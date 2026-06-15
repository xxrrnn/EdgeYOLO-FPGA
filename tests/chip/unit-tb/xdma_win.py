"""
xdma_win.py - Windows XDMA driver wrapper using xdma_rw.exe

Provides the same interface as tests/chip/runtime/xdma_driver.py but via
Windows-native xdma_rw.exe from tests/bin/.
"""
from __future__ import annotations

import os
import struct
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Optional

# Resolve xdma_rw.exe path
_THIS_DIR = Path(__file__).resolve().parent
REPO_ROOT = _THIS_DIR.parent.parent.parent
XDMA_RW_EXE = REPO_ROOT / "tests" / "bin" / "xdma_rw.exe"

# ─── Hardware Address Map (from scripts/ip/bd/lite/address.tcl) ───────────────
TILE_IBUF_BASE = 0x1_0000_0000  # + t * 0x80000 per tile (512KB each)
TILE_OBUF_BASE = 0x1_0100_0000  # + t * 0x40000 per tile (256KB each)
VPU_BUF_BASE   = 0x1_0200_0000  # 8MB
VPU_WB_BASE    = 0x1_0300_0000  # 32KB
INST_BASE      = 0x1_0400_0000  # 128KB
REGS_BASE      = 0x1_0500_0000  # 4KB

TILE_IBUF_SIZE = 0x80000   # 512KB
TILE_OBUF_SIZE = 0x40000   # 256KB

# ─── VPU_AXI_Regs offsets (from rtl/vpu/VPU_AXI_Regs.v) ─────────────────────
REG_STATUS         = 0x04
REG_DECODER_CTRL   = 0x38
REG_INST_COUNT     = 0x3C
REG_DECODER_STATUS = 0x40


