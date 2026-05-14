#!/usr/bin/env python3
"""
VPU（rtl 中为 PE/DCIM）+ XDMA + CDMA 主机侧协议。

与 Vivado Block Design 一致，地址见 scripts/ip/bd/vpu/address.tcl。
配置通过 XDMA H2C 写设备侧绝对地址完成。

仅支持 exe 模式（通过 xdma_rw.exe 进行读写）。
"""

from __future__ import annotations

import time
import numpy as np

from xdma_helpers import (
    XDMADevice, xdma_write, xdma_read, write_reg, read_reg,
    GLOBAL_BRAM_BASE, VPU_GB_BASE, VPU_WB_BASE, CDMA_BASE, VPU_REGS_BASE
)

# 地址别名（兼容旧代码）
GLOBAL_BASE = GLOBAL_BRAM_BASE
IBUF_BASE = VPU_GB_BASE
OBUF_BASE = VPU_WB_BASE

# PE 配置寄存器（在 VPU_REGS_BASE 内）
PE_CFG0_BASE = VPU_REGS_BASE + 0x0000
PE_CFG1_BASE = VPU_REGS_BASE + 0x1000
PE_CFG2_BASE = VPU_REGS_BASE + 0x2000
PE_CFG3_BASE = VPU_REGS_BASE + 0x3000
PE_CTRL_BASE = VPU_REGS_BASE + 0x4000
PE_STATUS_BASE = VPU_REGS_BASE + 0x5000

BRAM_WORD_BYTES = 32
MODE_INT8 = 0b110

# CDMA 寄存器偏移
CDMA_CR = 0x00
CDMA_SR = 0x04
CDMA_SA = 0x18
CDMA_SA_MSB = 0x1C
CDMA_DA = 0x20
CDMA_DA_MSB = 0x24
CDMA_BTT = 0x28
CDMA_SR_IDLE = 1 << 1
CDMA_SR_ERR_MASK = (
    (1 << 4) | (1 << 5) | (1 << 6) | (1 << 8) | (1 << 9) | (1 << 10)
)


def cdma_status() -> int:
    """读取 CDMA 状态寄存器"""
    return read_reg(CDMA_BASE, CDMA_SR)


def cdma_wait_idle(timeout_sec: float = 5.0) -> int:
    """等待 CDMA 空闲"""
    deadline = time.time() + timeout_sec
    last = 0
    while time.time() < deadline:
        last = cdma_status()
        if last & CDMA_SR_ERR_MASK:
            raise RuntimeError(f"CDMA error status: 0x{last:08X}")
        if last & CDMA_SR_IDLE:
            return last
        time.sleep(0.001)
    raise TimeoutError(f"CDMA idle timeout, last SR=0x{last:08X}")


def cdma_reset() -> None:
    """复位 CDMA"""
    write_reg(CDMA_BASE, CDMA_CR, 1 << 2)
    cdma_wait_idle(timeout_sec=2.0)


def cdma_memcpy(src_addr: int, dst_addr: int, nbytes: int) -> None:
    """CDMA 内存拷贝（simple mode，仅 32-bit 地址）"""
    if nbytes <= 0 or nbytes > 0x7FFFFF:
        raise ValueError(f"invalid CDMA length {nbytes}")
    cdma_wait_idle()
    write_reg(CDMA_BASE, CDMA_SA, src_addr & 0xFFFFFFFF)
    write_reg(CDMA_BASE, CDMA_SA_MSB, 0)
    write_reg(CDMA_BASE, CDMA_DA, dst_addr & 0xFFFFFFFF)
    write_reg(CDMA_BASE, CDMA_DA_MSB, 0)
    write_reg(CDMA_BASE, CDMA_BTT, nbytes)
    cdma_wait_idle(timeout_sec=10.0)


def pack_activation_rows(act: np.ndarray) -> bytes:
    """打包激活数据"""
    assert act.dtype == np.int8 and act.ndim == 2 and act.shape[1] == 16
    payload = bytearray()
    for row in range(0, act.shape[0], 2):
        lo = act[row].astype(np.uint8).tobytes()
        hi = (
            act[row + 1].astype(np.uint8).tobytes()
            if row + 1 < act.shape[0]
            else bytes(16)
        )
        payload += lo + hi
    return bytes(payload)


def pack_weight_tile(weight: np.ndarray) -> bytes:
    """打包权重数据"""
    assert weight.dtype == np.int8 and weight.shape == (16, 8)
    return weight.astype(np.uint8).tobytes(order="C")


