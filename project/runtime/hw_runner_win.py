"""Windows XDMA runner for compiler artifacts.

Runs either a monolithic `program.bin` or segmented programs described by
`program_manifest.json`.  Weights are uploaded once to HBM, input is uploaded
once to VPU_BUF, and each program segment executes in-place on FPGA buffers.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import time
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
UNIT_TB = REPO / "test" / "network" / "host"
if str(REPO / "project" / "runtime") not in sys.path:
    sys.path.insert(0, str(REPO / "project" / "runtime"))
if str(UNIT_TB) not in sys.path:
    sys.path.insert(0, str(UNIT_TB))

from xdma_win import (  # noqa: E402
    INST_BASE,
    REGS_BASE,
    REG_DECODER_CTRL,
    REG_DECODER_STATUS,
    REG_INST_COUNT,
    XDMAWin,
)


def _load_unit_tb_run():
    path = UNIT_TB / "run.py"
    spec = importlib.util.spec_from_file_location("unit_tb_run", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def make_yolo_input(image_path: Path, mode: str, parsed_dir: Path | None = None) -> bytes:
    unit_run = _load_unit_tb_run()
    if parsed_dir is not None:
        net = json.loads((parsed_dir / "network.json").read_text())
        unit_run.ACT_SCALE = float(net.get("input_act_scale", unit_run.ACT_SCALE))
    img = unit_run.load_image(str(image_path))
    if mode == "int16":
        padded, _ratio, _pad = unit_run.letterbox(img, unit_run.IMG_SIZE_YOLO)
        fp32 = padded.astype(np.float32) / 255.0
        q = np.clip(np.round(fp32 / float(unit_run.ACT_SCALE)), -32768, 32767).astype(np.int16)
        return q.astype(np.int16).tobytes()
    q, _ratio, _pad, _orig = unit_run.preprocess_yolov5n(img)
    return q.tobytes()


def make_resnet_input(image_path: Path, mode: str, parsed_dir: Path | None = None) -> bytes:
    import resnet_e2e

    precision = "int16" if mode == "int16" else "vai"
    parsed = resnet_e2e.configure_resnet_precision(precision, parsed_override=parsed_dir)
    img = resnet_e2e.load_image(str(image_path))
    q = resnet_e2e.preprocess_resnet18(img, parsed)
    if mode == "int16":
        return q.astype(np.int16, copy=False).tobytes()
    return q.astype(np.int8, copy=False).tobytes()


def plan_mode(plan: dict) -> str:
    return str(plan.get("mode", plan.get("compile_meta", {}).get("mode", "int8")))


def _pad_nhwc_input(raw: bytes, plan: dict, mode: str) -> bytes:
    """Pad C<16 input pixels to the layout expected by im2col_unit.

    im2col_unit reads every input pixel at a 16-byte aligned stride. Host image
    preprocessing naturally produces tight NHWC C=3 tensors, so the first layer
    input must be expanded before upload. If the caller already provided padded
    bytes, leave them unchanged.
    """
    shape = plan.get("input_shape") or []
    if len(shape) != 4:
        return raw
    _n, c, h, w = [int(x) for x in shape]
    elem_bytes = 2 if mode == "int16" else 1
    tight = h * w * c * elem_bytes
    padded_c = (c * elem_bytes + 15) // 16 * (16 // elem_bytes)
    padded = h * w * padded_c * elem_bytes
    if c * elem_bytes >= 16 or len(raw) != tight or tight == padded:
        return raw

    dtype = np.int16 if elem_bytes == 2 else np.uint8
    arr = np.frombuffer(raw, dtype=dtype).reshape(h, w, c)
    out = np.zeros((h, w, padded_c), dtype=dtype)
    out[:, :, :c] = arr
    return out.tobytes()


def load_programs(build_dir: Path) -> list[tuple[int, Path, bytes]]:
    manifest_path = build_dir / "program_manifest.json"
    if not manifest_path.exists():
        program = build_dir / "program.bin"
        return [(0, program, program.read_bytes())]

    manifest = json.loads(manifest_path.read_text())
    programs = []
    for seg in manifest["segments"]:
        path = build_dir / seg["bin"]
        programs.append((int(seg["index"]), path, path.read_bytes()))
    return programs


def start_and_poll(xdma: XDMAWin, n_words: int, timeout_s: float, label: str,
                   poll_interval_s: float = 0.05) -> float:
    print(f"[win] {label}: INST_COUNT={n_words}")
    t0 = time.perf_counter()
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, n_words)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

    interval = max(0.0, float(poll_interval_s))
    deadline = time.perf_counter() + timeout_s
    last = None
    while True:
        st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
        if st != last:
            print(f"[win] {label}: DECODER_STATUS=0x{st:08x}")
            last = st
        if st & 0x80000000:
            raise RuntimeError(f"{label}: decoder error status=0x{st:08x}")
        if st & 0x2:
            print(f"[win] {label}: DONE")
            return time.perf_counter() - t0
        remaining = deadline - time.perf_counter()
        if remaining <= 0:
            raise TimeoutError(f"{label}: decoder timeout after {timeout_s}s status=0x{st:08x}")
        time.sleep(interval if interval <= remaining else remaining)


def soft_reset_decoder(xdma: XDMAWin) -> int:
    """Request decoder-only soft reset on bitstreams that implement it.

    New RTL interprets a decoder start pulse with INST_COUNT=0 as a local
    decoder reset.  Older bitstreams simply ignore it, so callers still check
    DECODER_STATUS afterwards.
    """
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, 0)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    time.sleep(0.005)
    return xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)


def read_chunked(xdma: XDMAWin, address: int, nbytes: int, chunk_bytes: int = 0x20000) -> bytes:
    out = bytearray()
    offset = 0
    while offset < nbytes:
        size = min(chunk_bytes, nbytes - offset)
        out.extend(xdma.read(address + offset, size))
        offset += size
    return bytes(out)


def write_chunked(xdma: XDMAWin, address: int, data: bytes, chunk_bytes: int = 0x100000) -> None:
    offset = 0
    nbytes = len(data)
    while offset < nbytes:
        size = min(chunk_bytes, nbytes - offset)
        xdma.write(address + offset, data[offset:offset + size])
        offset += size


def verify_write_tail(xdma: XDMAWin, address: int, nbytes: int) -> None:
    """Read back a small tail sample after a write.

    Normal artifacts are much larger than 16B, but decoder smoke tests can use a
    single 32-bit instruction.  Clamp the verification read so the address never
    underflows the written range.
    """
    if nbytes <= 0:
        return
    sample = min(16, nbytes)
    xdma.read(address + nbytes - sample, sample)


def zero_obuf_regions(xdma: XDMAWin, obuf_base: int, regions: list[dict], chunk_bytes: int) -> float:
    total_s = 0.0
    zero_chunk = b"\x00" * min(chunk_bytes, 0x100000)
    for region in regions:
        off = int(region["obuf_off"])
        nbytes = int(region["bytes"])
        name = region.get("name", "region")
        print(f"[win] zero OBUF {name}: {nbytes} bytes -> VPU_BUF 0x{obuf_base + off:x}")
        t0 = time.perf_counter()
        done = 0
        while done < nbytes:
            size = min(len(zero_chunk), nbytes - done)
            xdma.write(obuf_base + off + done, zero_chunk[:size])
            done += size
        verify_write_tail(xdma, obuf_base + off, nbytes)
        total_s += time.perf_counter() - t0
    return total_s


def output_specs(plan: dict) -> list[dict]:
    host = plan["host_io"]
    outputs = host.get("outputs") or [{
        "name": "output",
        "obuf_off": host["output_obuf_off"],
        "dtype": host.get("output_dtype", "float32"),
        "hw": host["output_hw"],
        "c": host["output_c"],
    }]
    return outputs


def output_nbytes(spec: dict) -> int:
    dtype = spec.get("dtype", "float32")
    elem = 4 if dtype == "float32" else (2 if dtype == "int16" else 1)
    h, w = [int(x) for x in spec["hw"]]
    return h * w * int(spec["c"]) * elem


def _finalize_timing(timing: dict, total_t0: float, timing_json: str | None) -> None:
    timing["execute_s"] = sum(float(s.get("execute_s", 0.0)) for s in timing.get("segments", []))
    timing["program_upload_s"] = sum(float(s.get("upload_s", 0.0)) for s in timing.get("segments", []))
    timing["read_outputs_s"] = sum(float(o.get("read_s", 0.0)) for o in timing.get("outputs", []))
    timing["total_s"] = time.perf_counter() - total_t0
    print(
        "[win] timing "
        f"total={timing['total_s']:.3f}s "
        f"upload(weights/wb/input/program)="
        f"{float(timing.get('upload_weights_s', 0.0)):.3f}/"
        f"{float(timing.get('upload_wb_s', 0.0)):.3f}/"
        f"{float(timing.get('upload_input_s', 0.0)):.3f}/"
        f"{timing['program_upload_s']:.3f}s "
        f"execute={timing['execute_s']:.3f}s "
        f"read={timing['read_outputs_s']:.3f}s"
    )
    if timing_json:
        Path(timing_json).write_text(json.dumps(timing, indent=2))
        print(f"[win] wrote timing {timing_json}")


class HardwareSession:
    """Keep XDMA open and upload weights/WB once across many images."""

    def __init__(
        self,
        build_dir: Path,
        *,
        quiet_xdma: bool = True,
        soft_reset: bool = True,
        poll_timeout_s: float = 120.0,
        poll_interval_s: float = 0.05,
        read_chunk_bytes: int = 0x20000,
        write_chunk_bytes: int = 0x100000,
        force_start_when_busy: bool = False,
    ) -> None:
        self.build_dir = Path(build_dir)
        self.poll_timeout_s = poll_timeout_s
        self.poll_interval_s = poll_interval_s
        self.read_chunk_bytes = read_chunk_bytes
        self.write_chunk_bytes = write_chunk_bytes
        self.force_start_when_busy = force_start_when_busy
        self.plan = json.loads((self.build_dir / "plan.json").read_text())
        self.mode = plan_mode(self.plan)
        am = self.plan["address_map"]
        self.obuf_base = int(am["obuf_base"])
        self.hbm_base = int(am.get("hbm_base", 0))
        self.programs = load_programs(self.build_dir)
        self.weights = (
            (self.build_dir / "weights.bin").read_bytes()
            if (self.build_dir / "weights.bin").exists() else b""
        )
        self.wb_blob = (
            (self.build_dir / "wb.bin").read_bytes()
            if (self.build_dir / "wb.bin").exists() else b""
        )
        self.xdma = XDMAWin(verbose=not quiet_xdma)
        if soft_reset:
            st_after_reset = soft_reset_decoder(self.xdma)
            print(f"[win] after decoder soft reset DECODER_STATUS=0x{st_after_reset:08x}")
        self.initial_status = self.xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
        print(f"[win] initial DECODER_STATUS=0x{self.initial_status:08x}")
        if (self.initial_status & 0x1) and not force_start_when_busy:
            self.close()
            raise RuntimeError(
                f"decoder is already busy (DECODER_STATUS=0x{self.initial_status:08x}); "
                "reset/reprogram the FPGA before running a new compiled plan"
            )
        self._static_uploaded = False
        self._static_timing = {
            "upload_weights_s": 0.0,
            "upload_wb_s": 0.0,
            "zero_obuf_s": 0.0,
        }

    def close(self) -> None:
        xdma = getattr(self, "xdma", None)
        if xdma is not None:
            xdma.close()
            self.xdma = None

    def __enter__(self) -> "HardwareSession":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def prepare_input(
        self,
        *,
        input_path: Path | None = None,
        yolo_image: Path | None = None,
        resnet_image: Path | None = None,
        yolo_parsed_dir: Path | None = None,
        resnet_parsed_dir: Path | None = None,
    ) -> bytes:
        if input_path is not None:
            raw = Path(input_path).read_bytes()
        elif yolo_image is not None:
            raw = make_yolo_input(Path(yolo_image), self.mode, yolo_parsed_dir)
        elif resnet_image is not None:
            raw = make_resnet_input(Path(resnet_image), self.mode, resnet_parsed_dir)
        else:
            raise ValueError("provide input_path, yolo_image, or resnet_image")
        return _pad_nhwc_input(raw, self.plan, self.mode)

    def _upload_static(self) -> None:
        if self._static_uploaded:
            return
        xdma = self.xdma
        assert xdma is not None
        zero_regions = self.plan.get("host_io", {}).get("zero_obuf_regions", [])
        if zero_regions:
            self._static_timing["zero_obuf_s"] = zero_obuf_regions(
                xdma, self.obuf_base, zero_regions, self.write_chunk_bytes
            )
        if self.weights:
            off = int(self.plan.get("host_io", {}).get("weights_hbm_off", 0x200000))
            print(f"[win] upload weights once: {len(self.weights)} bytes -> HBM 0x{self.hbm_base + off:x}")
            t0 = time.perf_counter()
            write_chunked(xdma, self.hbm_base + off, self.weights, self.write_chunk_bytes)
            verify_write_tail(xdma, self.hbm_base + off, len(self.weights))
            self._static_timing["upload_weights_s"] = time.perf_counter() - t0
        if self.wb_blob:
            scratch_map = self.plan.get("wb_layout", {}).get("scratch_off_by_layer", {})
            scratch_off = min(int(v) for v in scratch_map.values()) if scratch_map else 0x7C0000
            print(f"[win] upload wb scratch: {len(self.wb_blob)} bytes -> VPU_BUF 0x{self.obuf_base + scratch_off:x}")
            t0 = time.perf_counter()
            write_chunked(xdma, self.obuf_base + scratch_off, self.wb_blob, self.write_chunk_bytes)
            verify_write_tail(xdma, self.obuf_base + scratch_off, len(self.wb_blob))
            self._static_timing["upload_wb_s"] = time.perf_counter() - t0
        self._static_uploaded = True

    def run(
        self,
        input_bytes: bytes,
        output: Path,
        output_dir: Path | None = None,
        timing_json: Path | None = None,
        reuse_program: bool = True,
    ) -> dict:
        xdma = self.xdma
        if xdma is None:
            raise RuntimeError("HardwareSession is closed")
        total_t0 = time.perf_counter()
        self._upload_static()
        timing = {
            "build_dir": str(self.build_dir),
            "network": self.plan.get("network"),
            "mode": self.plan.get("mode", self.plan.get("compile_meta", {}).get("mode")),
            "initial_decoder_status": self.initial_status,
            "weights_bytes": len(self.weights),
            "wb_bytes": len(self.wb_blob),
            "input_bytes": len(input_bytes),
            "segments": [],
            "outputs": [],
            "reused_static": True,
            **self._static_timing,
        }
        in_off = int(self.plan["host_io"]["input_obuf_off"])
        print(f"[win] upload input: {len(input_bytes)} bytes -> VPU_BUF 0x{self.obuf_base + in_off:x}")
        t0 = time.perf_counter()
        write_chunked(xdma, self.obuf_base + in_off, input_bytes, self.write_chunk_bytes)
        verify_write_tail(xdma, self.obuf_base + in_off, len(input_bytes))
        timing["upload_input_s"] = time.perf_counter() - t0

        skip_program = reuse_program and getattr(self, "_program_resident", False)
        for idx, path, program in self.programs:
            print(f"[win] {'keep' if skip_program else 'upload'} segment {idx}: {len(program)} bytes ({path.name}) -> INST 0x{INST_BASE:x}")
            seg = {
                "index": idx,
                "path": str(path),
                "bytes": len(program),
                "words": len(program) // 4,
            }
            timing["segments"].append(seg)
            t0 = time.perf_counter()
            try:
                if not skip_program:
                    write_chunked(xdma, INST_BASE, program, self.write_chunk_bytes)
                    verify_write_tail(xdma, INST_BASE, len(program))
                    seg["upload_s"] = time.perf_counter() - t0
                else:
                    seg["upload_s"] = 0.0
                # Multi-segment programs overwrite INST_BRAM each segment, so only
                # a single-segment program can stay resident across images.
                if len(self.programs) > 1:
                    skip_program = False
                seg["execute_s"] = start_and_poll(
                    xdma, len(program) // 4, self.poll_timeout_s, f"segment {idx}",
                    poll_interval_s=self.poll_interval_s,
                )
            except Exception as exc:
                seg.setdefault("upload_s", time.perf_counter() - t0)
                seg["error"] = f"{type(exc).__name__}: {exc}"
                timing["failed_segment"] = idx
                timing["error"] = seg["error"]
                _finalize_timing(timing, total_t0, str(timing_json) if timing_json else None)
                raise
        self._program_resident = len(self.programs) == 1

        outputs = output_specs(self.plan)
        primary = outputs[-1]
        out_off = int(primary["obuf_off"])
        nbytes = output_nbytes(primary)
        print(f"[win] read output {primary['name']}: {nbytes} bytes <- VPU_BUF 0x{self.obuf_base + out_off:x}")
        t0 = time.perf_counter()
        data = read_chunked(xdma, self.obuf_base + out_off, nbytes, self.read_chunk_bytes)
        read_s = time.perf_counter() - t0
        timing["outputs"].append({"name": primary["name"], "bytes": nbytes, "read_s": read_s})
        Path(output).parent.mkdir(parents=True, exist_ok=True)
        Path(output).write_bytes(data)
        print(f"[win] wrote {output}")

        if output_dir:
            out_dir = Path(output_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            for spec in outputs:
                name = str(spec["name"]).replace("/", "_").replace("\\", "_")
                path = out_dir / f"{name}.bin"
                if spec is primary:
                    blob = data
                else:
                    off = int(spec["obuf_off"])
                    nb = output_nbytes(spec)
                    print(f"[win] read output {name}: {nb} bytes <- VPU_BUF 0x{self.obuf_base + off:x}")
                    t0 = time.perf_counter()
                    blob = read_chunked(xdma, self.obuf_base + off, nb, self.read_chunk_bytes)
                    timing["outputs"].append({"name": name, "bytes": nb, "read_s": time.perf_counter() - t0})
                path.write_bytes(blob)
                print(f"[win] wrote {path}")

        _finalize_timing(timing, total_t0, str(timing_json) if timing_json else None)
        return timing


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)

    ap = argparse.ArgumentParser(description="Run compiler artifacts on Windows XDMA")
    ap.add_argument("--build-dir", required=True,
                    help="directory containing plan.json/program.bin/weights.bin/wb.bin")
    ap.add_argument("--input", default=None,
                    help="raw input bytes. If omitted, use --yolo-image or --resnet-image.")
    ap.add_argument("--yolo-image", default=None,
                    help="image to preprocess for YOLO input")
    ap.add_argument("--resnet-image", default=None,
                    help="image to preprocess for ResNet18 input")
    ap.add_argument("--yolo-parsed-dir", default=None,
                    help="optional YOLO parsed dir for input activation scale")
    ap.add_argument("--resnet-parsed-dir", default=None,
                    help="optional native/widened ResNet parsed dir for input quantization")
    ap.add_argument("--output", default=None,
                    help="raw output feature file")
    ap.add_argument("--output-dir", default=None,
                    help="optional directory for all named host outputs")
    ap.add_argument("--poll-timeout-s", type=float, default=120.0)
    ap.add_argument("--poll-interval-s", type=float, default=0.05,
                    help="sleep between DECODER_STATUS C2H polls; default 50ms")
    ap.add_argument("--read-chunk-bytes", type=int, default=0x20000,
                    help="chunk size for large C2H output reads")
    ap.add_argument("--write-chunk-bytes", type=int, default=0x100000,
                    help="chunk size for large H2C uploads")
    ap.add_argument("--quiet-xdma", action="store_true")
    ap.add_argument("--force-start-when-busy", action="store_true",
                    help="try to run even if DECODER_STATUS.busy is already set")
    ap.add_argument("--status-only", action="store_true",
                    help="only read DECODER_STATUS and exit without uploading or starting")
    ap.add_argument("--soft-reset-decoder", action="store_true",
                    help="pulse DECODER_CTRL with INST_COUNT=0 before doing anything else")
    ap.add_argument("--timing-json", default=None,
                    help="optional path to write upload/execute/readback timing summary")
    args = ap.parse_args()

    session = HardwareSession(
        Path(args.build_dir),
        quiet_xdma=args.quiet_xdma,
        soft_reset=args.soft_reset_decoder,
        poll_timeout_s=args.poll_timeout_s,
        poll_interval_s=args.poll_interval_s,
        read_chunk_bytes=args.read_chunk_bytes,
        write_chunk_bytes=args.write_chunk_bytes,
        force_start_when_busy=args.force_start_when_busy,
    )
    try:
        if args.status_only:
            return
        if not args.output:
            raise SystemExit("provide --output unless --status-only is used")
        input_bytes = session.prepare_input(
            input_path=Path(args.input) if args.input else None,
            yolo_image=Path(args.yolo_image) if args.yolo_image else None,
            resnet_image=Path(args.resnet_image) if args.resnet_image else None,
            yolo_parsed_dir=Path(args.yolo_parsed_dir) if args.yolo_parsed_dir else None,
            resnet_parsed_dir=Path(args.resnet_parsed_dir) if args.resnet_parsed_dir else None,
        )
        session.run(
            input_bytes,
            Path(args.output),
            Path(args.output_dir) if args.output_dir else None,
            Path(args.timing_json) if args.timing_json else None,
            reuse_program=False,
        )
    finally:
        session.close()


if __name__ == "__main__":
    main()


