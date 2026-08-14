"""
xdma_win.py - Windows XDMA driver wrapper using xdma_rw.exe

On-chip data path (default staging=hbm):
  Host -> HBM + INST_BRAM only
  HBM -> CDMA -> on-chip -> compute -> CDMA -> HBM -> Host readback
"""
from __future__ import annotations

import os
import struct
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Optional

_THIS_DIR = Path(__file__).resolve().parent
REPO_ROOT = _THIS_DIR.parent.parent.parent


def _resolve_xdma_rw_exe() -> Path:
    env_path = os.environ.get("XDMA_RW_EXE")
    if env_path:
        return Path(env_path).expanduser()
    for candidate in (
        REPO_ROOT / "tests" / "xdma_exe" / "xdma_rw.exe",
        REPO_ROOT / "tests" / "xdma_exe" / "xdma_rw",
        REPO_ROOT / "tests" / "bin" / "xdma_rw.exe",
        REPO_ROOT / "tests" / "bin" / "xdma_rw",
    ):
        if candidate.exists():
            return candidate
    return REPO_ROOT / "tests" / "xdma_exe" / "xdma_rw.exe"


XDMA_RW_EXE = _resolve_xdma_rw_exe()

try:
    import sys as _sys
    _tools = REPO_ROOT / "tools"
    if str(_tools) not in _sys.path:
        _sys.path.insert(0, str(_tools))
    from chip_config import DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE
except ImportError:
    DCIM_NUM_TILES = 8
    DCIM_INT8_OUT_WORDS_PER_TILE = 4

import hashlib as _hashlib


def _fast_hash(data: bytes) -> bytes:
    """Fast content hash for HBM weight-cache deduplication."""
    return _hashlib.md5(data, usedforsecurity=False).digest()


TILE_OBUF_CHK_SENTINEL = 0x800000

HBM_BASE = 0x0
HBM_OFF_INPUT0 = 0x00000
HBM_OFF_INPUT1 = 0x40000
HBM_OFF_WEIGHT = 0x80000
HBM_OFF_WB = 0xC0000
HBM_OFF_OUTPUT = 0x100000

# HBM weight pool: pre-allocated region for batched weight upload.
# Weights are placed starting after the normal staging region, leaving room for
# inputs (0x00000), weights scratch (0x80000), wb (0xC0000), output (0x100000).
# Pool starts at 2 MB from base, giving 4GB-2MB of space (>>enough for any network).
HBM_OFF_WEIGHT_POOL = 0x200000   # 2 MB offset: safe above all scratch regions

INST_BASE = 0x1_0400_0000

TILE_IBUF_BASE = 0x1_0000_0000
TILE_OBUF_BASE = 0x1_0100_0000
VPU_BUF_BASE = 0x1_0200_0000
WB_BASE = 0x1_0300_0000
WB_SIZE = 0x8000
VPU_BUF_SIZE = 1 << 23
REGS_BASE = 0x1_0500_0000

DEFAULT_TIMEOUT_S = 60.0
XDMA_SUBPROC_TIMEOUT_S = 30.0
# This bitstream hangs C2H at length >= 4096 (HBM and on-chip BRAM). 256 B is proven safe.
C2H_CHUNK_BYTES = 256
CASE_TIMEOUTS: dict[tuple[str, str], float] = {
    ("im2col", "im2col_6x6_s2_c3"): 180.0,
    ("im2col", "im2col_3x3_s2_c32"): 180.0,
    ("im2col", "im2col_3x3_s1_c128"): 180.0,
    ("im2col", "im2col_1x1_c512"): 120.0,
    ("dcim_matmul", "conv6_s2_c3_to16"): 90.0,
    ("dcim_matmul", "conv3_s2_c32_to64"): 90.0,
}


def case_timeout_s(module: str, variant: str, default: float = DEFAULT_TIMEOUT_S) -> float:
    return CASE_TIMEOUTS.get((module, variant), default)

TILE_IBUF_SIZE = 0x80000
TILE_OBUF_SIZE = 0x40000

REG_DECODER_CTRL = 0x38
REG_INST_COUNT = 0x3C
REG_DECODER_STATUS = 0x40


