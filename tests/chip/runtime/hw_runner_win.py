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

REPO = Path(__file__).resolve().parents[3]
UNIT_TB = REPO / "tests" / "chip" / "unit-tb"
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


def make_resnet_input(image_path: Path, mode: str) -> bytes:
    import resnet_e2e

    precision = "int16" if mode == "int16" else "vai"
    parsed = resnet_e2e.configure_resnet_precision(precision)
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


def start_and_poll(xdma: XDMAWin, n_words: int, timeout_s: float, label: str) -> float:
    print(f"[win] {label}: INST_COUNT={n_words}")
    t0 = time.perf_counter()
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, n_words)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

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
        if time.perf_counter() > deadline:
            raise TimeoutError(f"{label}: decoder timeout after {timeout_s}s status=0x{st:08x}")
        time.sleep(0.002)


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
    ap.add_argument("--output", default=None,
                    help="raw output feature file")
    ap.add_argument("--output-dir", default=None,
                    help="optional directory for all named host outputs")
    ap.add_argument("--poll-timeout-s", type=float, default=120.0)
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

    total_t0 = time.perf_counter()
    build_dir = Path(args.build_dir)
    plan = json.loads((build_dir / "plan.json").read_text())
    am = plan["address_map"]
    obuf_base = int(am["obuf_base"])
    hbm_base = int(am.get("hbm_base", 0))

    xdma = XDMAWin(verbose=not args.quiet_xdma)
    if args.soft_reset_decoder:
        st_after_reset = soft_reset_decoder(xdma)
        print(f"[win] after decoder soft reset DECODER_STATUS=0x{st_after_reset:08x}")
    initial_status = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
    print(f"[win] initial DECODER_STATUS=0x{initial_status:08x}")
    if args.status_only:
        return
    if (initial_status & 0x1) and not args.force_start_when_busy:
        raise SystemExit(
            f"decoder is already busy (DECODER_STATUS=0x{initial_status:08x}); "
            "reset/reprogram the FPGA before running a new compiled plan"
        )
    if not args.output:
        raise SystemExit("provide --output unless --status-only is used")

    mode = plan_mode(plan)
    if args.input:
        input_bytes = Path(args.input).read_bytes()
    elif args.yolo_image:
        input_bytes = make_yolo_input(
            Path(args.yolo_image), mode,
            Path(args.yolo_parsed_dir) if args.yolo_parsed_dir else None,
        )
    elif args.resnet_image:
        input_bytes = make_resnet_input(Path(args.resnet_image), mode)
    else:
        raise SystemExit("provide --input, --yolo-image, or --resnet-image")
    input_bytes = _pad_nhwc_input(input_bytes, plan, mode)

    programs = load_programs(build_dir)
    weights = (build_dir / "weights.bin").read_bytes() if (build_dir / "weights.bin").exists() else b""
    wb_blob = (build_dir / "wb.bin").read_bytes() if (build_dir / "wb.bin").exists() else b""

    timing = {
        "build_dir": str(build_dir),
        "network": plan.get("network"),
        "mode": plan.get("mode", plan.get("compile_meta", {}).get("mode")),
        "initial_decoder_status": initial_status,
        "weights_bytes": len(weights),
        "wb_bytes": len(wb_blob),
        "input_bytes": len(input_bytes),
        "segments": [],
        "outputs": [],
    }
    zero_regions = plan.get("host_io", {}).get("zero_obuf_regions", [])
    if zero_regions:
        timing["zero_obuf_s"] = zero_obuf_regions(xdma, obuf_base, zero_regions, args.write_chunk_bytes)
    else:
        timing["zero_obuf_s"] = 0.0

    if weights:
        off = int(plan.get("host_io", {}).get("weights_hbm_off", 0x200000))
        print(f"[win] upload weights once: {len(weights)} bytes -> HBM 0x{hbm_base + off:x}")
        t0 = time.perf_counter()
        write_chunked(xdma, hbm_base + off, weights, args.write_chunk_bytes)
        verify_write_tail(xdma, hbm_base + off, len(weights))
        timing["upload_weights_s"] = time.perf_counter() - t0
    else:
        timing["upload_weights_s"] = 0.0

    if wb_blob:
        scratch_map = plan.get("wb_layout", {}).get("scratch_off_by_layer", {})
        scratch_off = min(int(v) for v in scratch_map.values()) if scratch_map else 0x7C0000
        print(f"[win] upload wb scratch: {len(wb_blob)} bytes -> VPU_BUF 0x{obuf_base + scratch_off:x}")
        t0 = time.perf_counter()
        write_chunked(xdma, obuf_base + scratch_off, wb_blob, args.write_chunk_bytes)
        verify_write_tail(xdma, obuf_base + scratch_off, len(wb_blob))
        timing["upload_wb_s"] = time.perf_counter() - t0
    else:
        timing["upload_wb_s"] = 0.0

    in_off = int(plan["host_io"]["input_obuf_off"])
    print(f"[win] upload input: {len(input_bytes)} bytes -> VPU_BUF 0x{obuf_base + in_off:x}")
    t0 = time.perf_counter()
    write_chunked(xdma, obuf_base + in_off, input_bytes, args.write_chunk_bytes)
    verify_write_tail(xdma, obuf_base + in_off, len(input_bytes))
    timing["upload_input_s"] = time.perf_counter() - t0

    for idx, path, program in programs:
        print(f"[win] upload segment {idx}: {len(program)} bytes ({path.name}) -> INST 0x{INST_BASE:x}")
        seg = {
            "index": idx,
            "path": str(path),
            "bytes": len(program),
            "words": len(program) // 4,
        }
        timing["segments"].append(seg)
        t0 = time.perf_counter()
        try:
            write_chunked(xdma, INST_BASE, program, args.write_chunk_bytes)
            verify_write_tail(xdma, INST_BASE, len(program))
            seg["upload_s"] = time.perf_counter() - t0
            seg["execute_s"] = start_and_poll(xdma, len(program) // 4, args.poll_timeout_s, f"segment {idx}")
        except Exception as exc:
            seg.setdefault("upload_s", time.perf_counter() - t0)
            seg["error"] = f"{type(exc).__name__}: {exc}"
            timing["failed_segment"] = idx
            timing["error"] = seg["error"]
            _finalize_timing(timing, total_t0, args.timing_json)
            raise

    outputs = output_specs(plan)
    primary = outputs[-1]
    out_off = int(primary["obuf_off"])
    nbytes = output_nbytes(primary)
    print(f"[win] read output {primary['name']}: {nbytes} bytes <- VPU_BUF 0x{obuf_base + out_off:x}")
    t0 = time.perf_counter()
    data = read_chunked(xdma, obuf_base + out_off, nbytes, args.read_chunk_bytes)
    read_s = time.perf_counter() - t0
    timing["outputs"].append({"name": primary["name"], "bytes": nbytes, "read_s": read_s})
    Path(args.output).write_bytes(data)
    print(f"[win] wrote {args.output}")

    if args.output_dir:
        out_dir = Path(args.output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        for spec in outputs:
            name = str(spec["name"]).replace("/", "_").replace("\\", "_")
            path = out_dir / f"{name}.bin"
            if spec is primary:
                blob = data
            else:
                off = int(spec["obuf_off"])
                nb = output_nbytes(spec)
                print(f"[win] read output {name}: {nb} bytes <- VPU_BUF 0x{obuf_base + off:x}")
                t0 = time.perf_counter()
                blob = read_chunked(xdma, obuf_base + off, nb, args.read_chunk_bytes)
                timing["outputs"].append({"name": name, "bytes": nb, "read_s": time.perf_counter() - t0})
            path.write_bytes(blob)
            print(f"[win] wrote {path}")

    _finalize_timing(timing, total_t0, args.timing_json)


if __name__ == "__main__":
    main()
