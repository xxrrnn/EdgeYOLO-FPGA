"""Build HBM-first instruction patches for on-chip unit tests.

Data path (host-visible):
  Host --XDMA--> HBM / INST_BRAM
  HBM --CDMA--> tile_ibuf / VPU_BUF / WB  (via inst, prepended)
  compute (DCIM / VPU)
  tile_obuf / VPU_BUF --CDMA--> HBM  (via inst, appended)
  Host --XDMA--> HBM (readback, linear layout == expected.hex)
"""
from __future__ import annotations

from pathlib import Path

try:
    import sys as _sys
    from xdma_win import REPO_ROOT
    _tools = REPO_ROOT / "tools"
    if str(_tools) not in _sys.path:
        _sys.path.insert(0, str(_tools))
    from chip_config import DCIM_INT8_OUT_CH_PER_TILE
except ImportError:
    DCIM_INT8_OUT_CH_PER_TILE = 16

from xdma_win import (
    HBM_BASE,
    HBM_OFF_INPUT0,
    HBM_OFF_INPUT1,
    HBM_OFF_OUTPUT,
    HBM_OFF_WB,
    HBM_OFF_WEIGHT,
    TILE_IBUF_BASE,
    TILE_IBUF_SIZE,
    TILE_OBUF_BASE,
    TILE_OBUF_SIZE,
    VPU_BUF_BASE,
    VPU_BUF_SIZE,
    WB_BASE,
    WB_SIZE,
    TILE_OBUF_CHK_SENTINEL,
    DCIM_NUM_TILES,
    DCIM_INT8_OUT_WORDS_PER_TILE,
    hex_to_bin,
    parse_inst_words,
    inst_words_to_bin,
)

OP_CDMA_COPY = 0x1
OP_WAIT_CDMA = 0x3
OP_WAIT_VPU  = 0x4
OP_WAIT_DCIM = 0x7
OP_END = 0xF


def _header(op: int, flags: int, length: int) -> int:
    return ((op & 0xF) << 28) | ((flags & 0xF) << 24) | (length & 0xFFFFFF)


def _split64(addr: int) -> tuple[int, int]:
    return (addr >> 32) & 0xFFFFFFFF, addr & 0xFFFFFFFF


def cdma_copy(src: int, dst: int, nbytes: int) -> list[int]:
    sm, sl = _split64(src)
    dm, dl = _split64(dst)
    return [
        _header(OP_CDMA_COPY, 0, 20),
        sm,
        sl,
        dm,
        dl,
        nbytes & 0xFFFFFFFF,
        _header(OP_WAIT_CDMA, 0, 0),
    ]


def _tile_ibuf_index(phy_addr: int) -> int | None:
    if phy_addr < TILE_IBUF_BASE:
        return None
    rel = phy_addr - TILE_IBUF_BASE
    t = rel // TILE_IBUF_SIZE
    return t if 0 <= t < DCIM_NUM_TILES else None


def _hbm_src_offset(
    fname: str,
    weight_cursor: list[int],
    weight_hbm_map: "dict[str, int] | None" = None,
) -> int:
    if fname == "act.hex" or fname == "src0.hex" or (fname.startswith("src") and fname[3:4] == "0"):
        return HBM_OFF_INPUT0
    if fname == "src1.hex" or (fname.startswith("src") and fname[3:4] == "1"):
        return HBM_OFF_INPUT1
    if fname.startswith("src"):
        idx = int(fname[3:fname.index(".")])
        return HBM_OFF_INPUT1 + (idx - 1) * 0x40000
    if fname.startswith("weight"):
        if weight_hbm_map and fname in weight_hbm_map:
            return weight_hbm_map[fname]
        return HBM_OFF_WEIGHT + weight_cursor[0]
    if fname == "wb_init.hex":
        if weight_hbm_map and fname in weight_hbm_map:
            return weight_hbm_map[fname]
        return HBM_OFF_WB
    if fname == "aux_zero.hex":
        if weight_hbm_map and fname in weight_hbm_map:
            return weight_hbm_map[fname]
        return HBM_OFF_WEIGHT + weight_cursor[0]
    raise ValueError(f"no HBM staging rule for preload file {fname}")