class XDMAWin:
    def __init__(
        self,
        exe_path: Optional[Path] = None,
        verbose: bool = False,
        xdma_timeout_s: float = XDMA_SUBPROC_TIMEOUT_S,
    ):
        self.exe = str(exe_path or XDMA_RW_EXE)
        self.verbose = verbose
        self.xdma_timeout_s = xdma_timeout_s
        if not Path(self.exe).exists():
            raise FileNotFoundError(
                f"xdma_rw.exe not found: {self.exe}. "
                "Set XDMA_RW_EXE, or extract tests/bin.zip so tests/bin/xdma_rw.exe exists."
            )

    def _run(self, args: list[str], check: bool = True) -> subprocess.CompletedProcess:
        cmd = [self.exe] + args
        if self.verbose:
            print(f"  [xdma] {' '.join(cmd)}")
        try:
            result = subprocess.run(
                cmd, capture_output=True, timeout=self.xdma_timeout_s
            )
        except subprocess.TimeoutExpired as exc:
            raise TimeoutError(
                f"xdma_rw.exe hung after {self.xdma_timeout_s}s: {' '.join(cmd)}. "
                "XDMA device may be wedged — replug FPGA or restart the driver."
            ) from exc
        if check and result.returncode != 0:
            raise RuntimeError(
                f"xdma_rw.exe failed (rc={result.returncode}): "
                f"{result.stderr.decode(errors='replace')}"
            )
        return result

    def write(self, address: int, data: bytes) -> None:
        with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
            f.write(data)
            tmp_path = f.name
        try:
            self._run([
                "h2c_0", "write", f"0x{address:x}",
                "-b", "-f", tmp_path, "-l", str(len(data)),
            ])
        finally:
            os.unlink(tmp_path)

    def write_u32(self, address: int, val: int) -> None:
        self.write(address, struct.pack("<I", val & 0xFFFFFFFF))

    def _read_once(self, address: int, nbytes: int) -> bytes:
        with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
            tmp_path = f.name
        try:
            self._run([
                "c2h_0", "read", f"0x{address:x}",
                "-b", "-f", tmp_path, "-l", str(nbytes),
            ])
            return Path(tmp_path).read_bytes()
        finally:
            os.unlink(tmp_path)

    def read(self, address: int, nbytes: int) -> bytes:
        if nbytes <= 0:
            return b""
        if nbytes <= C2H_CHUNK_BYTES:
            return self._read_once(address, nbytes)
        out = bytearray()
        offset = 0
        while offset < nbytes:
            chunk = min(C2H_CHUNK_BYTES, nbytes - offset)
            out.extend(self._read_once(address + offset, chunk))
            offset += chunk
        return bytes(out)

    def read_u32(self, address: int) -> int:
        return struct.unpack("<I", self.read(address, 4))[0]

    def read_obuf_check_region(
        self, dst_off: int, n_words: int, wpt: int = 0
    ) -> bytes:
        """RTL module_tb scatter read from tile_obuf / VPU_BUF."""
        nbytes = n_words * 16
        if dst_off < TILE_OBUF_CHK_SENTINEL:
            return self.read(VPU_BUF_BASE + dst_off, nbytes)

        if wpt <= 0:
            wpt = DCIM_INT8_OUT_WORDS_PER_TILE

        stride = DCIM_NUM_TILES * wpt
        base_off = dst_off - TILE_OBUF_CHK_SENTINEL
        max_word_addr = (base_off >> 4) + n_words
        num_px = (max_word_addr + stride - 1) // stride

        tile_bufs: list[bytes] = []
        for t in range(DCIM_NUM_TILES):
            tile_bufs.append(
                self.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, num_px * wpt * 16)
            )

        out = bytearray()
        for i in range(n_words):
            byte_off = base_off + i * 16
            word_addr = byte_off >> 4
            px = word_addr // stride
            tile_idx = (word_addr % stride) // wpt
            intra_w = word_addr % wpt
            tile_word_addr = px * wpt + intra_w
            off = tile_word_addr * 16
            out.extend(tile_bufs[tile_idx][off : off + 16])
        return bytes(out)


