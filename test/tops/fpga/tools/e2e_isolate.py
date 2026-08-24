#!/usr/bin/env python3
"""Isolate YOLO/ResNet e2e: large CDMA, then prefix-N convs vs golden."""
from __future__ import annotations

import json
import struct
import sys
import time
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[4]
UNIT = REPO / "test" / "network" / "host"
RUNTIME = REPO / "project" / "runtime"
COMPILER = REPO / "project" / "compiler"
for p in (UNIT, RUNTIME, str(COMPILER), str(COMPILER.parent)):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from hbm_flow import OP_END, cdma_copy, _header  # noqa: E402
from xdma_win import (  # noqa: E402
    HBM_BASE,
    INST_BASE,
    REGS_BASE,
    REG_DECODER_CTRL,
    REG_INST_COUNT,
    TILE_IBUF_BASE,
    TILE_IBUF_SIZE,
    TILE_OBUF_BASE,
    TILE_OBUF_SIZE,
    VPU_BUF_BASE,
    ChipRunnerWin,
    inst_words_to_bin,
)
from compiler.codegen.encode_isa import encode_ops  # noqa: E402
from compare_one_shot import run_yolo_compiler_golden, _stats  # noqa: E402

YOLO_BUILD = REPO / "test" / "network" / "output" / "compiled" / "80832ec_attempt1" / "yolo_coco_int8"
YOLO_IMG = REPO / "test" / "network" / "examples" / "coco" / "000000000139.jpg"
YOLO_PARSED = REPO / "project" / "model" / "yolov5n_coco50k_qat" / "parsed_int8"
ABC_DIR = REPO / "test" / "tops" / "output" / "fpga" / "dcim_abc"
FILL = 0xA5


def unique(tag: int, n: int) -> bytes:
    buf = bytearray(n)
    for i in range(0, n, 4):
        struct.pack_into("<I", buf, i, ((tag & 0xFF) << 24) | (i & 0xFFFFFF))
    return bytes(buf)


def match_words(a: bytes, b: bytes) -> tuple[int, int]:
    n = min(len(a), len(b)) // 16
    ok = sum(1 for i in range(n) if a[i * 16 : (i + 1) * 16] == b[i * 16 : (i + 1) * 16])
    return ok, n


