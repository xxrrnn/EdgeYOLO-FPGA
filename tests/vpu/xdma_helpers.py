#!/usr/bin/env python3
"""
XDMA 读写辅助模块 - 基于 xdma_rw.exe

提供与 tests/xdma_bram/rw_test.ipynb 一致的接口，
使用 xdma_rw.exe 进行 PCIe XDMA 读写操作。

地址映射（参考 scripts/ip/bd/vpu/address.tcl）：
  0x1000_0000  staging global_bram (1MB) - 数据区
  0x1020_0000  inst_bram (1MB) - 指令区
  0x1040_0000  VPU GB (128KB)
  0x1042_0000  VPU WB (128KB)
  0x1044_0000  VPU_AXI_Regs (4KB) - 配置 + 状态 + 解码器控制
"""

from __future__ import annotations

import subprocess
import struct
import time
from pathlib import Path
from dataclasses import dataclass

# 地址映射（与 scripts/ip/bd/vpu/address.tcl 一致）
GLOBAL_BRAM_BASE = 0x10000000   # staging global_bram (1MB) - 数据区
INST_BRAM_BASE = 0x10200000     # inst_bram (1MB) - 指令区
VPU_GB_BASE = 0x10400000        # VPU Global Buffer (128KB)
VPU_WB_BASE = 0x10420000        # VPU Weight Buffer (128KB)
VPU_REGS_BASE = 0x10440000      # VPU AXI Regs (4KB) - 配置 + 状态 + 解码器控制

# 兼容旧代码：CDMA_BASE 已移除（软件不再直接访问 CDMA 寄存器）
CDMA_BASE = None  # 已废弃，由 INST_Decoder 通过 CDMA_Controller 控制

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

# 临时文件目录（使用 Windows 临时目录，因为 xdma_rw.exe 是 Windows 程序）
import tempfile
import os
TEMP_DIR = Path(tempfile.gettempdir()) / "xdma_temp"
TEMP_DIR.mkdir(exist_ok=True)

# BIN 目录（包含 xdma_info.exe）
BIN_DIR = REPO_ROOT / "tests" / "bin"

# 默认配置
CHANNEL = 0
CMD_TIMEOUT_SEC = 30
XDMA_INFO_PATH = BIN_DIR / "xdma_info.exe"

# 全局标志：是否启用 Busy 检查（可以临时禁用以避免干扰 CDMA 传输）
_BUSY_CHECK_ENABLED = True


def disable_busy_check():
    """临时禁用 XDMA Busy 检查（用于 CDMA 传输期间）"""
    global _BUSY_CHECK_ENABLED
    _BUSY_CHECK_ENABLED = False


def enable_busy_check():
    """重新启用 XDMA Busy 检查"""
    global _BUSY_CHECK_ENABLED
    _BUSY_CHECK_ENABLED = True


def check_xdma_busy(max_retries: int = 3, retry_delay: float = 0.1) -> bool:
    """
    检查 XDMA 是否处于 Busy 状态
    
    Args:
        max_retries: 最大重试次数
        retry_delay: 重试间隔（秒）
    
    Returns:
        True 如果所有通道都 Idle，False 如果有通道 Busy
        
    Raises:
        RuntimeError: 如果持续 Busy 超过重试次数
    """
    if not _BUSY_CHECK_ENABLED:
        return True
    
    for attempt in range(max_retries):
        try:
            result = subprocess.run(
                [str(XDMA_INFO_PATH)],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode != 0:
                continue
            
            # 检查输出中是否有 "Busy: true"
            if "Busy:\t\t\ttrue" in result.stdout or "Busy:			true" in result.stdout:
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                    continue
                else:
                    # 持续 Busy，抛出异常
                    raise RuntimeError(
                        "⚠️  XDMA 通道处于 Busy 状态！\n"
                        "   请通过以下方式重置硬件：\n"
                        "   1. Windows 设备管理器 -> 禁用/启用 XDMA 设备\n"
                        "   2. 或重启系统\n"
                        f"   (检测到 {attempt + 1} 次 Busy)"
                    )
            
            # 所有通道都 Idle
            return True
            
        except subprocess.TimeoutExpired:
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
                continue
            raise RuntimeError("xdma_info.exe 执行超时")
    
    return True


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
    """运行 xdma_rw 命令（执行前检查 XDMA 状态）"""
    # 执行前检查 XDMA 是否 Busy
    check_xdma_busy()
    
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


def write_blob(addr: int, data: bytes, channel: int = CHANNEL) -> CmdResult:
    """
    写入数据块（便利函数）
    
    Args:
        addr: 目标地址
        data: 要写入的数据
        channel: DMA 通道号
        
    Returns:
        命令执行结果
    """
    return xdma_write(addr, data, channel)


def read_blob(addr: int, size: int, channel: int = CHANNEL) -> bytes:
    """
    读取数据块（便利函数）
    
    Args:
        addr: 源地址
        size: 读取字节数
        channel: DMA 通道号
        
    Returns:
        读取的数据
    """
    return xdma_read(addr, size, channel)


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
    print(f"  INST_BRAM:   0x{INST_BRAM_BASE:08X}")
    print(f"  VPU_REGS:    0x{VPU_REGS_BASE:08X}")