class ChipRunnerWin:
    def __init__(self, xdma: Optional[XDMAWin] = None, verbose: bool = True):
        self.x = xdma or XDMAWin(verbose=verbose)
        self.verbose = verbose
        # Weight/WB cache per (layer_key, hbm_off, nbytes) — only skip if same layer AND same
        # content.  Different layers share the same HBM weight region so we must not reuse
        # another layer's weights even if nbytes happens to match.
        self._hbm_weight_cache: dict[tuple[str, int, int], bytes] = {}
        self._last_weight_key: str = ""   # tracks the current layer being cached

    def _weight_cache_hit(self, layer_key: str, hbm_off: int, data: bytes) -> bool:
        """Return True (and skip upload) if HBM already holds this exact data for this layer."""
        key = (layer_key, hbm_off, len(data))
        h = _fast_hash(data)
        if self._hbm_weight_cache.get(key) == h:
            return True
        self._hbm_weight_cache[key] = h
        return False

    def clear_weight_cache(self) -> None:
        """Invalidate the weight/WB HBM cache (call after FPGA reset or new session)."""
        self._hbm_weight_cache.clear()
        self._last_weight_key = ""

    def preload_all_weights(
        self,
        run_dirs: "list[Path]",
        pool_base: int = None,
    ) -> "dict[str, dict[str, int]]":
        """Upload all weights for a list of case dirs to a dedicated HBM pool.

        Each case dir gets its own sub-map: {filename -> hbm_absolute_offset}.
        Weight files (weight_tile*.hex, wb_init.hex, aux_zero.hex) are uploaded
        once to non-overlapping HBM addresses.  During inference, pass the
        per-case sub-map to upload_hbm() and upload_inst() so those calls skip
        weight re-uploading.

        Returns a dict keyed by run_dir.name -> {fname: hbm_abs_offset}.

        pool_base: HBM byte offset for the start of the pool (default HBM_OFF_WEIGHT_POOL).
        """
        from hbm_flow import staging_writes_for_preload

        if pool_base is None:
            pool_base = HBM_OFF_WEIGHT_POOL

        cursor = pool_base
        result: dict[str, dict[str, int]] = {}
        total_uploaded = 0
        skipped = 0

        self._log(f"\n[preload_all] Scanning {len(run_dirs)} case dirs for weights...")

        for run_dir in run_dirs:
            run_dir = Path(run_dir)
            preload_file = run_dir / "preload.txt"
            if not preload_file.exists():
                continue

            case_map: dict[str, int] = {}
            for hbm_off, fname, nbytes in staging_writes_for_preload(run_dir):
                is_weight_or_wb = (
                    fname.startswith("weight") or fname == "wb_init.hex"
                    or fname == "aux_zero.hex"
                )
                if not is_weight_or_wb:
                    continue
                if fname in case_map:
                    # Same file already allocated for this case (e.g. via ohtile sharing)
                    continue

                # Align to 256 bytes (16-byte word × 16 = DCIM tile alignment)
                cursor = (cursor + 255) & ~255

                # Check content hash against pool cache
                data = hex_to_bin(run_dir / fname)
                pool_key = (run_dir.name, fname)
                h = _fast_hash(data)
                cached = self._hbm_weight_cache.get(pool_key)
                if cached and cached[0] == h:
                    # Already in HBM at the same address from a previous preload
                    case_map[fname] = cached[1]
                    skipped += nbytes
                    self._log(f"  [pool] {run_dir.name}/{fname} -> 0x{cached[1]:x} [CACHED]")
                else:
                    self._log(
                        f"  [pool] {run_dir.name}/{fname} ({nbytes} B) -> HBM+0x{cursor:x}"
                    )
                    self.x.write(HBM_BASE + cursor, data)
                    case_map[fname] = cursor
                    self._hbm_weight_cache[pool_key] = (h, cursor)
                    total_uploaded += nbytes
                cursor += nbytes

            if case_map:
                result[run_dir.name] = case_map

        self._log(
            f"[preload_all] Done. Uploaded {total_uploaded/1024:.1f} KB, "
            f"skipped {skipped/1024:.1f} KB (cached). "
            f"Pool end=0x{cursor:x}"
        )
        return result

    def _log(self, msg: str):
        if self.verbose:
            try:
                print(msg)
            except UnicodeEncodeError:
                print(msg.encode("ascii", errors="replace").decode())

    def upload_hbm(
        self,
        run_dir: Path,
        skip_weights: bool = False,
        weight_hbm_map: "dict[str, int] | None" = None,
    ) -> None:
        """Upload HBM staging data for *run_dir*.

        skip_weights=True: skip weight_tile*.hex and wb_init.hex uploads entirely.
        weight_hbm_map: pre-allocated weight addresses from preload_all_weights().
            When provided, weight files that are already in the pool are skipped
            (they live at fixed addresses and do not need re-uploading).
        The default (False, None) uses a content-hash cache per case: files whose
        content has not changed since the last upload FOR THE SAME LAYER are
        silently skipped.
        """
        from hbm_flow import staging_writes_for_preload

        preload_file = run_dir / "preload.txt"
        if not preload_file.exists():
            raise FileNotFoundError(f"preload.txt not found in {run_dir}")

        # Layer key: use the run_dir name stripped of ohtile suffix so all OH-tiles of
        # the same layer/ctile share the same cache entry.
        #   e.g. "resnet_l10_conv2_ohtile3" -> "resnet_l10_conv2"
        #        "resnet_l30_conv2_ctile0_ohtile2" -> "resnet_l30_conv2_ctile0"
        dir_name = run_dir.name
        import re as _re
        layer_key = _re.sub(r'_ohtile\d+$', '', dir_name)

        last_hbm_off = 0
        last_nbytes = 0
        for hbm_off, fname, nbytes in staging_writes_for_preload(run_dir, weight_hbm_map):
            is_weight_or_wb = fname.startswith("weight") or fname == "wb_init.hex"
            if skip_weights and is_weight_or_wb:
                continue
            # If this file is in the preloaded pool, its address is already fixed in HBM —
            # skip uploading it (the pool address is already in weight_hbm_map).
            if weight_hbm_map and is_weight_or_wb and fname in weight_hbm_map:
                self._log(f"[hbm] {fname} ({nbytes} bytes) -> HBM+0x{hbm_off:x} [POOL, skip]")
                continue
            data = hex_to_bin(run_dir / fname)
            if len(data) != nbytes:
                raise ValueError(f"{fname}: size mismatch {len(data)} != {nbytes}")
            # Content-hash cache: skip re-upload if same layer already has this data in HBM
            if is_weight_or_wb and self._weight_cache_hit(layer_key, hbm_off, data):
                self._log(f"[hbm] {fname} ({nbytes} bytes) -> HBM+0x{hbm_off:x} [CACHED, skip]")
                continue
            self._log(
                f"[hbm] {fname} ({nbytes} bytes) -> HBM+0x{hbm_off:x}"
            )
            self.x.write(HBM_BASE + hbm_off, data)
            last_hbm_off = hbm_off
            last_nbytes = nbytes

        # PCIe h2c write-flush: read back the last byte of the last HBM staging
        # write.  This forces the SmartConnect write buffer to drain so the CDMA
        # sees committed data when the decoder starts immediately after.
        if last_nbytes > 0:
            flush_addr = HBM_BASE + last_hbm_off + last_nbytes - 16
            self.x.read(flush_addr, 16)

        for chk in self._parse_checks_meta(run_dir):
            dst_off = chk["dst_off"]
            n_words = chk["n_words"]
            wpt = chk["wpt"] or DCIM_INT8_OUT_WORDS_PER_TILE
            if dst_off >= TILE_OBUF_CHK_SENTINEL:
                # flat drain layout: need active_tiles × n_tile_words × 16 B
                from hbm_flow import (
                    DCIM_INT8_OUT_CH_PER_TILE,
                    _matmul_n_from_manifest,
                )
                matmul_n = _matmul_n_from_manifest(run_dir)
                active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
                active_tiles = min(active_tiles, DCIM_NUM_TILES)
                stride = DCIM_NUM_TILES * wpt
                n_pixels = (n_words + stride - 1) // stride
                n_tile_words = n_pixels * wpt
                out_bytes = active_tiles * n_tile_words * 16
            else:
                out_bytes = n_words * 16
            self._log(f"[hbm] zero output staging {out_bytes} B @ HBM+0x{HBM_OFF_OUTPUT:x}")
            self.x.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * out_bytes)
            break

    def _parse_checks_meta(self, run_dir: Path) -> list[dict]:
        """Parse checks.txt lines into dicts."""
        checks_file = run_dir / "checks.txt"
        if not checks_file.exists():
            raise FileNotFoundError(f"checks.txt not found in {run_dir}")
        meta = []
        for line in checks_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            name, exp_hex_fname, dst_hex, n_words_str, is_fp32_str = parts[:5]
            wpt = int(parts[5]) if len(parts) > 5 else 0
            meta.append({
                "name": name,
                "exp_hex_fname": exp_hex_fname,
                "dst_off": int(dst_hex, 16),
                "n_words": int(n_words_str),
                "is_fp32": int(is_fp32_str) != 0,
                "wpt": wpt,
            })
        return meta

    def clear_tile_obufs(self, n_words: int, wpt: int = 0) -> None:
        """Zero tile_obuf check regions so inactive tiles match golden (0)."""
        if wpt <= 0:
            wpt = DCIM_INT8_OUT_WORDS_PER_TILE
        stride = DCIM_NUM_TILES * wpt
        num_px = (n_words + stride - 1) // stride
        nbytes = num_px * wpt * 16
        zeros = b"\x00" * nbytes
        self._log(
            f"[obuf] clearing {DCIM_NUM_TILES} tiles x {nbytes} B "
            f"(px={num_px}, wpt={wpt})"
        )
        for t in range(DCIM_NUM_TILES):
            self.x.write(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, zeros)

    def upload_preload(self, run_dir: Path) -> None:
        """Direct preload to on-chip memory (lab path, matches RTL backdoor)."""
        preload_file = run_dir / "preload.txt"
        if not preload_file.exists():
            raise FileNotFoundError(f"preload.txt not found in {run_dir}")

        for line in preload_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            fname, addr_str = line.split()
            address = int(addr_str, 16)
            data = hex_to_bin(run_dir / fname)
            self._log(f"[preload] {fname} ({len(data)} bytes) -> 0x{address:010x}")
            self.x.write(address, data)

    def upload_inst_raw(self, run_dir: Path) -> int:
        data = hex_to_bin_32bit(run_dir / "inst.hex")
        n_words = len(data) // 4
        self._log(f"[inst] {n_words} words ({len(data)} bytes) -> INST_BRAM 0x{INST_BASE:010x}")
        self.x.write(INST_BASE, data)
        return n_words

    def upload_inst(
        self,
        run_dir: Path,
        drain_output: bool = True,
        weight_hbm_map: "dict[str, int] | None" = None,
    ) -> int:
        from hbm_flow import patch_inst_for_hbm

        data = patch_inst_for_hbm(run_dir, drain_output=drain_output,
                                   weight_hbm_map=weight_hbm_map)
        n_words = len(data) // 4
        self._log(f"[inst] {n_words} words ({len(data)} bytes) -> INST_BRAM 0x{INST_BASE:010x}")
        self.x.write(INST_BASE, data)
        return n_words

    def start_decoder(self, n_words: int) -> None:
        self._log(f"[decoder] INST_COUNT={n_words}, starting...")
        print("*** PEAK/DECODER ENABLED now — start power measurement ***", flush=True)
        self.x.write_u32(REGS_BASE + REG_INST_COUNT, n_words)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
        time.sleep(0.001)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

    def poll_done(self, timeout_s: float = 10.0) -> int:
        deadline = time.time() + timeout_s
        last_st = None
        while True:
            st = self.x.read_u32(REGS_BASE + REG_DECODER_STATUS)
            if st != last_st:
                self._log(f"[decoder] STATUS = 0x{st:08x}")
                last_st = st
            if st & 0x80000000:
                raise RuntimeError(f"Decoder ERROR: status=0x{st:08x}")
            if st & 0x2:
                self._log("[decoder] DONE")
                return st
            if time.time() > deadline:
                raise TimeoutError(f"Decoder timeout after {timeout_s}s (status=0x{st:08x})")
            time.sleep(0.002)

    def read_check(
        self, run_dir: Path, from_hbm: bool = False, hbm_out_off: int = HBM_OFF_OUTPUT
    ) -> list[dict]:
        results = []
        for chk in self._parse_checks_meta(run_dir):
            name = chk["name"]
            dst_off = chk["dst_off"]
            n_words = chk["n_words"]
            is_fp32 = chk["is_fp32"]
            wpt = chk["wpt"]
            nbytes = n_words * 16

            if from_hbm:
                if dst_off >= TILE_OBUF_CHK_SENTINEL:
                    # tile_obuf path: drain used flat layout; remap back to expected order
                    from hbm_flow import (
                        hbm_drain_remap,
                        DCIM_INT8_OUT_CH_PER_TILE,
                        _matmul_n_from_manifest,
                    )
                    matmul_n = _matmul_n_from_manifest(run_dir)
                    active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
                    active_tiles = min(active_tiles, DCIM_NUM_TILES)
                    stride = DCIM_NUM_TILES * (wpt or DCIM_INT8_OUT_WORDS_PER_TILE)
                    n_pixels = (n_words + stride - 1) // stride
                    n_tile_words = n_pixels * (wpt or DCIM_INT8_OUT_WORDS_PER_TILE)
                    flat_bytes = active_tiles * n_tile_words * 16
                    addr = HBM_BASE + hbm_out_off
                    self._log(
                        f"[check] '{name}': read {flat_bytes}B flat from HBM 0x{addr:010x} "
                        f"({active_tiles} tile(s) × {n_tile_words} words), then remap"
                    )
                    flat_raw = self.x.read(addr, flat_bytes)
                    got_raw = hbm_drain_remap(run_dir, flat_raw)
                else:
                    # VPU_BUF path: host reads VPU_BUF directly.
                    # RTL race: WAIT_VPU fires before URAM write pipeline commits, so
                    # a drain CDMA reads stale zeros.  Direct host readback is safe
                    # because by the time poll_done() returns the URAM is stable.
                    addr = VPU_BUF_BASE + dst_off
                    self._log(
                        f"[check] '{name}': read {n_words} words from VPU_BUF 0x{addr:010x} "
                        f"(direct, no HBM drain)"
                    )
                    got_raw = self.x.read(addr, nbytes)
            elif dst_off >= TILE_OBUF_CHK_SENTINEL:
                self._log(
                    f"[check] '{name}': scatter read {n_words} words from tile_obuf "
                    f"(wpt={wpt or DCIM_INT8_OUT_WORDS_PER_TILE})"
                )
                got_raw = self.x.read_obuf_check_region(dst_off, n_words, wpt=wpt)
            else:
                addr = VPU_BUF_BASE + dst_off
                self._log(f"[check] '{name}': reading {n_words} words from VPU_BUF 0x{addr:010x}")
                got_raw = self.x.read(addr, nbytes)

            exp_raw = hex_to_bin(run_dir / chk["exp_hex_fname"])[:nbytes]
            results.append(compare_result(name, exp_raw, got_raw, n_words, is_fp32))

        return results

    def run_case(
        self,
        run_dir: Path,
        timeout_s: float = DEFAULT_TIMEOUT_S,
        staging: str = "hbm",
        verify: bool = True,
        weight_hbm_map: "dict[str, int] | None" = None,
        on_before_decoder=None,
        on_decoder_start=None,
        on_decoder_done=None,
    ) -> list[dict]:
        """Run one case.

        staging        : 'hbm' (default) or 'preload' (lab/sim path).
        verify         : if False, skip read_check and return empty pass result.
                         Speeds up E2E inference when verification is not needed.
        weight_hbm_map : per-file HBM address map from preload_all_weights().
                         When supplied, weight uploads are skipped (pool already in HBM)
                         and inst patching uses pool addresses for CDMA src.
        """
        run_dir = Path(run_dir)
        self._log(f"\n{'='*60}")
        self._log(f"Running case: {run_dir.name} (staging={staging}, verify={verify})")
        self._log(f"{'='*60}")

        if staging == "hbm":
            self.upload_hbm(run_dir, weight_hbm_map=weight_hbm_map)
            # Official path: HBM->IBUF load CDMAs + tile_obuf->HBM drain.
            # Duplicate preload filenames (peak act.hex x8) must keep per-line
            # destinations; see hbm_flow._preload_rows.
            n_words = self.upload_inst(run_dir, drain_output=True,
                                        weight_hbm_map=weight_hbm_map)
        else:
            self.upload_preload(run_dir)
            n_words = self.upload_inst_raw(run_dir)
            for chk in self._parse_checks_meta(run_dir):
                if chk["dst_off"] >= TILE_OBUF_CHK_SENTINEL:
                    self.clear_tile_obufs(chk["n_words"], chk["wpt"])
                    break
                else:
                    # VPU_BUF path: zero the output region to prevent stale data
                    # from a previous case contaminating this run's readback.
                    nbytes = chk["n_words"] * 16
                    self._log(
                        f"[preload] zero VPU_BUF output region "
                        f"{nbytes}B @ 0x{VPU_BUF_BASE + chk['dst_off']:011x}"
                    )
                    self.x.write(VPU_BUF_BASE + chk["dst_off"], b"\x00" * nbytes)
                    break

        if on_before_decoder is not None:
            on_before_decoder()
        self.start_decoder(n_words)
        if on_decoder_start is not None:
            on_decoder_start()
        self.poll_done(timeout_s)
        if on_decoder_done is not None:
            on_decoder_done()

        if not verify:
            self._log(f"[result] {run_dir.name}: SKIP verify")
            return [{"name": run_dir.name, "pass": True, "total_words": 0,
                     "passed": 0, "failed": 0, "first_mismatch": None, "mismatches": []}]

        results = self.read_check(run_dir, from_hbm=(staging == "hbm"))

        status = "PASS" if all(r["pass"] for r in results) else "FAIL"
        self._log(f"[result] {run_dir.name}: {status}")
        return results