OP_NOP = 0x0

# Number of NOP cycles to insert after a WB CDMA write before VPU can read WB.
# WB uses URAM/BRAM with a write-to-read pipeline; without the pause the first
# VPU run after a WB load may read stale zeros.
# Workaround until CDMA_COOLDOWN_CYCLES is properly set in RTL.
_WB_SETTLE_NOPS = 512

# Number of NOP cycles inserted between WAIT_VPU and the VPU_BUF drain CDMA.
# VPU_BUF uses URAM; vpu_ready fires ~2 cycles after the last output word is
# written.  Without extra settling time the drain CDMA may start reading before
# the URAM write pipeline has fully committed the last few words.
# Workaround until RTL fixes vpu_ready timing (方案B).
_VPU_SETTLE_NOPS = 256


def _preload_rows(
    run_dir: Path,
    weight_hbm_map: "dict[str, int] | None" = None,
) -> list[tuple[int, str, int, int]]:
    """(hbm_off, fname, nbytes, dst_addr) for every preload.txt line.

    Duplicate filenames (peak broadcasts act.hex to 8 tile IBUFs) must keep
    their per-line destination. Looking up dst by filename would collapse
    them all onto tile0.
    """
    preload = run_dir / "preload.txt"
    if not preload.exists():
        return []

    rows: list[tuple[int, str, int, int]] = []
    weight_cursor = [0]
    for line in preload.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        fname, addr_str = line.split()
        nbytes = len(hex_to_bin(run_dir / fname))
        hbm_off = _hbm_src_offset(fname, weight_cursor, weight_hbm_map)
        if fname.startswith("weight") and not (weight_hbm_map and fname in weight_hbm_map):
            weight_cursor[0] += nbytes
        if fname == "aux_zero.hex" and not (weight_hbm_map and fname in weight_hbm_map):
            weight_cursor[0] += nbytes
        rows.append((hbm_off, fname, nbytes, int(addr_str, 16)))
    return rows


def build_hbm_input_cdma(
    run_dir: Path,
    weight_hbm_map: "dict[str, int] | None" = None,
) -> list[int]:
    """CDMA insts: HBM staging -> on-chip targets listed in preload.txt.

    weight_hbm_map: optional pre-allocated weight address map returned by
    ChipRunnerWin.preload_all_weights().  When provided, weight/wb CDMA src
    addresses are taken from the map instead of the default HBM_OFF_WEIGHT region.

    Entries whose preload target address is in HBM space (< TILE_IBUF_BASE)
    are skipped: those files are already written to HBM by upload_hbm(), and
    the inst.hex itself contains the corresponding HBM->on-chip CDMA transfer
    (e.g. conv_pipeline / mini_network input feature maps).
    """
    insts: list[int] = []
    for hbm_off, fname, nbytes, dst in _preload_rows(run_dir, weight_hbm_map):
        # If the preload target is HBM-space, the file is stored in HBM and the
        # inst.hex already handles moving it on-chip.  Nothing to inject here.
        if dst < TILE_IBUF_BASE:
            continue
        if (
            _tile_ibuf_index(dst) is None
            and not (WB_BASE <= dst < WB_BASE + WB_SIZE)
            and not (VPU_BUF_BASE <= dst < VPU_BUF_BASE + VPU_BUF_SIZE)
        ):
            raise ValueError(
                f"unsupported preload target 0x{dst:016x} for {fname}; "
                "host path only stages HBM -> ibuf / vpu_buf / wb"
            )
        if nbytes == 0:
            # Skip zero-length transfers: issuing a 0-byte CDMA can trip the
            # Xilinx AXI CDMA IP into an error/locked state.
            continue
        insts += cdma_copy(HBM_BASE + hbm_off, dst, nbytes)
        if WB_BASE <= dst < WB_BASE + WB_SIZE:
            # WB BRAM write-to-read settle: insert NOP padding so VPU does not
            # read stale zeros from the URAM write pipeline on the first access.
            insts += [_header(OP_NOP, 0, 0)] * _WB_SETTLE_NOPS
    return insts


