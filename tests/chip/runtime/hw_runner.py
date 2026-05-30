"""
hw_runner.py - host-side driver that pushes a compiled plan to the FPGA via XDMA.

Hardware-side address map (mirrors chip_defines.vh:94-99 and scripts/ip/bd/lite/address.tcl):

   0x1_0000_0000  IBUF      (2 MB)        DMA via /dev/xdma0_h2c_0 / c2h_0
   0x1_0100_0000  OBUF      (16 MB)       DMA via /dev/xdma0_h2c_0 / c2h_0
   0x1_0200_0000  WB        (32 KB)       DMA via /dev/xdma0_h2c_0
   0x1_0300_0000  INST_BRAM (128 KB)      DMA via /dev/xdma0_h2c_0
   0x1_0400_0000  VPU_AXI_Regs (4 KB)     same channel, AXI-Lite small writes

All five segments hang off the XDMA M_AXI, so we DO NOT need /dev/xdma0_user
mmap; all reads/writes go through /dev/xdma0_h2c_0 (writes) and
/dev/xdma0_c2h_0 (reads) using `os.pwrite` / `os.pread`.

CLI:
    python tools/runtime/hw_runner.py --build-dir build/yolov5n \
        --input image.bin --output result.bin [--device /dev/xdma0]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

import numpy as np


class XDMA:
    def __init__(self, device_prefix: str = "/dev/xdma0"):
        self.device_prefix = device_prefix
        self.h2c_path = f"{device_prefix}_h2c_0"
        self.c2h_path = f"{device_prefix}_c2h_0"
        self._h2c_fd: Optional[int] = None
        self._c2h_fd: Optional[int] = None

    def __enter__(self):
        if not os.path.exists(self.h2c_path):
            raise FileNotFoundError(f"XDMA H2C device {self.h2c_path} not found.  "
                                    f"Is the driver loaded?  Run with --dry-run to skip.")
        self._h2c_fd = os.open(self.h2c_path, os.O_WRONLY)
        self._c2h_fd = os.open(self.c2h_path, os.O_RDONLY)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._h2c_fd is not None:
            os.close(self._h2c_fd)
        if self._c2h_fd is not None:
            os.close(self._c2h_fd)

    def write(self, address: int, data: bytes):
        """Write `data` to the FPGA at the given absolute AXI address.

        Uses os.pwrite which respects the seek offset internally; the XDMA
        driver interprets the offset as the AXI address LSB."""
        n = os.pwrite(self._h2c_fd, data, address & 0xFFFFFFFFFFFFFFFF)
        if n != len(data):
            raise RuntimeError(f"H2C short write at 0x{address:x}: {n}/{len(data)}")

    def write_u32(self, address: int, val: int):
        self.write(address, int(val & 0xFFFFFFFF).to_bytes(4, "little"))

    def read(self, address: int, nbytes: int) -> bytes:
        out = os.pread(self._c2h_fd, nbytes, address & 0xFFFFFFFFFFFFFFFF)
        if len(out) != nbytes:
            raise RuntimeError(f"C2H short read at 0x{address:x}: {len(out)}/{nbytes}")
        return out

    def read_u32(self, address: int) -> int:
        return int.from_bytes(self.read(address, 4), "little")


class DryXDMA:
    """No-op stand-in used when --dry-run is set: logs every transaction."""

    def __init__(self, *_a, **_kw): pass
    def __enter__(self): return self
    def __exit__(self, *args): return None
    def write(self, address, data):
        print(f"[dry] write @ 0x{address:x}  {len(data)} bytes")
    def write_u32(self, address, val):
        print(f"[dry] write32 @ 0x{address:x} = 0x{val:08x}")
    def read(self, address, nbytes):
        print(f"[dry] read  @ 0x{address:x}  {nbytes} bytes")
        return b"\x00" * nbytes
    def read_u32(self, address):
        print(f"[dry] read32 @ 0x{address:x}")
        # Pretend DONE on every poll so the dry run terminates.
        return 0x2


# VPU_AXI_Regs offsets (from rtl/vpu/VPU_AXI_Regs.v + hw_caps.yaml)
REG_STATUS = 0x04
REG_DECODER_CTRL = 0x38
REG_INST_COUNT = 0x3C
REG_DECODER_STATUS = 0x40


def main():
    ap = argparse.ArgumentParser(description="EdgeYOLO-FPGA-lite XDMA host runner")
    ap.add_argument("--build-dir", required=True,
                    help="directory with plan.json / program.bin / weights.bin / wb.bin")
    ap.add_argument("--input", required=True,
                    help="raw input bytes (NHWC INT8/UINT8) to upload at OBUF[input_obuf_off]")
    ap.add_argument("--output", required=True,
                    help="path to write the OBUF[output_obuf_off..] tensor back to")
    ap.add_argument("--device", default="/dev/xdma0",
                    help="XDMA device prefix (default /dev/xdma0)")
    ap.add_argument("--dry-run", action="store_true",
                    help="do not actually open XDMA; just print the transactions")
    ap.add_argument("--poll-timeout-s", type=float, default=10.0,
                    help="how long to wait for DECODER_STATUS.done")
    args = ap.parse_args()

    bd = Path(args.build_dir)
    plan = json.loads((bd / "plan.json").read_text())
    program = (bd / "program.bin").read_bytes()
    weights = (bd / "weights.bin").read_bytes() if (bd / "weights.bin").exists() else b""
    wb_blob = (bd / "wb.bin").read_bytes() if (bd / "wb.bin").exists() else b""
    input_bytes = open(args.input, "rb").read()

    am = plan["address_map"]
    ibuf_base = int(am["ibuf_base"])
    obuf_base = int(am["obuf_base"])
    wb_base = int(am["wb_base"])
    inst_base = int(am["inst_base"])
    regs_base = int(am["regs_base"])

    Xclass = DryXDMA if args.dry_run else XDMA

    with Xclass(args.device) as x:
        # ---- 1. Upload program ----
        print(f"[hw] upload program: {len(program)} bytes → INST_BRAM @ 0x{inst_base:x}")
        x.write(inst_base, program)
        n_words = len(program) // 4

        # ---- 2. Upload weights ----
        # For the MVP single-layer run, weights occupy IBUF from offset 0.  For
        # multi-layer runs the host streams per-layer weights between layer
        # ops (not in MVP scope).
        if weights:
            print(f"[hw] upload weights: {len(weights)} bytes → IBUF @ 0x{ibuf_base:x}")
            x.write(ibuf_base, weights)

        # ---- 3. Upload WB scratch (into OBUF wb-scratch region) ----
        if wb_blob:
            scratch_lo = obuf_base + 0xFF0000
            print(f"[hw] upload wb_scratch: {len(wb_blob)} bytes → OBUF wb_scratch @ 0x{scratch_lo:x}")
            x.write(scratch_lo, wb_blob)

        # ---- 4. Upload input feature ----
        in_off = plan["host_io"]["input_obuf_off"]
        print(f"[hw] upload input: {len(input_bytes)} bytes → OBUF @ 0x{obuf_base + in_off:x}")
        x.write(obuf_base + in_off, input_bytes)

        # ---- 5. Kick off decoder ----
        print(f"[hw] write INST_COUNT = {n_words}")
        x.write_u32(regs_base + REG_INST_COUNT, n_words)
        print(f"[hw] write DECODER_CTRL = 1")
        x.write_u32(regs_base + REG_DECODER_CTRL, 1)
        # The decoder takes the edge; clear the level for cleanliness.
        x.write_u32(regs_base + REG_DECODER_CTRL, 0)

        # ---- 6. Poll DECODER_STATUS until done or error ----
        deadline = time.time() + args.poll_timeout_s
        last = None
        while True:
            st = x.read_u32(regs_base + REG_DECODER_STATUS)
            if st != last:
                print(f"[hw] DECODER_STATUS = 0x{st:08x}")
                last = st
            if st & 0x80000000:
                raise RuntimeError(f"decoder error: status=0x{st:08x}")
            if st & 0x2:
                print(f"[hw] decoder DONE")
                break
            if time.time() > deadline:
                raise TimeoutError(f"decoder still busy after {args.poll_timeout_s}s "
                                   f"(status=0x{st:08x})")
            time.sleep(0.001)

        # ---- 7. Read back output tensor ----
        out_off = plan["host_io"]["output_obuf_off"]
        oh, ow = plan["host_io"]["output_hw"]
        oc = plan["host_io"]["output_c"]
        elem = 4 if plan["host_io"]["output_dtype"] == "float32" else 1
        nbytes = oh * ow * oc * elem
        print(f"[hw] read output: {nbytes} bytes from OBUF @ 0x{obuf_base + out_off:x}")
        data = x.read(obuf_base + out_off, nbytes)

    open(args.output, "wb").write(data)
    print(f"[hw] wrote {nbytes} bytes to {args.output}")


if __name__ == "__main__":
    main()
