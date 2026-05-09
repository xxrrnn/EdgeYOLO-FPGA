#!/usr/bin/env python3
"""
Large Matrix K-Tiling Test for XDMA DCIM HBM

This script tests end-to-end large matrix multiplication using K-tiling
with the accumulate_type feature to accumulate partial results.

Example: C[M,N] = A[M,K] @ W[K,N] where K > 16 (tile size)
- Split K dimension into tiles of 16
- For each K-tile, compute partial result and accumulate
"""

from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
import subprocess
import time
import numpy as np

# Configuration
CHANNEL = 0
HBM_PORT = 0
CMD_TIMEOUT_SEC = 30
HBM_SEGMENT_SIZE = 0x10000000
# All PCs are reachable via SAXI_00 map: pseudo-channel k starts at k * 256 MB (low 4 GB).
HBM_BASE = HBM_PORT * HBM_SEGMENT_SIZE
BRAM_WINDOW_BYTES = 64 * 1024
BRAM_WORD_BYTES = 32

# Mode constants
MODE_INT8 = 0b110
MODE_INT16 = 0b111

# Accumulate type constants
ACCUM_OVERWRITE = 0  # C = new_result
ACCUM_ADD = 1        # C = C_old + new_result

# Address map (must match scripts/ip/bd/xdma_dcim_hbm/address.tcl)
# Local PE/CDMA/GPIO aperture starts after the 4 GB HBM window at 0x100000000
IBUF_BASE = 0x100000000
OBUF_BASE = 0x100010000
CDMA_BASE = 0x100020000
PE_CFG0_BASE = 0x100030000
PE_CFG1_BASE = 0x100031000
PE_CFG2_BASE = 0x100032000
PE_CFG3_BASE = 0x100033000
PE_CTRL_BASE = 0x100034000
PE_STATUS_BASE = 0x100035000

# CDMA registers
CDMA_CR = 0x00
CDMA_SR = 0x04
CDMA_SA = 0x18
CDMA_SA_MSB = 0x1C
CDMA_DA = 0x20
CDMA_DA_MSB = 0x24
CDMA_BTT = 0x28
CDMA_SR_IDLE = 1 << 1
CDMA_SR_ERR_MASK = 0x00000770

# Find XDMA tool
SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent.parent
BIN_DIR = REPO_ROOT / "tests" / "bin"
XDMA_EXE = None
for candidate in [BIN_DIR / "xdma_rw.exe", BIN_DIR / "xdma_rw"]:
    if candidate.exists():
        XDMA_EXE = candidate
        break

DATA_DIR = SCRIPT_DIR / "data"
READBACK_DIR = SCRIPT_DIR / "readbacks"
REG_DIR = SCRIPT_DIR / "reg_io"
for path in (DATA_DIR, READBACK_DIR, REG_DIR):
    path.mkdir(exist_ok=True)


@dataclass
class CmdResult:
    cmd: list[str]
    returncode: int
    stdout: str
    stderr: str
    elapsed_sec: float

    @property
    def ok(self) -> bool:
        return self.returncode == 0


def run_cmd(cmd: list[str], timeout: int = CMD_TIMEOUT_SEC) -> CmdResult:
    start = time.perf_counter()
    try:
        cp = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return CmdResult(cmd, cp.returncode, cp.stdout, cp.stderr, time.perf_counter() - start)
    except subprocess.TimeoutExpired as exc:
        return CmdResult(cmd, -124, str(exc.stdout or ""), f"TIMEOUT after {timeout}s", time.perf_counter() - start)


def xdma_write(addr: int, payload_path: Path, timeout: int = CMD_TIMEOUT_SEC) -> CmdResult:
    return run_cmd([str(XDMA_EXE), f"h2c_{CHANNEL}", "write", hex(addr), "-b", "-f", str(payload_path)], timeout=timeout)


def xdma_read(addr: int, size: int, out_path: Path, timeout: int = CMD_TIMEOUT_SEC) -> CmdResult:
    if out_path.exists():
        out_path.unlink()
    return run_cmd([str(XDMA_EXE), f"c2h_{CHANNEL}", "read", hex(addr), "-l", hex(size), "-b", "-f", str(out_path)], timeout=timeout)


def mmio_write_u32(addr: int, value: int, label: str = "") -> CmdResult:
    name = label or f"wr_{addr:X}"
    path = REG_DIR / f"{name}.bin"
    path.write_bytes((value & 0xFFFFFFFF).to_bytes(4, "little"))
    return xdma_write(addr, path)