def staging_writes_for_preload(
    run_dir: Path,
    weight_hbm_map: "dict[str, int] | None" = None,
) -> list[tuple[int, str, int]]:
    """(hbm_offset, filename, nbytes) triples for host HBM staging.

    weight_hbm_map: when supplied, weight/wb file HBM offsets come from the map
    (pre-allocated pool), allowing the caller to skip re-uploading them.
    """
    return [(hbm_off, fname, nbytes) for hbm_off, fname, nbytes, _dst in
            _preload_rows(run_dir, weight_hbm_map)]


def _preload_dst(run_dir: Path, fname: str) -> int:
    """First preload.txt address for fname. Do not use for CDMA injection."""
    for line in (run_dir / "preload.txt").read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        f, addr_str = line.split()
        if f == fname:
            return int(addr_str, 16)
    raise KeyError(f"{fname} not in preload.txt")


def _matmul_m_from_manifest(run_dir: Path, n_words: int, wpt: int) -> int:
    mf = run_dir / "manifest.txt"
    if mf.exists():
        for line in mf.read_text().splitlines():
            if line.startswith("matmul_m:"):
                return int(line.split(": ", 1)[1])
    stride = DCIM_NUM_TILES * wpt
    return (n_words + stride - 1) // stride


def _matmul_n_from_manifest(run_dir: Path) -> int:
    mf = run_dir / "manifest.txt"
    if mf.exists():
        for line in mf.read_text().splitlines():
            if line.startswith("matmul_n:"):
                return int(line.split(": ", 1)[1])
    return DCIM_NUM_TILES * DCIM_INT8_OUT_CH_PER_TILE


def build_hbm_output_drain(run_dir: Path) -> tuple[list[int], int]:
    """CDMA insts: tile_obuf/VPU_BUF -> HBM.

    VPU_BUF path: one contiguous CDMA (n_words × 16 B).

    tile_obuf path: one CDMA per active tile, each draining that tile's
    complete pixel-sequential words to a contiguous "flat" HBM region.

    Layout in HBM (flat, starting at HBM_OFF_OUTPUT):
        tile 0 : words [0 .. n_tile_words-1]   @ HBM_OFF_OUTPUT
        tile 1 : words [0 .. n_tile_words-1]   @ HBM_OFF_OUTPUT + n_tile_words*16
        ...

    The Python side calls hbm_drain_remap() to convert this flat buffer back to
    the expected.hex scatter order for comparison.

    NOTE: multi-tile drain (active_tiles > 1) requires CDMA_COOLDOWN_CYCLES to
    be sufficiently large in RTL (CDMA_Controller.sv).  Without adequate
    cooldown, back-to-back CDMAs writing to HBM can corrupt each other due to
    SmartConnect write buffer ordering.
    """
    checks = run_dir / "checks.txt"
    if not checks.exists():
        return [], HBM_OFF_OUTPUT

    line = next(l for l in checks.read_text().splitlines() if l.strip() and not l.startswith("#"))
    parts = line.split()
    dst_off = int(parts[2], 16)
    n_words = int(parts[3])
    wpt = int(parts[5]) if len(parts) > 5 else DCIM_INT8_OUT_WORDS_PER_TILE

    hbm_out = HBM_BASE + HBM_OFF_OUTPUT

    if dst_off < TILE_OBUF_CHK_SENTINEL:
        # VPU_BUF path: single contiguous transfer
        return cdma_copy(VPU_BUF_BASE + dst_off, hbm_out, n_words * 16), HBM_OFF_OUTPUT

    matmul_n = _matmul_n_from_manifest(run_dir)
    active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
    active_tiles = min(active_tiles, DCIM_NUM_TILES)  # 不能超过物理 tile 数
    stride = DCIM_NUM_TILES * wpt

    n_pixels = (n_words + stride - 1) // stride
    n_tile_words = n_pixels * wpt

    # One CDMA per active tile: tile_obuf[t][0..n_tile_words-1] -> HBM flat slot t
    insts: list[int] = []
    for t in range(active_tiles):
        src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
        dst = hbm_out + t * n_tile_words * 16
        insts += cdma_copy(src, dst, n_tile_words * 16)

    return insts, HBM_OFF_OUTPUT