class XDMAWin:
    """Windows XDMA driver using xdma_rw.exe subprocess calls."""

    def __init__(self, exe_path: Optional[Path] = None, verbose: bool = False):
        self.exe = str(exe_path or XDMA_RW_EXE)
        self.verbose = verbose
        if not Path(self.exe).exists():
            raise FileNotFoundError(f"xdma_rw.exe not found: {self.exe}")

    def _run(self, args: list[str], check: bool = True) -> subprocess.CompletedProcess:
        cmd = [self.exe] + args
        if self.verbose:
            print(f"  [xdma] {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True)
        if check and result.returncode != 0:
            raise RuntimeError(
                f"xdma_rw.exe failed (rc={result.returncode}): "
                f"{result.stderr.decode(errors='replace')}"
            )
        return result

    def write(self, address: int, data: bytes) -> None:
        """Write binary data to FPGA at given AXI address."""
        with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
            f.write(data)
            tmp_path = f.name
        try:
            self._run([
                "h2c_0", "write", f"0x{address:x}",
                "-b", "-f", tmp_path, "-l", str(len(data))
            ])
        finally:
            os.unlink(tmp_path)

    def write_u32(self, address: int, val: int) -> None:
        """Write a single 32-bit value (little-endian) to FPGA."""
        self.write(address, struct.pack("<I", val & 0xFFFFFFFF))

    def read(self, address: int, nbytes: int) -> bytes:
        """Read binary data from FPGA at given AXI address."""
        with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
            tmp_path = f.name
        try:
            self._run([
                "c2h_0", "read", f"0x{address:x}",
                "-b", "-f", tmp_path, "-l", str(nbytes)
            ])
            return Path(tmp_path).read_bytes()
        finally:
            os.unlink(tmp_path)

    def read_u32(self, address: int) -> int:
        """Read a single 32-bit value from FPGA."""
        raw = self.read(address, 4)
        return struct.unpack("<I", raw)[0]


class ChipRunnerWin:
    """High-level chip runner for Windows, reusing module_tb golden data."""

    def __init__(self, xdma: Optional[XDMAWin] = None, verbose: bool = True):
        self.x = xdma or XDMAWin(verbose=verbose)
        self.verbose = verbose

    def _log(self, msg: str):
        if self.verbose:
            try:
                print(msg)
            except UnicodeEncodeError:
                print(msg.encode("ascii", errors="replace").decode())

    # ─── Preload: parse module_tb format and upload ───────────────────────────

    def upload_preload(self, run_dir: Path) -> None:
        """Parse preload.txt and upload each hex file to its physical address."""
        preload_file = run_dir / "preload.txt"
        if not preload_file.exists():
            raise FileNotFoundError(f"preload.txt not found in {run_dir}")

        for line in preload_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != 2:
                continue
            hex_fname, addr_str = parts
            hex_path = run_dir / hex_fname
            address = int(addr_str, 16)
            data = hex_to_bin(hex_path)
            self._log(f"[preload] {hex_fname} ({len(data)} bytes) → 0x{address:010x}")
            self.x.write(address, data)

    def upload_inst(self, run_dir: Path) -> int:
        """Upload inst.hex to INST_BRAM, return word count."""
        inst_path = run_dir / "inst.hex"
        if not inst_path.exists():
            raise FileNotFoundError(f"inst.hex not found in {run_dir}")
        data = hex_to_bin_32bit(inst_path)
        n_words = len(data) // 4
        self._log(f"[inst] {n_words} words ({len(data)} bytes) → INST_BRAM 0x{INST_BASE:010x}")
        self.x.write(INST_BASE, data)
        return n_words

    def start_decoder(self, n_words: int) -> None:
        """Write INST_COUNT and pulse DECODER_CTRL to start execution."""
        self._log(f"[decoder] INST_COUNT={n_words}, starting...")
        self.x.write_u32(REGS_BASE + REG_INST_COUNT, n_words)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
        time.sleep(0.001)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

    def poll_done(self, timeout_s: float = 10.0) -> int:
        """Poll DECODER_STATUS until done or timeout."""
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
                self._log("[decoder] DONE ✓")
                return st
            if time.time() > deadline:
                raise TimeoutError(
                    f"Decoder timeout after {timeout_s}s (status=0x{st:08x})"
                )
            time.sleep(0.002)

    def read_check(self, run_dir: Path) -> list[dict]:
        """Parse checks.txt, read FPGA results, compare with expected."""
        checks_file = run_dir / "checks.txt"
        if not checks_file.exists():
            raise FileNotFoundError(f"checks.txt not found in {run_dir}")

        results = []
        for line in checks_file.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            name, exp_hex_fname, dst_hex, n_words_str, is_fp32_str = parts[:5]
            dst_off = int(dst_hex, 16)
            n_words = int(n_words_str)
            is_fp32 = int(is_fp32_str) != 0
            bytes_per_word = 16  # 128-bit
            nbytes = n_words * bytes_per_word

            # Resolve physical read address from dst_off
            read_addr = self._resolve_check_addr(dst_off)
            self._log(f"[check] '{name}': reading {n_words} words from 0x{read_addr:010x}")
            got_raw = self.x.read(read_addr, nbytes)

            # Load expected
            exp_path = run_dir / exp_hex_fname
            exp_raw = hex_to_bin(exp_path)[:nbytes]

            # Compare
            result = compare_result(name, exp_raw, got_raw, n_words, is_fp32)
            results.append(result)

        return results

    def _resolve_check_addr(self, dst_off: int) -> int:
        """Map checks.txt dst offset to physical AXI address.

        In module_tb, dst_off >= 0x800000 means tile_obuf (TILE_OBUF_CHK_SENTINEL).
        Otherwise it's a VPU_BUF offset.
        """
        TILE_OBUF_CHK_SENTINEL = 0x800000
        if dst_off >= TILE_OBUF_CHK_SENTINEL:
            obuf_off = dst_off - TILE_OBUF_CHK_SENTINEL
            return TILE_OBUF_BASE + obuf_off
        else:
            return VPU_BUF_BASE + dst_off

    def run_case(self, run_dir: Path, timeout_s: float = 10.0) -> list[dict]:
        """Full flow: preload → upload inst → start → poll → check."""
        run_dir = Path(run_dir)
        self._log(f"\n{'='*60}")
        self._log(f"Running case: {run_dir.name}")
        self._log(f"{'='*60}")

        self.upload_preload(run_dir)
        n_words = self.upload_inst(run_dir)
        self.start_decoder(n_words)
        self.poll_done(timeout_s)
        results = self.read_check(run_dir)

        passed = all(r["pass"] for r in results)
        status = "PASS ✓" if passed else "FAIL ✗"
        self._log(f"[result] {run_dir.name}: {status}")
        return results


# ─── Utility Functions ────────────────────────────────────────────────────────

def hex_to_bin(hex_path: Path) -> bytes:
    """Convert a 128-bit-per-line hex file to binary (little-endian word order).

    Each line is a 32-char hex string representing one 128-bit word.
    Stored as 16 bytes in little-endian byte order (byte[0] = LSB).
    """
    hex_path = Path(hex_path)
    out = bytearray()
    for line in hex_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("//") or line.startswith("@"):
            continue
        word_bytes = bytes.fromhex(line)
        # hex file is big-endian (MSB first), reverse for little-endian AXI
        out.extend(word_bytes[::-1])
    return bytes(out)


def hex_to_bin_32bit(hex_path: Path) -> bytes:
    """Convert a 32-bit-per-line hex file (inst.hex) to binary."""
    hex_path = Path(hex_path)
    out = bytearray()
    for line in hex_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("//") or line.startswith("@"):
            continue
        val = int(line, 16)
        out.extend(struct.pack("<I", val))
    return bytes(out)


def compare_result(
    name: str, expected: bytes, got: bytes, n_words: int, is_fp32: bool
) -> dict:
    """Compare expected vs got, return result dict."""
    import numpy as np

    bytes_per_word = 16
    total_pass = 0
    total_fail = 0
    first_mismatch = None

    for w in range(n_words):
        off = w * bytes_per_word
        exp_word = expected[off:off + bytes_per_word]
        got_word = got[off:off + bytes_per_word]

        if is_fp32:
            exp_fp = np.frombuffer(exp_word, dtype=np.float32)
            got_fp = np.frombuffer(got_word, dtype=np.float32)
            tol = 1e-2 * (np.abs(exp_fp) + 1.0)
            if np.allclose(exp_fp, got_fp, atol=tol, rtol=0):
                total_pass += 1
            else:
                total_fail += 1
                if first_mismatch is None:
                    first_mismatch = {
                        "word": w, "expected": exp_fp.tolist(), "got": got_fp.tolist()
                    }
        else:
            if exp_word == got_word:
                total_pass += 1
            else:
                total_fail += 1
                if first_mismatch is None:
                    first_mismatch = {
                        "word": w,
                        "expected": exp_word.hex(),
                        "got": got_word.hex(),
                    }

    return {
        "name": name,
        "pass": total_fail == 0,
        "total_words": n_words,
        "passed": total_pass,
        "failed": total_fail,
        "first_mismatch": first_mismatch,
    }
