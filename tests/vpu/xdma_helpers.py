#!/usr/bin/env python3
"""
XDMA 读写辅助模块 - 基于 xdma_rw.exe

提供与 tests/xdma_bram/rw_test.ipynb 一致的接口，
使用 xdma_rw.exe 进行 PCIe XDMA 读写操作。

地址映射（参考 scripts/ip/bd/vpu/address.tcl）：
  0x1000_0000  staging global_bram (64KB)
  0x1001_0000  VPU GB (axi_bram_ctrl, 64KB)
  0x1002_0000  VPU WB (axi_bram_ctrl, 64KB)
  0x1003_0000  CDMA 寄存器 (64KB)
  0x1004_0000  VPU_AXI_Regs (4KB)
"""

from __future__ import annotations

import subprocess
import struct
import time
from pathlib import Path
from dataclasses import dataclass

# 地址映射（与 scripts/ip/bd/vpu/address.tcl 一致）
GLOBAL_BRAM_BASE = 0x10000000   # staging global_bram (64KB)
VPU_GB_BASE = 0x10010000        # VPU Global Buffer (64KB)
VPU_WB_BASE = 0x10020000        # VPU Weight Buffer (64KB)
CDMA_BASE = 0x10030000          # CDMA 寄存器 (64KB)
VPU_REGS_BASE = 0x10040000      # VPU AXI Regs (4KB)

# 查找 xdma_rw.exe
SCRIPT_DIR = Path(__file__).parent.resolve()

# 查找 repo root（包含 tests 目录的父目录）
REPO_ROOT = SCRIPT_DIR
for _ in range(5):
    if (REPO_ROOT / "tests" / "bin").exists():
        break
    REPO_ROOT = REPO_ROOT.parent

for candidate in [
    REPO_ROOT / "tests" / "bin" / "xdma_rw.exe",
    REPO_ROOT / "tests" / "bin" / "xdma_rw",
    SCRIPT_DIR / "bin" / "xdma_rw.exe",
    SCRIPT_DIR / "bin" / "xdma_rw",
]:
    if candidate.exists():
        XDMA_EXE = candidate
        break
else:
    XDMA_EXE = REPO_ROOT / "tests" / "bin" / "xdma_rw.exe"

# 临时文件目录
TEMP_DIR = SCRIPT_DIR / "temp"
TEMP_DIR.mkdir(exist_ok=True)

# 默认配置
CHANNEL = 0
CMD_TIMEOUT_SEC = 30


@dataclass
class CmdResult:
    """命令执行结果"""
    cmd: list[str]
    returncode: int
    stdout: str
    stderr: str
    elapsed_sec: float

    @property
    def ok(self) -> bool:
        return self.returncode == 0


def _run_xdma_cmd(cmd: list[str], timeout: int = CMD_TIMEOUT_SEC) -> CmdResult:
    """运行 xdma_rw 命令"""
    start = time.perf_counter()
    try:
        cp = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout
        )
        return CmdResult(cmd, cp.returncode, cp.stdout, cp.stderr, time.perf_counter() - start)
    except subprocess.TimeoutExpired:
        return CmdResult(cmd, -1, "", "Command timeout", time.perf_counter() - start)


def xdma_write(addr: int, data: bytes, channel: int = CHANNEL) -> CmdResult:
    """
    通过 XDMA H2C 通道写入数据
    
    Args:
        addr: 目标地址（设备侧绝对地址）
        data: 要写入的数据
        channel: DMA 通道号（默认 0）
        
    Returns:
        CmdResult 命令执行结果
    """
    temp_file = TEMP_DIR / f"write_{addr:08x}_{len(data)}.bin"
    temp_file.write_bytes(data)
    
    cmd = [str(XDMA_EXE), f"h2c_{channel}", "write", hex(addr), "-b", "-f", str(temp_file)]
    result = _run_xdma_cmd(cmd)
    
    temp_file.unlink(missing_ok=True)
    return result