def hbm_drain_remap(run_dir: Path, flat_bytes: bytes) -> bytes:
    """Convert flat HBM drain buffer back to expected.hex scatter order.

    flat_bytes layout (from build_hbm_output_drain):
        tile 0 words [0..n_tile_words-1], then tile 1, ...

    Returns a bytes object where byte slice [i*16:(i+1)*16] corresponds to
    expected.hex word index i (same as what read_check compares against).

    Words from inactive tiles are filled with zeros.
    """
    checks = run_dir / "checks.txt"
    if not checks.exists():
        return flat_bytes

    line = next(l for l in checks.read_text().splitlines() if l.strip() and not l.startswith("#"))
    parts = line.split()
    dst_off = int(parts[2], 16)
    n_words = int(parts[3])
    wpt = int(parts[5]) if len(parts) > 5 else DCIM_INT8_OUT_WORDS_PER_TILE

    if dst_off < TILE_OBUF_CHK_SENTINEL:
        # VPU_BUF: no remapping needed, flat == scatter
        return flat_bytes

    matmul_n = _matmul_n_from_manifest(run_dir)
    active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
    active_tiles = min(active_tiles, DCIM_NUM_TILES)  # 不能超过物理 tile 数
    stride = DCIM_NUM_TILES * wpt
    base_word = (dst_off - TILE_OBUF_CHK_SENTINEL) >> 4
    n_pixels = (n_words + stride - 1) // stride
    n_tile_words = n_pixels * wpt

    out = bytearray(n_words * 16)
    flat = flat_bytes
    for i in range(n_words):
        word_addr = base_word + i
        px = word_addr // stride
        tile = (word_addr % stride) // wpt
        intra = word_addr % wpt
        if tile >= active_tiles:
            # inactive tile: zeros (pre-zeroed HBM, not drained)
            pass
        else:
            tile_word = px * wpt + intra
            flat_off = (tile * n_tile_words + tile_word) * 16
            out[i*16:(i+1)*16] = flat[flat_off:flat_off+16]
    return bytes(out)


def patch_inst_for_hbm(
    run_dir: Path,
    drain_output: bool = True,
    weight_hbm_map: "dict[str, int] | None" = None,
) -> bytes:
    """Prepend HBM->on-chip CDMA; append on-chip->HBM drain (default on).

    weight_hbm_map: when supplied, weight/wb CDMA src addresses use the
    pre-allocated pool addresses from ChipRunnerWin.preload_all_weights().

    VPU_BUF path (dst_off < TILE_OBUF_CHK_SENTINEL):
      No drain CDMA is appended. The host reads VPU_BUF directly after
      INST_DECODER finishes (see read_check). This avoids a RTL race where
      WAIT_VPU fires before the URAM write pipeline fully commits, causing
      the drain CDMA to read stale zeros.

    tile_obuf path (dst_off >= TILE_OBUF_CHK_SENTINEL):
      Drain CDMAs are appended (tile_obuf -> HBM flat layout).
    """
    core = parse_inst_words(run_dir / "inst.hex")
    while core and (core[-1] >> 28) & 0xF == OP_END:
        core.pop()

    # Determine output path
    dst_off = 0
    chk_file = run_dir / "checks.txt"
    if chk_file.exists():
        checks_line = next(
            (l for l in chk_file.read_text().splitlines() if l.strip() and not l.startswith("#")),
            ""
        )
        dst_off = int(checks_line.split()[2], 16) if checks_line else 0

    tail: list[int] = []
    barrier: list[int] = []
    if drain_output and dst_off >= TILE_OBUF_CHK_SENTINEL:
        # tile_obuf path only: append drain CDMAs with WAIT_DCIM barrier
        tail = build_hbm_output_drain(run_dir)[0]
        if tail:
            barrier = [_header(OP_WAIT_DCIM, 0, 0)]
    # VPU_BUF path: no drain needed; host reads VPU_BUF directly after done

    patched = (
        build_hbm_input_cdma(run_dir, weight_hbm_map)
        + core + barrier + tail
        + [_header(OP_END, 0, 0)]
    )
    return inst_words_to_bin(patched)
