"""
xdma_driver.py - XDMA driver class for EdgeYOLO-FPGA-lite board testing.

Provides a unified interface for Host↔FPGA communication via /dev/xdma0.
"""
from __future__ import annotations

import os
import time
from typing import Optional

import numpy as np


# Hardware address map (chip-v3 Vivado BD / hw_caps.yaml)
IBUF_BASE = 0x1_0000_0000
TILE_OBUF_BASE = 0x1_0100_0000
VPU_BUF_BASE = 0x1_0200_0000
OBUF_BASE = VPU_BUF_BASE
WB_BASE = 0x1_0300_0000
INST_BASE = 0x1_0400_0000
REGS_BASE = 0x1_0500_0000

IBUF_SIZE = 0x80000       # 512KB per tile
TILE_OBUF_SIZE = 0x40000  # 256KB per tile
OBUF_SIZE = 0x800000      # 8MB VPU buffer
WB_SIZE = 0x8000          # 32KB
INST_SIZE = 0x20000       # 128KB
REGS_SIZE = 0x1000        # 4KB

# VPU_AXI_Regs offsets
REG_STATUS = 0x04
REG_DECODER_CTRL = 0x38
REG_INST_COUNT = 0x3C
REG_DECODER_STATUS = 0x40


class XDMA:
    """Low-level XDMA driver using /dev/xdma0_h2c_0 and /dev/xdma0_c2h_0."""

    def __init__(self, device_prefix: str = "/dev/xdma0"):
        self.device_prefix = device_prefix
        self.h2c_path = f"{device_prefix}_h2c_0"
        self.c2h_path = f"{device_prefix}_c2h_0"
        self._h2c_fd: Optional[int] = None
        self._c2h_fd: Optional[int] = None

    def __enter__(self):
        if not os.path.exists(self.h2c_path):
            raise FileNotFoundError(
                f"XDMA device {self.h2c_path} not found. "
                f"Is the driver loaded? Use DryXDMA for offline testing."
            )
        self._h2c_fd = os.open(self.h2c_path, os.O_WRONLY)
        self._c2h_fd = os.open(self.c2h_path, os.O_RDONLY)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._h2c_fd is not None:
            os.close(self._h2c_fd)
        if self._c2h_fd is not None:
            os.close(self._c2h_fd)

    def write(self, address: int, data: bytes):
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
    """No-op stand-in for offline testing without hardware."""

    def __init__(self, *_a, **_kw):
        self._log = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return None

    def write(self, address, data):
        self._log.append(("write", address, len(data)))

    def write_u32(self, address, val):
        self._log.append(("write32", address, val))

    def read(self, address, nbytes):
        self._log.append(("read", address, nbytes))
        return b"\x00" * nbytes

    def read_u32(self, address):
        self._log.append(("read32", address))
        return 0x2  # pretend DONE


class ChipRunner:
    """High-level runner: uploads plan artifacts and executes on FPGA."""

    def __init__(self, xdma: XDMA | DryXDMA):
        self.x = xdma

    def upload_program(self, program_bin: bytes):
        print(f"[chip] upload program: {len(program_bin)} bytes → INST @ 0x{INST_BASE:x}")
        self.x.write(INST_BASE, program_bin)
        return len(program_bin) // 4

    def upload_weights(self, weights_bin: bytes):
        print(f"[chip] upload weights: {len(weights_bin)} bytes → IBUF @ 0x{IBUF_BASE:x}")
        self.x.write(IBUF_BASE, weights_bin)

    def upload_wb(self, wb_bin: bytes, obuf_off: int = 0xFF0000):
        addr = OBUF_BASE + obuf_off
        print(f"[chip] upload wb: {len(wb_bin)} bytes → OBUF wb_shadow @ 0x{addr:x}")
        self.x.write(addr, wb_bin)

    def upload_input(self, input_bin: bytes, obuf_off: int = 0x000000):
        addr = OBUF_BASE + obuf_off
        print(f"[chip] upload input: {len(input_bin)} bytes → OBUF @ 0x{addr:x}")
        self.x.write(addr, input_bin)

    def start_decoder(self, n_words: int):
        print(f"[chip] INST_COUNT = {n_words}, starting decoder")
        self.x.write_u32(REGS_BASE + REG_INST_COUNT, n_words)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

    def poll_done(self, timeout_s: float = 30.0) -> int:
        deadline = time.time() + timeout_s
        last = None
        while True:
            st = self.x.read_u32(REGS_BASE + REG_DECODER_STATUS)
            if st != last:
                print(f"[chip] DECODER_STATUS = 0x{st:08x}")
                last = st
            if st & 0x80000000:
                raise RuntimeError(f"Decoder error: status=0x{st:08x}")
            if st & 0x2:
                print("[chip] decoder DONE")
                return st
            if time.time() > deadline:
                raise TimeoutError(
                    f"Decoder still busy after {timeout_s}s (status=0x{st:08x})"
                )
            time.sleep(0.001)

    def read_output(self, obuf_off: int, nbytes: int) -> bytes:
        addr = OBUF_BASE + obuf_off
        print(f"[chip] read output: {nbytes} bytes from OBUF @ 0x{addr:x}")
        return self.x.read(addr, nbytes)

    def run_plan(self, build_dir, input_bin: bytes, timeout_s: float = 30.0) -> bytes:
        """Full run: upload everything, execute, read back result."""
        import json
        from pathlib import Path

        bd = Path(build_dir)
        plan = json.loads((bd / "plan.json").read_text())
        program = (bd / "program.bin").read_bytes()
        weights = (bd / "weights.bin").read_bytes() if (bd / "weights.bin").exists() else b""
        wb_blob = (bd / "wb.bin").read_bytes() if (bd / "wb.bin").exists() else b""

        n_words = self.upload_program(program)
        if weights:
            self.upload_weights(weights)
        if wb_blob:
            self.upload_wb(wb_blob)

        in_off = plan["host_io"]["input_obuf_off"]
        self.upload_input(input_bin, in_off)
        self.start_decoder(n_words)
        self.poll_done(timeout_s)

        out_off = plan["host_io"]["output_obuf_off"]
        oh, ow = plan["host_io"]["output_hw"]
        oc = plan["host_io"]["output_c"]
        elem = 4 if plan["host_io"]["output_dtype"] == "float32" else 1
        nbytes = oh * ow * oc * elem
        return self.read_output(out_off, nbytes)