def mmio_read_u32(addr: int, label: str = "") -> tuple[int, CmdResult]:
    name = label or f"rd_{addr:X}"
    path = REG_DIR / f"{name}.bin"
    result = xdma_read(addr, 4, path)
    value = int.from_bytes(path.read_bytes()[:4], "little") if result.ok and path.exists() else 0
    return value, result


def cdma_status() -> int:
    value, result = mmio_read_u32(CDMA_BASE + CDMA_SR, "cdma_sr")
    assert result.ok, "CDMA status read failed"
    return value


def cdma_wait_idle(timeout_sec: float = 2.0) -> int:
    deadline = time.time() + timeout_sec
    last = 0
    while time.time() < deadline:
        last = cdma_status()
        if last & CDMA_SR_ERR_MASK:
            raise RuntimeError(f"CDMA error status: 0x{last:08X}")
        if last & CDMA_SR_IDLE:
            return last
        time.sleep(0.001)
    raise TimeoutError(f"CDMA did not become idle, last status=0x{last:08X}")


def cdma_reset() -> None:
    result = mmio_write_u32(CDMA_BASE + CDMA_CR, 1 << 2, "cdma_reset")
    assert result.ok
    time.sleep(0.01)
    cdma_wait_idle(timeout_sec=2.0)


def cdma_write_addr(reg_lo: int, reg_hi: int, value: int, label: str) -> None:
    lo = value & 0xFFFFFFFF
    hi = (value >> 32) & 0xFFFFFFFF
    result_lo = mmio_write_u32(CDMA_BASE + reg_lo, lo, f"{label}_lo")
    assert result_lo.ok
    result_hi = mmio_write_u32(CDMA_BASE + reg_hi, hi, f"{label}_hi")
    assert result_hi.ok


def cdma_memcpy(src_addr: int, dst_addr: int, size: int, label: str = "cdma") -> None:
    assert size > 0
    cdma_wait_idle(timeout_sec=2.0)
    cdma_write_addr(CDMA_SA, CDMA_SA_MSB, src_addr, f"{label}_sa")
    cdma_write_addr(CDMA_DA, CDMA_DA_MSB, dst_addr, f"{label}_da")
    result = mmio_write_u32(CDMA_BASE + CDMA_BTT, size, f"{label}_btt")
    assert result.ok
    cdma_wait_idle(timeout_sec=5.0)


def pe_status() -> dict:
    status, _ = mmio_read_u32(PE_STATUS_BASE + 0x00, "pe_status")
    error_code, _ = mmio_read_u32(PE_STATUS_BASE + 0x08, "pe_error_code")
    return {
        "raw": status,
        "busy": bool(status & 0x1),
        "done": bool(status & 0x2),
        "error": bool(status & 0x4),
        "config_ready": bool(status & 0x8),
        "error_code": error_code,
    }


def pe_ctrl_value(mode: int, acc: int, accumulate_type: int, start: bool = False, config_valid: bool = True) -> int:
    """
    Build PE control register value.
    Bit layout:
      [0]     = start
      [1]     = config_valid
      [4:2]   = mode (3 bits)
      [9:5]   = acc (5 bits)
      [11:10] = accumulate_type (2 bits)
    """
    return ((1 if start else 0) << 0) | \
           ((1 if config_valid else 0) << 1) | \
           ((mode & 0x7) << 2) | \
           ((acc & 0x1F) << 5) | \
           ((accumulate_type & 0x3) << 10)


def pe_clear_done_if_needed() -> None:
    status = pe_status()
    if status["done"] and not status["busy"]:
        mmio_write_u32(PE_CTRL_BASE, 0x1, "pe_clear_done")
        time.sleep(0.002)
        mmio_write_u32(PE_CTRL_BASE, 0x0, "pe_clear_done_low")