def golden_int8_matmul(act: np.ndarray, weight: np.ndarray, acc: int = 0) -> np.ndarray:
    """INT8 矩阵乘法 golden model"""
    assert act.dtype == np.int8 and weight.dtype == np.int8
    out = act.astype(np.int32) @ weight.astype(np.int32)
    if acc in (0, 1):
        return out.astype(np.int32)
    assert acc in (2, 4, 8, 16)
    assert out.shape[0] % acc == 0
    return out.reshape(out.shape[0] // acc, acc, out.shape[1]).sum(axis=1).astype(np.int32)


def pack_expected_rows(rows: np.ndarray) -> bytes:
    """打包期望结果"""
    assert rows.dtype == np.int32 and rows.ndim == 2 and rows.shape[1] == 8
    return rows.astype("<i4", copy=False).tobytes(order="C")


def decode_result_rows(payload: bytes) -> np.ndarray:
    """解码结果数据"""
    assert len(payload) % 32 == 0
    return np.frombuffer(payload, dtype="<i4").reshape(-1, 8)


def pe_ctrl_value(acc: int, start: bool = False, config_valid: bool = True) -> int:
    """构造 PE 控制寄存器值"""
    return (
        ((1 if start else 0) << 0)
        | ((1 if config_valid else 0) << 1)
        | (MODE_INT8 << 2)
        | ((acc & 0x1F) << 5)
    )


def pe_status() -> dict:
    """读取 PE 状态"""
    status = read_reg(PE_STATUS_BASE, 0x00)
    error_code = read_reg(PE_STATUS_BASE, 0x08)
    return {
        "raw": status,
        "busy": bool(status & 0x1),
        "done": bool(status & 0x2),
        "error": bool(status & 0x4),
        "config_ready": bool(status & 0x8),
        "error_code": error_code,
    }


def pe_clear_done_if_needed() -> None:
    """清除 PE done 标志"""
    st = pe_status()
    if st["done"] and not st["busy"]:
        write_reg(PE_CTRL_BASE, 0, 0x1)
        time.sleep(0.002)
        write_reg(PE_CTRL_BASE, 0, 0x0)


def pe_start(
    wsrc_base: int,
    asrc_base: int,
    dst_base: int,
    raw_rows: int,
    acc: int,
    timeout_sec: float = 5.0,
) -> dict:
    """启动 PE 运算"""
    assert wsrc_base % BRAM_WORD_BYTES == 0
    assert asrc_base % BRAM_WORD_BYTES == 0
    assert dst_base % BRAM_WORD_BYTES == 0

    pe_clear_done_if_needed()
    for base, value in [
        (PE_CFG0_BASE, wsrc_base),
        (PE_CFG1_BASE, asrc_base),
        (PE_CFG2_BASE, dst_base),
        (PE_CFG3_BASE, raw_rows),
    ]:
        write_reg(base, 0, value)

    ctrl = pe_ctrl_value(acc, start=False, config_valid=True)
    write_reg(PE_CTRL_BASE, 0, ctrl)
    time.sleep(0.002)
    write_reg(PE_CTRL_BASE, 0, pe_ctrl_value(acc, start=True, config_valid=True))
    time.sleep(0.002)
    write_reg(PE_CTRL_BASE, 0, ctrl)

    deadline = time.time() + timeout_sec
    last: dict = {}
    while time.time() < deadline:
        last = pe_status()
        if last["error"]:
            raise RuntimeError(f"PE/VPU error: {last}")
        if last["done"]:
            return last
        time.sleep(0.001)
    raise TimeoutError(f"PE/VPU timeout, last={last}")


def h2c_write_blob(card_addr: int, data: bytes) -> None:
    """写入数据到设备"""
    result = xdma_write(card_addr, data)
    if not result.ok:
        raise RuntimeError(f"H2C write failed at 0x{card_addr:08X}: {result.stderr}")


def c2h_read_blob(card_addr: int, nbytes: int) -> bytes:
    """从设备读取数据"""
    return xdma_read(card_addr, nbytes)


class VpuBramSession:
    """
    VPU BRAM 会话管理
    
    global_bram 暂存 → CDMA → PE ibuf → GPIO 启动 VPU → CDMA obuf → global_bram 读回。
    """

    def __init__(self, channel: int = 0):
        self.channel = channel
        self.device = XDMADevice(channel)

    def close(self) -> None:
        self.device.close()

    def __enter__(self) -> "VpuBramSession":
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    def run_case_from_payloads(
        self,
        weight_payload: bytes,
        act_payload: bytes,
        expected_nbytes: int,
        *,
        w_global_off: int = 0x0000,
        a_global_off: int = 0x1000,
        r_global_off: int = 0x4000,
        w_ibuf_off: int = 0x0000,
        a_ibuf_off: int = 0x0100,
        r_obuf_off: int = 0x0000,
        raw_rows: int,
        acc: int = 0,
    ) -> bytes:
        """执行一个完整的 VPU 运算用例"""
        h2c_write_blob(GLOBAL_BASE + w_global_off, weight_payload)
        h2c_write_blob(GLOBAL_BASE + a_global_off, act_payload)

        cdma_reset()
        cdma_memcpy(
            GLOBAL_BASE + w_global_off,
            IBUF_BASE + w_ibuf_off,
            len(weight_payload),
        )
        cdma_memcpy(
            GLOBAL_BASE + a_global_off,
            IBUF_BASE + a_ibuf_off,
            len(act_payload),
        )

        pe_start(
            w_ibuf_off,
            a_ibuf_off,
            r_obuf_off,
            raw_rows,
            acc,
        )

        cdma_memcpy(
            OBUF_BASE + r_obuf_off,
            GLOBAL_BASE + r_global_off,
            expected_nbytes,
        )
        return c2h_read_blob(GLOBAL_BASE + r_global_off, expected_nbytes)