def xdma_read(addr: int, size: int, channel: int = CHANNEL) -> bytes:
    """
    通过 XDMA C2H 通道读取数据
    
    Args:
        addr: 源地址（设备侧绝对地址）
        size: 读取字节数
        channel: DMA 通道号（默认 0）
        
    Returns:
        读取的数据
        
    Raises:
        RuntimeError: 读取失败时抛出
    """
    temp_file = TEMP_DIR / f"read_{addr:08x}_{size}.bin"
    if temp_file.exists():
        temp_file.unlink()
    
    cmd = [str(XDMA_EXE), f"c2h_{channel}", "read", hex(addr), "-l", hex(size), "-b", "-f", str(temp_file)]
    result = _run_xdma_cmd(cmd)
    
    if not result.ok or not temp_file.exists():
        temp_file.unlink(missing_ok=True)
        raise RuntimeError(f"XDMA read failed at 0x{addr:08X}: {result.stderr}")
    
    data = temp_file.read_bytes()
    temp_file.unlink(missing_ok=True)
    return data


def write_reg(base: int, offset: int, value: int, channel: int = CHANNEL) -> CmdResult:
    """
    写 32 位寄存器
    
    Args:
        base: 寄存器基地址
        offset: 寄存器偏移
        value: 要写入的值（32位）
        channel: DMA 通道号
        
    Returns:
        CmdResult 命令执行结果
    """
    data = struct.pack('<I', value & 0xFFFFFFFF)
    return xdma_write(base + offset, data, channel)


def read_reg(base: int, offset: int, channel: int = CHANNEL) -> int:
    """
    读 32 位寄存器
    
    Args:
        base: 寄存器基地址
        offset: 寄存器偏移
        channel: DMA 通道号
        
    Returns:
        读取的值（32位）
    """
    data = xdma_read(base + offset, 4, channel)
    return struct.unpack('<I', data)[0]


def print_result(name: str, result: CmdResult) -> None:
    """打印命令执行结果"""
    status = "PASS" if result.ok else "FAIL"
    print(f"{name}: {status}, ret={result.returncode}, elapsed={result.elapsed_sec:.3f}s")
    if not result.ok:
        print(f"  CMD: {' '.join(result.cmd)}")
        if result.stderr.strip():
            print(f"  STDERR: {result.stderr.strip()}")


def check_xdma_available() -> bool:
    """检查 XDMA 工具是否可用"""
    return XDMA_EXE.exists()


class XDMADevice:
    """
    XDMA 设备封装类 - 仅支持 exe 模式
    """
    
    def __init__(self, channel: int = 0):
        self.channel = channel
        if not XDMA_EXE.exists():
            raise FileNotFoundError(f"XDMA tool not found: {XDMA_EXE}")
    
    def write_u32(self, addr: int, value: int) -> None:
        """写 32 位值"""
        result = xdma_write(addr, struct.pack('<I', value & 0xFFFFFFFF), self.channel)
        if not result.ok:
            raise RuntimeError(f"Write failed at 0x{addr:08X}: {result.stderr}")
    
    def read_u32(self, addr: int) -> int:
        """读 32 位值"""
        data = xdma_read(addr, 4, self.channel)
        return struct.unpack('<I', data)[0]
    
    def write_blob(self, addr: int, data: bytes) -> None:
        """写入数据块"""
        result = xdma_write(addr, data, self.channel)
        if not result.ok:
            raise RuntimeError(f"Write blob failed at 0x{addr:08X}: {result.stderr}")
    
    def read_blob(self, addr: int, size: int) -> bytes:
        """读取数据块"""
        return xdma_read(addr, size, self.channel)
    
    def close(self) -> None:
        """关闭设备（无操作，保持接口兼容）"""
        pass
    
    def __enter__(self) -> "XDMADevice":
        return self
    
    def __exit__(self, *exc) -> None:
        self.close()


if __name__ == "__main__":
    print(f"XDMA Tool: {XDMA_EXE}")
    print(f"Available: {check_xdma_available()}")
    print(f"\nAddress Map:")
    print(f"  GLOBAL_BRAM: 0x{GLOBAL_BRAM_BASE:08X}")
    print(f"  VPU_GB:      0x{VPU_GB_BASE:08X}")
    print(f"  VPU_WB:      0x{VPU_WB_BASE:08X}")
    print(f"  CDMA:        0x{CDMA_BASE:08X}")
    print(f"  VPU_REGS:    0x{VPU_REGS_BASE:08X}")