def pe_start(wsrc_base: int, asrc_base: int, dst_base: int, raw_rows: int, 
             mode: int, acc: int, accumulate_type: int) -> dict:
    """Start PE computation with given parameters."""
    pe_clear_done_if_needed()
    
    # Write configuration registers
    mmio_write_u32(PE_CFG0_BASE, wsrc_base, "pe_cfg_wsrc")
    mmio_write_u32(PE_CFG1_BASE, asrc_base, "pe_cfg_asrc")
    mmio_write_u32(PE_CFG2_BASE, dst_base, "pe_cfg_dst")
    mmio_write_u32(PE_CFG3_BASE, raw_rows, "pe_cfg_raw_rows")
    
    # Set config_valid
    ctrl = pe_ctrl_value(mode, acc, accumulate_type, start=False, config_valid=True)
    mmio_write_u32(PE_CTRL_BASE, ctrl, "pe_ctrl_cfg")
    time.sleep(0.002)
    
    # Pulse start
    mmio_write_u32(PE_CTRL_BASE, pe_ctrl_value(mode, acc, accumulate_type, start=True, config_valid=True), "pe_ctrl_start")
    time.sleep(0.002)
    mmio_write_u32(PE_CTRL_BASE, ctrl, "pe_ctrl_start_low")
    
    # Wait for completion
    deadline = time.time() + 5.0
    while time.time() < deadline:
        status = pe_status()
        if status["error"]:
            raise RuntimeError(f"PE error: {status}")
        if status["done"]:
            return status
        time.sleep(0.001)
    raise TimeoutError(f"PE did not complete")


def pack_int8_activation_rows(act: np.ndarray) -> bytes:
    """Pack INT8 activation matrix for PE. Two rows per 256-bit word."""
    assert act.dtype == np.int8 and act.ndim == 2 and act.shape[1] == 16
    payload = bytearray()
    for row in range(0, act.shape[0], 2):
        lo = act[row].astype(np.uint8).tobytes()
        hi = act[row + 1].astype(np.uint8).tobytes() if row + 1 < act.shape[0] else bytes(16)
        payload += lo + hi
    return bytes(payload)


def pack_int8_weight_tile(weight: np.ndarray) -> bytes:
    """Pack INT8 weight tile [16, 8] for PE."""
    assert weight.dtype == np.int8 and weight.shape == (16, 8)
    return weight.astype(np.uint8).tobytes(order="C")


def golden_int8_matmul_tile(act: np.ndarray, weight: np.ndarray) -> np.ndarray:
    """Compute golden INT8 matmul for a single tile."""
    assert act.dtype == np.int8 and weight.dtype == np.int8
    return (act.astype(np.int32) @ weight.astype(np.int32)).astype(np.int32)


def pack_int32_result(result: np.ndarray) -> bytes:
    """Pack INT32 result matrix."""
    assert result.dtype == np.int32 and result.ndim == 2 and result.shape[1] == 8
    return result.astype("<i4").tobytes(order="C")


def decode_int32_result(payload: bytes) -> np.ndarray:
    """Decode INT32 result from PE output."""
    assert len(payload) % 32 == 0
    return np.frombuffer(payload, dtype="<i4").reshape(-1, 8)