class Iso:
    def __init__(self) -> None:
        self.r = ChipRunnerWin(verbose=False)
        self.x = self.r.x

    def soft_reset(self) -> None:
        self.x.write_u32(REGS_BASE + REG_INST_COUNT, 0)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
        time.sleep(0.001)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
        time.sleep(0.005)

    def run_words(self, words: list[int], timeout_s: float = 30.0) -> None:
        data = inst_words_to_bin(list(words) + [_header(OP_END, 0, 0)])
        self.soft_reset()
        self.x.write(INST_BASE, data)
        self.r.start_decoder(len(data) // 4)
        self.r.poll_done(timeout_s)

    def cdma_check(self, name: str, src: int, dst: int, n: int, tag: int) -> str:
        exp = unique(tag, n)
        fill = bytes([FILL]) * n
        self.x.write(dst, fill)
        self.x.write(src, exp)
        self.run_words(cdma_copy(src, dst, n), timeout_s=20.0)
        got = self.x.read(dst, n)
        if got == exp:
            kind = "MATCH"
        elif got == fill:
            kind = "UNTOUCHED"
        else:
            ok, tot = match_words(got, exp)
            kind = f"CORRUPT {ok}/{tot} head={got[:8].hex()}"
        print(f"  {name}: {kind}", flush=True)
        return kind


def slice_ops_until_layers(plan: dict, allowed: set[str]) -> list[dict]:
    out = []
    for op in plan["ops"]:
        layer = op.get("layer")
        if layer and layer not in allowed:
            # WB refresh for next layer has layer in src tuple, kind cdma_copy without layer
            src = op.get("src")
            if (
                op.get("kind") == "cdma_copy"
                and isinstance(src, (list, tuple))
                and src
                and src[0] == "obuf_wb_scratch_off_for_layer"
                and src[1] not in allowed
            ):
                break
            if layer not in allowed:
                break
        out.append(op)
    if not out or out[-1].get("kind") != "end":
        out.append({"kind": "end"})
    return out


def large_cdma(iso: Iso) -> None:
    print("\n=== large CDMA (YOLO first-layer sizes) ===", flush=True)
    cases = [
        ("vpu->ibuf0 512000", VPU_BUF_BASE + 0x1000, TILE_IBUF_BASE + 2048, 512000, 0x11),
        ("ibuf0->vpu 512000", TILE_IBUF_BASE + 2048, VPU_BUF_BASE + 0x200000, 512000, 0x22),
        ("obuf0->vpu 256000", TILE_OBUF_BASE, VPU_BUF_BASE + 0x300000, 256000, 0x33),
    ]
    for name, src, dst, n, tag in cases:
        iso.cdma_check(name, src, dst, n, tag)


def pad_waits(ops: list, n: int) -> list:
    if n <= 0:
        return ops
    out = []
    for op in ops:
        out.append(op)
        if op.get("kind") in ("wait_vpu", "wait_dcim"):
            out.extend({"kind": "nop"} for _ in range(n))
    return out


def yolo_prefix(iso: Iso, n_conv: int, settle_nops: int = 0) -> dict:
    plan = json.loads((YOLO_BUILD / "plan.json").read_text())
    layers = plan["memory_plan"]["layers"]
    names = [L["name"] for L in layers[:n_conv]]
    allowed = set(names)
    last = layers[n_conv - 1]
    ops = pad_waits(slice_ops_until_layers(plan, allowed), settle_nops)
    words = encode_ops(plan, ops)
    print(
        f"\n=== YOLO prefix {n_conv} conv ({names[-1]}) ops={len(ops)} words={len(words)} settle_nops={settle_nops} ===",
        flush=True,
    )
    if len(words) * 4 > 128 * 1024:
        print("  INST too big", flush=True)
        return {"pass": False, "reason": "inst_too_big"}

    from hw_runner_win import (  # noqa: WPS433
        make_yolo_input,
        _pad_nhwc_input,
        write_chunked,
        verify_write_tail,
        plan_mode,
        soft_reset_decoder,
    )

    mode = plan_mode(plan)
    am = plan["address_map"]
    obuf_base = int(am["obuf_base"])
    hbm_base = int(am.get("hbm_base", 0))
    input_bytes = make_yolo_input(YOLO_IMG, mode, YOLO_PARSED)
    input_bytes = _pad_nhwc_input(input_bytes, plan, mode)
    weights = (YOLO_BUILD / "weights.bin").read_bytes()
    wb_blob = (YOLO_BUILD / "wb.bin").read_bytes()

    soft_reset_decoder(iso.x)
    off = int(plan["host_io"].get("weights_hbm_off", 0x200000))
    write_chunked(iso.x, hbm_base + off, weights, 0x100000)
    verify_write_tail(iso.x, hbm_base + off, len(weights))
    scratch_map = plan.get("wb_layout", {}).get("scratch_off_by_layer", {})
    scratch_off = min(int(v) for v in scratch_map.values()) if scratch_map else 0x7C0000
    write_chunked(iso.x, obuf_base + scratch_off, wb_blob, 0x100000)
    in_off = int(plan["host_io"]["input_obuf_off"])
    write_chunked(iso.x, obuf_base + in_off, input_bytes, 0x100000)
    verify_write_tail(iso.x, obuf_base + in_off, len(input_bytes))

    data = inst_words_to_bin(words)
    iso.x.write(INST_BASE, data)
    iso.r.start_decoder(len(data) // 4)
    iso.r.poll_done(60.0)

    oh, ow = last["output_hw"]
    c = last["output_c"]
    nbytes = oh * ow * c * 4
    addr = obuf_base + int(last["output_off"])
    print(f"  reading {nbytes}B from VPU_BUF+0x{int(last['output_off']):x} (2048B C2H)", flush=True)
    raw = bytearray()
    off = 0
    chunk = 2048
    while off < nbytes:
        n = min(chunk, nbytes - off)
        raw.extend(iso.x._read_once(addr + off, n))
        off += n
    raw = bytes(raw)
    got = np.frombuffer(raw, dtype=np.float32).reshape(oh, ow, c)
    ref, _ = run_yolo_compiler_golden(YOLO_IMG, "int8", n_conv, str(YOLO_PARSED))
    if ref.shape != got.shape:
        print(f"  shape got {got.shape} ref {ref.shape}", flush=True)
        # try channel pad
        cmin = min(got.shape[-1], ref.shape[-1])
        got_c, ref_c = got[..., :cmin], ref[..., :cmin]
    else:
        got_c, ref_c = got, ref
    s = _stats(got_c, ref_c)
    corr = float(np.corrcoef(got_c.ravel(), ref_c.ravel())[0, 1]) if got_c.size > 8 else 0.0
    print(
        f"  {names[-1]} max_abs={s['max_abs']:.6g} mean_abs={s['mean_abs']:.6g} "
        f"rmse={s['rmse']:.6g} corr={corr:.4f} shape={got.shape}",
        flush=True,
    )
    analyze_spatial(got_c, ref_c, chunk=25)
    return {"pass": s["max_abs"] <= 1e-3, "stats": s, "corr": corr, "layer": names[-1]}


def split_oh_tiles(ops: list) -> tuple[list, list]:
    pre, tiles, cur = [], [], None
    for op in ops:
        if op.get("kind") == "end":
            continue
        if op.get("unit") == "im2col":
            if cur:
                tiles.append(cur)
            cur = [op]
        elif cur is None:
            pre.append(op)
        else:
            cur.append(op)
    if cur:
        tiles.append(cur)
    return pre, tiles


def yolo_prefix_split(iso: Iso, settle_s: float = 0.05) -> dict:
    plan = json.loads((YOLO_BUILD / "plan.json").read_text())
    last = plan["memory_plan"]["layers"][0]
    ops = slice_ops_until_layers(plan, {last["name"]})
    pre, tiles = split_oh_tiles(ops)
    print(
        f"\n=== YOLO prefix SPLIT {len(tiles)} OH tiles settle={settle_s}s pre={len(pre)} ===",
        flush=True,
    )
    input_bytes, obuf_base, _hbm = _upload_yolo_inputs(iso, plan)
    oh, ow, c = int(last["output_hw"][0]), int(last["output_hw"][1]), int(last["output_c"])
    out_off = int(last["output_off"])
    oh_start = 0
    for ti, tile in enumerate(tiles):
        im = next(op for op in tile if op.get("unit") == "im2col")
        this_oh = int(im["args"]["addr_s"])
        chunk = pre + tile if ti == 0 else tile
        words = encode_ops(plan, chunk + [{"kind": "end"}])
        data = inst_words_to_bin(words)
        iso.x.write(INST_BASE, data)
        iso.r.start_decoder(len(data) // 4)
        iso.r.poll_done(60.0)
        time.sleep(settle_s)
        nbytes = this_oh * ow * c * 4
        addr = obuf_base + out_off + oh_start * ow * c * 4
        raw = read_c2h(iso.x, addr, nbytes)
        got = np.frombuffer(raw, dtype=np.float32).reshape(this_oh, ow, c)
        print(
            f"  tile{ti} oh[{oh_start}:{oh_start + this_oh}] ran words={len(words)} "
            f"got_range=[{got.min():.4g},{got.max():.4g}] mean={got.mean():.4g}",
            flush=True,
        )
        pre = []
        oh_start += this_oh

    nbytes = oh * ow * c * 4
    raw = read_c2h(iso.x, obuf_base + out_off, nbytes)
    got = np.frombuffer(raw, dtype=np.float32).reshape(oh, ow, c)
    ref, _ = run_yolo_compiler_golden(YOLO_IMG, "int8", 1, str(YOLO_PARSED))
    s = _stats(got, ref)
    corr = float(np.corrcoef(got.ravel(), ref.ravel())[0, 1])
    print(
        f"  SPLIT max_abs={s['max_abs']:.6g} corr={corr:.4f}",
        flush=True,
    )
    analyze_spatial(got, ref, chunk=25)
    return {"pass": s["max_abs"] <= 1e-3, "stats": s, "corr": corr, "mode": "split"}


def read_c2h(x, addr: int, nbytes: int, chunk: int = 256) -> bytes:
    """Host C2H must stay at 256B. A single 4KB C2H has wedged this PCIe link."""
    if hasattr(x, "read") and chunk == 256:
        return x.read(addr, nbytes)
    raw = bytearray()
    off = 0
    while off < nbytes:
        n = min(chunk, nbytes - off)
        raw.extend(x._read_once(addr + off, n))
        off += n
    return bytes(raw)


def _pix_match(got: bytes, exp: bytes, pix_bytes: int) -> tuple[int, int, int]:
    n_pix = min(len(got), len(exp)) // pix_bytes
    same = 0
    first = -1
    for p in range(n_pix):
        sl = slice(p * pix_bytes, (p + 1) * pix_bytes)
        if got[sl] == exp[sl]:
            same += 1
        elif first < 0:
            first = p
    return same, n_pix, first


def _abc_verdict(act_ok: bool, obuf_eq_prev: bool | None, resident_ok: bool, sw_ok: bool) -> str:
    if obuf_eq_prev:
        return "NO_START (job2 OBUF identical to job1)"
    if act_ok and resident_ok and sw_ok:
        return "CLEAN"
    if (not act_ok) and resident_ok:
        return "INPUT (IBUF act stale/partial; DCIM matches resident IBUF)"
    if act_ok and (not resident_ok):
        return "DCIM_FPGA (IBUF act exact, compute != resident matmul)"
    if (not act_ok) and (not resident_ok):
        return "INPUT_AND_COMPUTE (act wrong and OBUF != resident matmul)"
    if act_ok and resident_ok and (not sw_ok):
        return "PACK_MISMATCH (resident matmul matches OBUF, software golden does not)"
    return "UNCLASSIFIED"


def analyze_spatial(got: np.ndarray, ref: np.ndarray, chunk: int = 25) -> None:
    oh, ow, c = got.shape
    print(
        f"  range got=[{got.min():.4g},{got.max():.4g}] mean={got.mean():.4g} "
        f"ref=[{ref.min():.4g},{ref.max():.4g}] mean={ref.mean():.4g} "
        f"got_zero={(got == 0).mean():.3f} ref_zero={(ref == 0).mean():.3f}",
        flush=True,
    )
    for y0 in range(0, oh, chunk):
        y1 = min(y0 + chunk, oh)
        g, r = got[y0:y1], ref[y0:y1]
        cc = float(np.corrcoef(g.ravel(), r.ravel())[0, 1]) if g.size > 8 else 0.0
        print(
            f"  oh[{y0}:{y1}] max_abs={np.max(np.abs(g - r)):.4g} corr={cc:.4f}",
            flush=True,
        )
    for ch in range(c):
        g, r = got[..., ch], ref[..., ch]
        cc = float(np.corrcoef(g.ravel(), r.ravel())[0, 1]) if g.size > 8 else 0.0
        print(
            f"  ch{ch:02d} max_abs={np.max(np.abs(g - r)):.4g} corr={cc:.4f} "
            f"got_mean={g.mean():.4g} ref_mean={r.mean():.4g}",
            flush=True,
        )
    best = (-1.0, 0, 0)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            ys, ye = max(0, dy), min(oh, oh + dy)
            xs, xe = max(0, dx), min(ow, ow + dx)
            g = got[ys:ye, xs:xe]
            r = ref[ys - dy:ye - dy, xs - dx:xe - dx]
            if g.size < 64 or g.shape != r.shape:
                continue
            cc = float(np.corrcoef(g.ravel(), r.ravel())[0, 1])
            if cc > best[0]:
                best = (cc, dy, dx)
    print(f"  best spatial shift dy={best[1]} dx={best[2]} corr={best[0]:.4f}", flush=True)
    t0 = got[:chunk]
    for y0 in range(chunk, oh, chunk):
        y1 = min(y0 + chunk, oh)
        g = got[y0:y1]
        n = min(g.shape[0], t0.shape[0])
        same = np.array_equal(g[:n], t0[:n])
        cc = float(np.corrcoef(g[:n].ravel(), t0[:n].ravel())[0, 1]) if n > 1 else 0.0
        print(f"  got[{y0}:{y1}] vs got[0:{n}] identical={same} corr={cc:.4f}", flush=True)


def sw_im2col_tile(feat_hwc: np.ndarray, kh: int, kw: int, sh: int, sw: int,
                   ph: int, pw: int, oh: int, ow: int, cin: int, row_stride: int) -> bytes:
    """Match im2col_unit: NHWC, copy cin bytes/pixel, pad each OH*OW row to row_stride."""
    h, w, _cpad = feat_hwc.shape
    out = np.zeros((oh * ow, row_stride), dtype=np.int8)
    for oy in range(oh):
        for ox in range(ow):
            col = 0
            for ky in range(kh):
                for kx in range(kw):
                    ih = oy * sh - ph + ky
                    iw = ox * sw - pw + kx
                    if 0 <= ih < h and 0 <= iw < w:
                        out[oy * ow + ox, col:col + cin] = feat_hwc[ih, iw, :cin]
                    col += cin
    return out.tobytes()


def im2col_probe(iso: Iso, tile_idx: int = 0) -> dict:
    plan = json.loads((YOLO_BUILD / "plan.json").read_text())
    im_ops = [o for o in plan["ops"] if o.get("unit") == "im2col"]
    op = im_ops[tile_idx]
    args = op["args"]
    print(f"\n=== im2col tile {tile_idx}/{len(im_ops)} ===", flush=True)
    print(f"  args {args}", flush=True)

    from hw_runner_win import (  # noqa: WPS433
        make_yolo_input, _pad_nhwc_input, write_chunked, verify_write_tail,
        plan_mode, soft_reset_decoder,
    )
    mode = plan_mode(plan)
    am = plan["address_map"]
    obuf_base = int(am["obuf_base"])
    input_bytes = _pad_nhwc_input(make_yolo_input(YOLO_IMG, mode, YOLO_PARSED), plan, mode)
    in_off = int(plan["host_io"]["input_obuf_off"])
    soft_reset_decoder(iso.x)
    write_chunked(iso.x, obuf_base + in_off, input_bytes, 0x100000)
    verify_write_tail(iso.x, obuf_base + in_off, len(input_bytes))

    words = encode_ops(plan, [op, {"kind": "wait_vpu"}, {"kind": "end"}])
    data = inst_words_to_bin(words)
    iso.x.write(INST_BASE, data)
    dst = obuf_base + int(args["dst_addr"])
    iso.x.write(dst, bytes([FILL]) * 4096)
    iso.r.start_decoder(len(data) // 4)
    iso.r.poll_done(30.0)

    src_h, src_w, cin = int(args["src_h"]), int(args["src_w"]), int(args["src_c"])
    oh, ow = int(args["addr_s"]), int(args["addr_t"])
    br = int(args["addr_break"])
    kh, kw = (br >> 24) & 0xFF, (br >> 16) & 0xFF
    sh, sw = (br >> 12) & 0xF, (br >> 8) & 0xF
    ph, pw = (br >> 4) & 0xF, br & 0xF
    row_stride = ((kh * kw * cin + 63) // 64) * 64
    nbytes = oh * ow * row_stride
    dst = obuf_base + int(args["dst_addr"])
    print(f"  reading {nbytes}B im2col dst (then re-read after 1s)", flush=True)
    got1 = read_c2h(iso.x, dst, nbytes)
    time.sleep(1.0)
    got2 = read_c2h(iso.x, dst, nbytes)
    same = got1 == got2
    print(f"  re-read identical={same}", flush=True)
    if not same:
        diff = sum(1 for a, b in zip(got1, got2) if a != b)
        print(f"  WAIT_VPU EARLY: {diff}/{nbytes} bytes changed after 1s", flush=True)

    shape = plan.get("input_shape") or [1, 3, 320, 320]
    _n, _c, in_h, in_w = [int(x) for x in shape]
    padded_c = 16
    feat = np.frombuffer(input_bytes, dtype=np.int8).reshape(in_h, in_w, padded_c)
    in_y0 = int(args["src_addr"]) // (src_w * padded_c)
    feat_crop = feat[in_y0:in_y0 + src_h, :src_w]
    print(f"  crop y[{in_y0}:{in_y0 + src_h}] padH={ph} padW={pw}", flush=True)
    exp = sw_im2col_tile(feat_crop, kh, kw, sh, sw, ph, pw, oh, ow, cin, row_stride)
    n16 = min(len(got1), len(exp)) // 16
    ok = sum(1 for i in range(n16) if got1[i * 16:(i + 1) * 16] == exp[i * 16:(i + 1) * 16])
    print(f"  vs sw_im2col {ok}/{n16} words", flush=True)
    if ok != n16:
        for i in range(n16):
            if got1[i * 16:(i + 1) * 16] != exp[i * 16:(i + 1) * 16]:
                print(f"  first mismatch word {i} got={got1[i*16:i*16+16].hex()} exp={exp[i*16:i*16+16].hex()}", flush=True)
                break
        g = np.frombuffer(got1, dtype=np.int8)
        e = np.frombuffer(exp, dtype=np.int8)
        print(f"  byte match {(g == e).mean():.4f} got_nz={(g != 0).mean():.4f} exp_nz={(e != 0).mean():.4f}", flush=True)
    return {"pass": ok == n16, "ok": ok, "n16": n16, "reread": same}


def _upload_yolo_inputs(iso: Iso, plan: dict) -> tuple[bytes, int, int]:
    from hw_runner_win import (  # noqa: WPS433
        make_yolo_input, _pad_nhwc_input, write_chunked, verify_write_tail,
        plan_mode, soft_reset_decoder,
    )
    mode = plan_mode(plan)
    am = plan["address_map"]
    obuf_base = int(am["obuf_base"])
    hbm_base = int(am.get("hbm_base", 0))
    input_bytes = _pad_nhwc_input(make_yolo_input(YOLO_IMG, mode, YOLO_PARSED), plan, mode)
    weights = (YOLO_BUILD / "weights.bin").read_bytes()
    wb_blob = (YOLO_BUILD / "wb.bin").read_bytes()
    soft_reset_decoder(iso.x)
    off = int(plan["host_io"].get("weights_hbm_off", 0x200000))
    write_chunked(iso.x, hbm_base + off, weights, 0x100000)
    verify_write_tail(iso.x, hbm_base + off, len(weights))
    scratch_map = plan.get("wb_layout", {}).get("scratch_off_by_layer", {})
    scratch_off = min(int(v) for v in scratch_map.values()) if scratch_map else 0x7C0000
    write_chunked(iso.x, obuf_base + scratch_off, wb_blob, 0x100000)
    in_off = int(plan["host_io"]["input_obuf_off"])
    write_chunked(iso.x, obuf_base + in_off, input_bytes, 0x100000)
    verify_write_tail(iso.x, obuf_base + in_off, len(input_bytes))
    return input_bytes, obuf_base, hbm_base


def dcim_probe(iso: Iso, tile_idx: int = 0, prev_obuf: bytes | None = None) -> dict:
    from golden_module_tb import im2col, conv_meta, load_network  # noqa: WPS433

    plan = json.loads((YOLO_BUILD / "plan.json").read_text())
    pre, tiles = split_oh_tiles(plan["ops"])
    pix0 = 0
    for t in tiles[:tile_idx]:
        im = next(op for op in t if op.get("unit") == "im2col")
        pix0 += int(im["args"]["addr_s"]) * int(im["args"]["addr_t"])
    tile = tiles[tile_idx]
    collect = next(op for op in tile if op.get("kind") == "cdma_copy" and "collect tile_obuf" in str(op.get("comment", "")))
    dcim = next(op for op in tile if op.get("kind") == "dcim_layer")
    cut = []
    for op in tile:
        cut.append(op)
        if op is collect:
            continue
        if collect in cut and op.get("kind") == "wait_cdma":
            break
    ops = pre + cut + [{"kind": "end"}]
    print(f"\n=== DCIM OH tile {tile_idx} ISOLATED pix0={pix0} ===", flush=True)
    print(f"  ops={len(ops)} collect={collect}", flush=True)
    print(
        f"  dcim act_base_word={dcim.get('act_base_word')} "
        f"act_stride={dcim.get('act_stride_words')} "
        f"wei0={dcim.get('wei_base_words', [None])[0]} pixels={dcim.get('num_pixels')}",
        flush=True,
    )

    input_bytes, obuf_base, _hbm = _upload_yolo_inputs(iso, plan)
    words = encode_ops(plan, ops)
    data = inst_words_to_bin(words)
    iso.x.write(INST_BASE, data)
    iso.r.start_decoder(len(data) // 4)
    iso.r.poll_done(60.0)

    n = int(collect["length"])
    dst_off = int(collect["dst"][1])
    n_pix = int(dcim.get("num_pixels") or (n // 64))
    act_word = int(dcim.get("act_base_word", 128))
    act_stride = int(dcim.get("act_stride_words", 8))
    wei_word = int((dcim.get("wei_base_words") or [0])[0])
    act_bytes = n_pix * act_stride * 16
    wei_bytes = 2048
    print(f"  reading collect {n}B VPU+0x{dst_off:x} tile_obuf0 IBUF act {act_bytes}B @word {act_word}", flush=True)
    wexp = (YOLO_BUILD / "weights.bin").read_bytes()[:wei_bytes]
    wgot = read_c2h(iso.x, TILE_IBUF_BASE + wei_word * 16, wei_bytes)
    print(f"  IBUF weights match={wgot == wexp}", flush=True)
    if wgot != wexp:
        okw = sum(1 for i in range(128) if wgot[i * 16:(i + 1) * 16] == wexp[i * 16:(i + 1) * 16])
        print(f"  weight words {okw}/128 head_got={wgot[:16].hex()} head_exp={wexp[:16].hex()}", flush=True)
    got_vpu = read_c2h(iso.x, obuf_base + dst_off, n)
    got_tile = read_c2h(iso.x, TILE_OBUF_BASE, n)
    print(f"  collect vs tile_obuf match={got_vpu == got_tile}", flush=True)
    ibuf_act = read_c2h(iso.x, TILE_IBUF_BASE + act_word * 16, act_bytes)

    net = load_network(str(YOLO_PARSED / "network.json"))
    meta = conv_meta(net, "model.0.conv")
    shape = plan.get("input_shape") or [1, 3, 320, 320]
    _n, cin, in_h, in_w = [int(x) for x in shape]
    feat_pad = np.frombuffer(input_bytes, dtype=np.int8).reshape(in_h, in_w, -1)
    feat = feat_pad[:, :, :cin]
    cols = im2col(feat, meta)
    npz = np.load(YOLO_PARSED / "weights" / "model_0_conv.npz")
    w = npz["weight_int8"].reshape(meta.out_ch, -1).astype(np.int32)
    if w.shape[1] < cols.shape[1]:
        w = np.pad(w, ((0, 0), (0, cols.shape[1] - w.shape[1])))
    tile_cols = cols[pix0:pix0 + n_pix]
    exp_act = tile_cols.astype(np.int8).tobytes()
    exp = (tile_cols.astype(np.int32) @ w[:, :cols.shape[1]].T).astype(np.int32)
    got = np.frombuffer(got_vpu, dtype=np.int32).reshape(n_pix, 16)
    same = int((got == exp).sum())
    tot = got.size
    max_abs = int(np.max(np.abs(got.astype(np.int64) - exp.astype(np.int64))))
    cc = float(np.corrcoef(got.ravel().astype(np.float64), exp.ravel().astype(np.float64))[0, 1])
    print(
        f"  INT32 vs software exact {same}/{tot} max_abs={max_abs} corr={cc:.4f} "
        f"got_range=[{got.min()},{got.max()}] exp_range=[{exp.min()},{exp.max()}]",
        flush=True,
    )
    if same != tot:
        bad = np.where(~np.all(got == exp, axis=1))[0]
        rows = sorted({int(i // 160) for i in bad})
        print(
            f"  bad pixels {len(bad)} first={bad[:8].tolist()} last={bad[-4:].tolist()} "
            f"oh_rows={rows} contiguous={len(bad) == (bad[-1] - bad[0] + 1)}",
            flush=True,
        )
        i0 = int(bad[0])
        print(f"  first px {i0} got={got[i0].tolist()} exp={exp[i0].tolist()}", flush=True)

    act_same, act_n, act_first = _pix_match(ibuf_act, exp_act, act_stride * 16)
    act_ok = act_same == act_n
    print(
        f"  ABC-A IBUF act vs sw im2col {act_same}/{act_n} first_bad_px={act_first} match={act_ok}",
        flush=True,
    )
    if not act_ok and act_first >= 0:
        p = act_first
        sl = slice(p * act_stride * 16, (p + 1) * act_stride * 16)
        print(f"  ABC-A px{p} got={ibuf_act[sl][:16].hex()} exp={exp_act[sl][:16].hex()}", flush=True)

    obuf_eq_prev = None
    if prev_obuf is not None:
        obuf_eq_prev = got_tile == prev_obuf
        print(f"  ABC-B tile_obuf vs prev job identical={obuf_eq_prev} len={len(got_tile)}/{len(prev_obuf)}", flush=True)
        if not obuf_eq_prev:
            same_b, n_b, first_b = _pix_match(got_tile, prev_obuf, 64)
            print(f"  ABC-B vs prev exact_px={same_b}/{n_b} first_diff_px={first_b}", flush=True)

    resident = np.frombuffer(ibuf_act, dtype=np.int8).reshape(n_pix, act_stride * 16)
    k = min(resident.shape[1], w.shape[1])
    exp_res = (resident[:, :k].astype(np.int32) @ w[:, :k].T).astype(np.int32)
    got_tile_i = np.frombuffer(got_tile, dtype=np.int32).reshape(n_pix, 16)
    same_c = int((got_tile_i == exp_res).sum())
    max_c = int(np.max(np.abs(got_tile_i.astype(np.int64) - exp_res.astype(np.int64))))
    resident_ok = same_c == tot
    print(
        f"  ABC-C OBUF vs resident IBUF matmul exact {same_c}/{tot} max_abs={max_c} match={resident_ok}",
        flush=True,
    )
    if not resident_ok:
        bad_c = np.where(~np.all(got_tile_i == exp_res, axis=1))[0]
        print(f"  ABC-C first_bad_px={int(bad_c[0]) if len(bad_c) else -1} n_bad_px={len(bad_c)}", flush=True)

    sw_ok = same == tot
    verdict = _abc_verdict(act_ok, obuf_eq_prev, resident_ok, sw_ok)
    print(f"  ABC-VERDICT tile{tile_idx}: {verdict}", flush=True)

    ABC_DIR.mkdir(parents=True, exist_ok=True)
    (ABC_DIR / f"tile{tile_idx}_obuf.bin").write_bytes(got_tile)
    (ABC_DIR / f"tile{tile_idx}_ibuf_act.bin").write_bytes(ibuf_act)

    return {
        "pass": sw_ok,
        "exact": same,
        "tot": tot,
        "max_abs": max_abs,
        "corr": cc,
        "obuf": got_tile,
        "act_ok": act_ok,
        "act_first": act_first,
        "obuf_eq_prev": obuf_eq_prev,
        "resident_ok": resident_ok,
        "verdict": verdict,
    }


def dcim_lock(iso: Iso) -> dict:
    """PCIe-reset session: tile0 then tile1, A/B/C lock. Do not PCIe-reset between."""
    print("\n=== DCIM ABC LOCK tile0 then tile1 (no PCIe reset between) ===", flush=True)
    r0 = dcim_probe(iso, tile_idx=0)
    r1 = dcim_probe(iso, tile_idx=1, prev_obuf=r0.get("obuf"))
    print(
        f"\nLOCK tile0 verdict={r0.get('verdict')} exact={r0.get('exact')}/{r0.get('tot')}\n"
        f"LOCK tile1 verdict={r1.get('verdict')} exact={r1.get('exact')}/{r1.get('tot')} "
        f"A_act_ok={r1.get('act_ok')} A_first={r1.get('act_first')} "
        f"B_eq_prev={r1.get('obuf_eq_prev')} C_resident_ok={r1.get('resident_ok')}",
        flush=True,
    )
    return {"tile0": {k: v for k, v in r0.items() if k != "obuf"},
            "tile1": {k: v for k, v in r1.items() if k != "obuf"},
            "pass": bool(r0.get("pass") and r1.get("pass"))}


def _dcim_exp_and_got(input_bytes, plan, pix0, n_pix, got_vpu):
    from golden_module_tb import im2col, conv_meta, load_network  # noqa: WPS433
    net = load_network(str(YOLO_PARSED / "network.json"))
    meta = conv_meta(net, "model.0.conv")
    shape = plan.get("input_shape") or [1, 3, 320, 320]
    _n, cin, in_h, in_w = [int(x) for x in shape]
    feat_pad = np.frombuffer(input_bytes, dtype=np.int8).reshape(in_h, in_w, -1)
    feat = feat_pad[:, :, :cin]
    cols = im2col(feat, meta)
    npz = np.load(YOLO_PARSED / "weights" / "model_0_conv.npz")
    w = npz["weight_int8"].reshape(meta.out_ch, -1).astype(np.int32)
    if w.shape[1] < cols.shape[1]:
        w = np.pad(w, ((0, 0), (0, cols.shape[1] - w.shape[1])))
    exp = (cols[pix0:pix0 + n_pix].astype(np.int32) @ w[:, :cols.shape[1]].T)
    got = np.frombuffer(got_vpu, dtype=np.int32).reshape(n_pix, 16)
    same = int((got == exp).sum())
    tot = got.size
    max_abs = int(np.max(np.abs(got.astype(np.int64) - exp.astype(np.int64))))
    cc = float(np.corrcoef(got.ravel().astype(np.float64), exp.ravel().astype(np.float64))[0, 1])
    print(
        f"  INT32 exact {same}/{tot} max_abs={max_abs} corr={cc:.4f} "
        f"got_range=[{got.min()},{got.max()}] exp_range=[{exp.min()},{exp.max()}]",
        flush=True,
    )
    return {"pass": same == tot, "exact": same, "tot": tot, "max_abs": max_abs, "corr": cc}


def _tile_through_collect(tile: list) -> list:
    collect = next(op for op in tile if op.get("kind") == "cdma_copy" and "collect tile_obuf" in str(op.get("comment", "")))
    cut = []
    for op in tile:
        cut.append(op)
        if op is collect:
            continue
        if collect in cut and op.get("kind") == "wait_cdma":
            break
    return cut


def dcim_host_ibuf(iso: Iso, tile_idx: int = 0) -> dict:
    """Fill IBUF from host, run only dcim_layer. Distinguishes CDMA race vs DCIM compute."""
    from golden_module_tb import (  # noqa: WPS433
        im2col, conv_meta, load_network, pack_weight_tile,
    )
    from hw_runner_win import write_chunked, verify_write_tail, plan_mode, make_yolo_input, _pad_nhwc_input, soft_reset_decoder  # noqa: WPS433

    plan = json.loads((YOLO_BUILD / "plan.json").read_text())
    pre, tiles = split_oh_tiles(plan["ops"])
    pix0 = 0
    for t in tiles[:tile_idx]:
        im = next(op for op in t if op.get("unit") == "im2col")
        pix0 += int(im["args"]["addr_s"]) * int(im["args"]["addr_t"])
    tile = tiles[tile_idx]
    dcim = next(op for op in tile if op.get("kind") == "dcim_layer")
    n_pix = int(dcim["num_pixels"])
    act_word = int(dcim["act_base_word"])
    act_stride = int(dcim["act_stride_words"])
    wei_word = int(dcim["wei_base_words"][0])

    net = load_network(str(YOLO_PARSED / "network.json"))
    meta = conv_meta(net, "model.0.conv")
    mode = plan_mode(plan)
    feat_pad = _pad_nhwc_input(make_yolo_input(YOLO_IMG, mode, YOLO_PARSED), plan, mode)
    shape = plan.get("input_shape") or [1, 3, 320, 320]
    _n, cin, in_h, in_w = [int(x) for x in shape]
    feat = np.frombuffer(feat_pad, dtype=np.int8).reshape(in_h, in_w, -1)[:, :, :cin]
    cols = im2col(feat, meta)
    npz = np.load(YOLO_PARSED / "weights" / "model_0_conv.npz")
    w = npz["weight_int8"].reshape(meta.out_ch, -1).astype(np.int32)
    if w.shape[1] < cols.shape[1]:
        w = np.pad(w, ((0, 0), (0, cols.shape[1] - w.shape[1])))
    tile_cols = cols[pix0:pix0 + n_pix]
    act_blob = tile_cols.astype(np.int8).tobytes()
    wei_ints = pack_weight_tile(meta, npz["weight_int8"], 0)
    wei_blob = b"".join(int(e).to_bytes(16, "little") for e in wei_ints)
    exp = (tile_cols.astype(np.int32) @ w[:, :cols.shape[1]].T).astype(np.int32)

    print(
        f"\n=== DCIM HOST-IBUF tile {tile_idx} pix0={pix0} n_pix={n_pix} "
        f"wei@{wei_word} act@{act_word} ===",
        flush=True,
    )
    soft_reset_decoder(iso.x)
    write_chunked(iso.x, TILE_IBUF_BASE + wei_word * 16, wei_blob, 4096)
    write_chunked(iso.x, TILE_IBUF_BASE + act_word * 16, act_blob, 4096)
    verify_write_tail(iso.x, TILE_IBUF_BASE + wei_word * 16, len(wei_blob))
    wgot = read_c2h(iso.x, TILE_IBUF_BASE + wei_word * 16, len(wei_blob))
    agot = read_c2h(iso.x, TILE_IBUF_BASE + act_word * 16, len(act_blob))
    print(f"  host IBUF weights match={wgot == wei_blob} act match={agot == act_blob}", flush=True)
    if agot != act_blob:
        same_a, n_a, first_a = _pix_match(agot, act_blob, act_stride * 16)
        print(f"  host act px {same_a}/{n_a} first_bad={first_a}", flush=True)
        return {"pass": False, "reason": "host_ibuf_write_mismatch"}

    ops = [dcim, {"kind": "wait_dcim", "layer": dcim.get("layer")}, {"kind": "end"}]
    words = encode_ops(plan, ops)
    data = inst_words_to_bin(words)
    iso.x.write(INST_BASE, data)
    iso.r.start_decoder(len(data) // 4)
    iso.r.poll_done(60.0)

    n = n_pix * 64
    got_tile = read_c2h(iso.x, TILE_OBUF_BASE, n)
    got = np.frombuffer(got_tile, dtype=np.int32).reshape(n_pix, 16)
    same = int((got == exp).sum())
    tot = got.size
    max_abs = int(np.max(np.abs(got.astype(np.int64) - exp.astype(np.int64))))
    cc = float(np.corrcoef(got.ravel().astype(np.float64), exp.ravel().astype(np.float64))[0, 1])
    print(
        f"  HOST-IBUF INT32 exact {same}/{tot} max_abs={max_abs} corr={cc:.4f}",
        flush=True,
    )
    if same != tot:
        bad = np.where(~np.all(got == exp, axis=1))[0]
        print(
            f"  bad pixels {len(bad)} first={int(bad[0])} last={int(bad[-1])} "
            f"contiguous={len(bad) == (bad[-1] - bad[0] + 1)}",
            flush=True,
        )
    print(
        f"  HOST-IBUF-VERDICT: {'CDMA_RACE (DCIM ok without CDMA)' if same == tot else 'DCIM_FPGA (still wrong without CDMA)'}",
        flush=True,
    )
    return {"pass": same == tot, "exact": same, "tot": tot, "max_abs": max_abs, "corr": cc}


def dcim_seq(iso: Iso) -> dict:
    """One INST stream: preamble + OH tile0 + OH tile1, compare tile1 INT32."""
    plan = json.loads((YOLO_BUILD / "plan.json").read_text())
    pre, tiles = split_oh_tiles(plan["ops"])
    t0, t1 = _tile_through_collect(tiles[0]), _tile_through_collect(tiles[1])
    collect = next(op for op in t1 if op.get("kind") == "cdma_copy" and "collect tile_obuf" in str(op.get("comment", "")))
    ops = pre + t0 + t1 + [{"kind": "end"}]
    print("\n=== DCIM SEQ tile0 then tile1 in one stream ===", flush=True)
    input_bytes, obuf_base, _hbm = _upload_yolo_inputs(iso, plan)
    words = encode_ops(plan, ops)
    data = inst_words_to_bin(words)
    iso.x.write(INST_BASE, data)
    iso.r.start_decoder(len(data) // 4)
    iso.r.poll_done(60.0)
    n = int(collect["length"])
    dst_off = int(collect["dst"][1])
    got_vpu = read_c2h(iso.x, obuf_base + dst_off, n)
    pix0 = int(tiles[0][0]["args"]["addr_s"]) * int(tiles[0][0]["args"]["addr_t"])
    n_pix = n // 64
    print(f"  collect {n}B pix0={pix0} n_pix={n_pix}", flush=True)
    return _dcim_exp_and_got(input_bytes, plan, pix0, n_pix, got_vpu)


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-large-cdma", action="store_true",
                    help="C2H Busy 后不要再打 512KB 读；只跑 YOLO prefix")
    ap.add_argument("--max-conv", type=int, default=1)
    ap.add_argument("--im2col-probe", action="store_true",
                    help="只跑指定 OH tile 的 im2col，对照软件")
    ap.add_argument("--im2col-tile", type=int, default=0)
    ap.add_argument("--dcim-probe", action="store_true",
                    help="跑到指定 OH tile 的 DCIM collect，对照 INT32 accum")
    ap.add_argument("--dcim-tile", type=int, default=0)
    ap.add_argument("--settle-nops", type=int, default=0,
                    help="在 wait_vpu/wait_dcim 后插入 NOP，验证 handshake 竞态")
    ap.add_argument("--split-tiles", action="store_true",
                    help="按 OH tile 拆开跑，tile 之间 host sleep")
    ap.add_argument("--dcim-seq", action="store_true",
                    help="同一 INST：tile0+tile1 DCIM，对照 tile1 INT32")
    ap.add_argument("--dcim-lock", action="store_true",
                    help="复位后同一会话：tile0 再 tile1，打印 IBUF/OBUF A/B/C 对照")
    ap.add_argument("--dcim-host-ibuf", action="store_true",
                    help="host 直写 IBUF 权重+激活，只跑 dcim_layer，绕开 CDMA")
    args = ap.parse_args()

    iso = Iso()
    st = iso.x.read_u32(REGS_BASE + 0x40)
    print(f"[iso] DECODER_STATUS=0x{st:08x}", flush=True)
    if args.im2col_probe:
        r = im2col_probe(iso, tile_idx=args.im2col_tile)
        print("\n======== SUMMARY ========", flush=True)
        print(r)
        return 0 if r.get("pass") else 1
    if args.dcim_probe:
        r = dcim_probe(iso, tile_idx=args.dcim_tile)
        print("\n======== SUMMARY ========", flush=True)
        print({k: v for k, v in r.items() if k != "obuf"})
        return 0 if r.get("pass") else 1
    if args.dcim_lock:
        r = dcim_lock(iso)
        print("\n======== SUMMARY ========", flush=True)
        print(r)
        return 0 if r.get("pass") else 1
    if args.dcim_host_ibuf:
        r = dcim_host_ibuf(iso, tile_idx=args.dcim_tile)
        print("\n======== SUMMARY ========", flush=True)
        print(r)
        return 0 if r.get("pass") else 1
    if args.dcim_seq:
        r = dcim_seq(iso)
        print("\n======== SUMMARY ========", flush=True)
        print(r)
        return 0 if r.get("pass") else 1
    if args.split_tiles:
        r = yolo_prefix_split(iso)
        print("\n======== SUMMARY ========", flush=True)
        print(r)
        return 0 if r.get("pass") else 1
    if not args.skip_large_cdma:
        large_cdma(iso)
    results = []
    for n in range(1, args.max_conv + 1):
        results.append(yolo_prefix(iso, n, settle_nops=args.settle_nops))
        if not results[-1].get("pass"):
            print("  prefix FAIL — stop", flush=True)
            break
    print("\n======== SUMMARY ========", flush=True)
    for r in results:
        print(r)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