def parse_inst_words(inst_path: Path) -> list[int]:
    words: list[int] = []
    for line in inst_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        words.append(int(line, 16))
    return words


def inst_words_to_bin(words: list[int]) -> bytes:
    return b"".join(struct.pack("<I", w & 0xFFFFFFFF) for w in words)


def hex_to_bin(hex_path: Path) -> bytes:
    out = bytearray()
    for line in Path(hex_path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("//") or line.startswith("@"):
            continue
        out.extend(bytes.fromhex(line)[::-1])
    return bytes(out)


def hex_to_bin_32bit(hex_path: Path) -> bytes:
    out = bytearray()
    for line in Path(hex_path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("//") or line.startswith("@"):
            continue
        out.extend(struct.pack("<I", int(line, 16)))
    return bytes(out)


def compare_result(name, expected, got, n_words, is_fp32) -> dict:
    import numpy as np

    total_pass = total_fail = 0
    first_mismatch = None
    all_mismatches: list[dict] = []
    for w in range(n_words):
        off = w * 16
        exp_word = expected[off:off + 16]
        got_word = got[off:off + 16]
        if is_fp32:
            exp_fp = np.frombuffer(exp_word, dtype=np.float32)
            got_fp = np.frombuffer(got_word, dtype=np.float32)
            tol = 1e-2 * (np.abs(exp_fp) + 1.0)
            ok = np.allclose(exp_fp, got_fp, atol=tol, rtol=0)
        else:
            ok = exp_word == got_word
        if ok:
            total_pass += 1
        else:
            total_fail += 1
            diffs = [(b, exp_word[b], got_word[b]) for b in range(16) if exp_word[b] != got_word[b]]
            mismatch = {"word": w, "diffs": diffs,
                        "expected": exp_word.hex(), "got": got_word.hex()}
            all_mismatches.append(mismatch)
            if first_mismatch is None:
                if is_fp32:
                    first_mismatch = {"word": w, "expected": exp_fp.tolist(), "got": got_fp.tolist()}
                else:
                    first_mismatch = mismatch

    return {
        "name": name,
        "pass": total_fail == 0,
        "total_words": n_words,
        "passed": total_pass,
        "failed": total_fail,
        "first_mismatch": first_mismatch,
        "mismatches": all_mismatches,
    }