def run_large_gemm_test(M: int, K: int, N: int = 8, seed: int = 42):
    """
    Run large matrix multiplication test with K-tiling.
    
    C[M, N] = A[M, K] @ W[K, N]
    
    K is split into tiles of 16. For each tile:
    - First tile: accumulate_type = OVERWRITE
    - Subsequent tiles: accumulate_type = ADD
    """
    assert K % 16 == 0, "K must be multiple of 16"
    assert N == 8, "N must be 8 for INT8 mode"
    
    K_TILES = K // 16
    print(f"\n{'='*60}")
    print(f"Large GEMM Test: M={M}, K={K}, N={N}")
    print(f"K-tiles: {K_TILES}")
    print(f"{'='*60}")
    
    # Generate random test data
    rng = np.random.default_rng(seed)
    A_full = rng.integers(-128, 128, size=(M, K), dtype=np.int8)
    W_full = rng.integers(-128, 128, size=(K, N), dtype=np.int8)
    
    # Compute golden result
    C_golden = (A_full.astype(np.int32) @ W_full.astype(np.int32)).astype(np.int32)
    print(f"Golden result shape: {C_golden.shape}")
    print(f"Golden result sample:\n{C_golden[:4, :]}")
    
    # HBM layout for tiles
    W_HBM_BASE = 0x0000
    A_HBM_BASE = 0x2000
    R_HBM_BASE = 0x8000
    
    # IBUF/OBUF layout
    W_IBUF_OFF = 0x0000
    A_IBUF_OFF = 0x0100
    R_OBUF_OFF = 0x0000
    
    cdma_reset()
    
    # Process each K-tile
    for kt in range(K_TILES):
        print(f"\n--- K-tile {kt}/{K_TILES} ---")
        
        # Extract tile data
        A_tile = A_full[:, kt*16:(kt+1)*16]  # [M, 16]
        W_tile = W_full[kt*16:(kt+1)*16, :]  # [16, 8]
        
        # Pack data
        A_payload = pack_int8_activation_rows(A_tile)
        W_payload = pack_int8_weight_tile(W_tile)
        
        # Write to HBM
        w_hbm_addr = HBM_BASE + W_HBM_BASE + kt * 128  # 128 bytes per weight tile
        a_hbm_addr = HBM_BASE + A_HBM_BASE + kt * (M * 16)  # M*16 bytes per act tile
        
        w_path = DATA_DIR / f"ktile{kt}_weight.bin"
        a_path = DATA_DIR / f"ktile{kt}_act.bin"
        w_path.write_bytes(W_payload)
        a_path.write_bytes(A_payload)
        
        wr_w = xdma_write(w_hbm_addr, w_path)
        assert wr_w.ok, f"Failed to write weight tile {kt}"
        wr_a = xdma_write(a_hbm_addr, a_path)
        assert wr_a.ok, f"Failed to write activation tile {kt}"
        
        # Stage to IBUF via CDMA
        cdma_memcpy(w_hbm_addr, IBUF_BASE + W_IBUF_OFF, len(W_payload), f"kt{kt}_w_to_ibuf")
        cdma_memcpy(a_hbm_addr, IBUF_BASE + A_IBUF_OFF, len(A_payload), f"kt{kt}_a_to_ibuf")
        
        # Determine accumulate type
        accum_type = ACCUM_OVERWRITE if kt == 0 else ACCUM_ADD
        print(f"  accumulate_type = {'OVERWRITE' if accum_type == 0 else 'ADD'}")
        
        # Run PE
        status = pe_start(
            wsrc_base=W_IBUF_OFF,
            asrc_base=A_IBUF_OFF,
            dst_base=R_OBUF_OFF,
            raw_rows=M,
            mode=MODE_INT8,
            acc=0,  # No row accumulation
            accumulate_type=accum_type
        )
        print(f"  PE done: {status}")
    
    # Read back final result
    result_size = M * 8 * 4  # M rows, 8 cols, 4 bytes per int32
    r_hbm_addr = HBM_BASE + R_HBM_BASE
    
    cdma_memcpy(OBUF_BASE + R_OBUF_OFF, r_hbm_addr, result_size, "result_to_hbm")
    
    result_path = READBACK_DIR / "large_gemm_result.bin"
    rd = xdma_read(r_hbm_addr, result_size, result_path)
    assert rd.ok, "Failed to read result"
    
    # Compare
    C_hw = decode_int32_result(result_path.read_bytes())
    print(f"\nHardware result shape: {C_hw.shape}")
    print(f"Hardware result sample:\n{C_hw[:4, :]}")
    
    match = np.array_equal(C_golden, C_hw)
    if match:
        print(f"\n[PASS] Large GEMM test passed!")
    else:
        diff = np.abs(C_golden - C_hw)
        print(f"\n[FAIL] Mismatch detected!")
        print(f"Max diff: {diff.max()}")
        print(f"Diff locations: {np.argwhere(diff > 0)[:10]}")
    
    return match


if __name__ == "__main__":
    if XDMA_EXE is None or not XDMA_EXE.exists():
        print("XDMA tool not found. This script requires hardware.")
        print("Run simulation tests with: ./run_xsim.sh int8")
        exit(1)
    
    print(f"XDMA tool: {XDMA_EXE}")
    print(f"Data dir: {DATA_DIR}")
    
    # Test cases
    test_cases = [
        (16, 32, 8),   # M=16, K=32 (2 tiles), N=8
        (16, 64, 8),   # M=16, K=64 (4 tiles), N=8
        (32, 48, 8),   # M=32, K=48 (3 tiles), N=8
    ]
    
    results = []
    for M, K, N in test_cases:
        try:
            passed = run_large_gemm_test(M, K, N)
            results.append((M, K, N, passed))
        except Exception as e:
            print(f"[ERROR] Test M={M}, K={K}, N={N} failed: {e}")
            results.append((M, K, N, False))
    
    print("\n" + "="*60)
    print("Summary:")
    for M, K, N, passed in results:
        status = "PASS" if passed else "FAIL"
        print(f"  M={M}, K={K}, N={N}: {status}")
