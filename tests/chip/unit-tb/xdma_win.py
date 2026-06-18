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
    for candidate in (
        REPO_ROOT / "tests" / "xdma_exe" / "xdma_rw.exe",
        REPO_ROOT / "tests" / "xdma_exe" / "xdma_rw",
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

TILE_OBUF_CHK_SENTINEL = 0x800000

HBM_BASE = 0x0
HBM_OFF_INPUT0 = 0x00000
HBM_OFF_INPUT1 = 0x40000
HBM_OFF_WEIGHT = 0x80000
HBM_OFF_WB = 0xC0000
HBM_OFF_OUTPUT = 0x100000

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
            raise FileNotFoundError(f"xdma_rw.exe not found: {self.exe}")

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

    def read(self, address: int, nbytes: int) -> bytes:
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

    def _log(self, msg: str):
        if self.verbose:
            try:
                print(msg)
            except UnicodeEncodeError:
                print(msg.encode("ascii", errors="replace").decode())

    def upload_hbm(self, run_dir: Path) -> None:
        from hbm_flow import staging_writes_for_preload

        preload_file = run_dir / "preload.txt"
        if not preload_file.exists():
            raise FileNotFoundError(f"preload.txt not found in {run_dir}")

        last_hbm_off = 0
        last_nbytes = 0
        for hbm_off, fname, nbytes in staging_writes_for_preload(run_dir):
            data = hex_to_bin(run_dir / fname)
            if len(data) != nbytes:
                raise ValueError(f"{fname}: size mismatch {len(data)} != {nbytes}")
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

    def upload_inst(self, run_dir: Path, drain_output: bool = True) -> int:
        from hbm_flow import patch_inst_for_hbm

        data = patch_inst_for_hbm(run_dir, drain_output=drain_output)
        n_words = len(data) // 4
        self._log(f"[inst] {n_words} words ({len(data)} bytes) -> INST_BRAM 0x{INST_BASE:010x}")
        self.x.write(INST_BASE, data)
        return n_words

    def start_decoder(self, n_words: int) -> None:
        self._log(f"[decoder] INST_COUNT={n_words}, starting...")
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
    ) -> list[dict]:
        """Run one case. staging='hbm' (default, host HBM+inst only) or 'preload' (lab)."""
        run_dir = Path(run_dir)
        self._log(f"\n{'='*60}")
        self._log(f"Running case: {run_dir.name} (staging={staging})")
        self._log(f"{'='*60}")

        if staging == "hbm":
            self.upload_hbm(run_dir)
            n_words = self.upload_inst(run_dir, drain_output=True)
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

        self.start_decoder(n_words)
        self.poll_done(timeout_s)
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
