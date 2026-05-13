#!/usr/bin/env python3
"""
VPU（rtl 中为 PE/DCIM）+ XDMA + CDMA 主机侧协议。

与 Vivado Block Design `xdma_dcim_bram` 一致，地址见 scripts/ip/bd/xdma_dcim_bram/address.tcl。
配置通过 XDMA H2C 写设备侧绝对地址完成（非 XDMA user BAR）。
"""

from __future__ import annotations

import time
from typing import BinaryIO

import numpy as np

# --- 与 address.tcl / gpio.tcl 一致 ---
GLOBAL_BASE = 0x10000000
IBUF_BASE = 0x10010000
OBUF_BASE = 0x10020000
CDMA_BASE = 0x10030000
PE_CFG0_BASE = 0x10040000
PE_CFG1_BASE = 0x10041000
PE_CFG2_BASE = 0x10042000
PE_CFG3_BASE = 0x10043000
PE_CTRL_BASE = 0x10044000
PE_STATUS_BASE = 0x10045000

BRAM_WORD_BYTES = 32
MODE_INT8 = 0b110

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


def _mmio_write_u32(h2c: BinaryIO, addr: int, value: int) -> None:
    h2c.seek(addr)
    h2c.write((value & 0xFFFFFFFF).to_bytes(4, "little"))
    h2c.flush()


def _mmio_read_u32(c2h: BinaryIO, addr: int) -> int:
    c2h.seek(addr)
    data = c2h.read(4)
    if len(data) != 4:
        raise OSError(f"short MMIO read at 0x{addr:08X}")
    return int.from_bytes(data, "little")


def cdma_status(h2c: BinaryIO, c2h: BinaryIO) -> int:
    return _mmio_read_u32(c2h, CDMA_BASE + CDMA_SR)


def cdma_wait_idle(h2c: BinaryIO, c2h: BinaryIO, timeout_sec: float = 5.0) -> int:
    deadline = time.time() + timeout_sec
    last = 0
    while time.time() < deadline:
        last = cdma_status(h2c, c2h)
        if last & CDMA_SR_ERR_MASK:
            raise RuntimeError(f"CDMA error status: 0x{last:08X}")
        if last & CDMA_SR_IDLE:
            return last
        time.sleep(0.001)
    raise TimeoutError(f"CDMA idle timeout, last SR=0x{last:08X}")


def cdma_reset(h2c: BinaryIO, c2h: BinaryIO) -> None:
    _mmio_write_u32(h2c, CDMA_BASE + CDMA_CR, 1 << 2)
    cdma_wait_idle(h2c, c2h, timeout_sec=2.0)


def cdma_memcpy(
    h2c: BinaryIO,
    c2h: BinaryIO,
    src_addr: int,
    dst_addr: int,
    nbytes: int,
) -> None:
    """simple mode CDMA：仅写 32-bit 物理地址（高位寄存器写 0）。"""
    if nbytes <= 0 or nbytes > 0x7FFFFF:
        raise ValueError(f"invalid CDMA length {nbytes}")
    cdma_wait_idle(h2c, c2h)
    _mmio_write_u32(h2c, CDMA_BASE + CDMA_SA, src_addr & 0xFFFFFFFF)
    _mmio_write_u32(h2c, CDMA_BASE + CDMA_SA_MSB, 0)
    _mmio_write_u32(h2c, CDMA_BASE + CDMA_DA, dst_addr & 0xFFFFFFFF)
    _mmio_write_u32(h2c, CDMA_BASE + CDMA_DA_MSB, 0)
    _mmio_write_u32(h2c, CDMA_BASE + CDMA_BTT, nbytes)
    cdma_wait_idle(h2c, c2h, timeout_sec=10.0)


def pack_activation_rows(act: np.ndarray) -> bytes:
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
    assert weight.dtype == np.int8 and weight.shape == (16, 8)
    return weight.astype(np.uint8).tobytes(order="C")


def golden_int8_matmul(
    act: np.ndarray, weight: np.ndarray, acc: int = 0
) -> np.ndarray:
    assert act.dtype == np.int8 and weight.dtype == np.int8
    out = act.astype(np.int32) @ weight.astype(np.int32)
    if acc in (0, 1):
        return out.astype(np.int32)
    assert acc in (2, 4, 8, 16)
    assert out.shape[0] % acc == 0
    return out.reshape(out.shape[0] // acc, acc, out.shape[1]).sum(axis=1).astype(
        np.int32
    )


def pack_expected_rows(rows: np.ndarray) -> bytes:
    assert rows.dtype == np.int32 and rows.ndim == 2 and rows.shape[1] == 8
    return rows.astype("<i4", copy=False).tobytes(order="C")


def decode_result_rows(payload: bytes) -> np.ndarray:
    assert len(payload) % 32 == 0
    return np.frombuffer(payload, dtype="<i4").reshape(-1, 8)


def pe_ctrl_value(
    acc: int, start: bool = False, config_valid: bool = True
) -> int:
    return (
        ((1 if start else 0) << 0)
        | ((1 if config_valid else 0) << 1)
        | (MODE_INT8 << 2)
        | ((acc & 0x1F) << 5)
    )


def pe_status(h2c: BinaryIO, c2h: BinaryIO) -> dict:
    status = _mmio_read_u32(c2h, PE_STATUS_BASE + 0x00)
    error_code = _mmio_read_u32(c2h, PE_STATUS_BASE + 0x08)
    return {
        "raw": status,
        "busy": bool(status & 0x1),
        "done": bool(status & 0x2),
        "error": bool(status & 0x4),
        "config_ready": bool(status & 0x8),
        "error_code": error_code,
    }


def pe_clear_done_if_needed(h2c: BinaryIO, c2h: BinaryIO) -> None:
    st = pe_status(h2c, c2h)
    if st["done"] and not st["busy"]:
        _mmio_write_u32(h2c, PE_CTRL_BASE, 0x1)
        time.sleep(0.002)
        _mmio_write_u32(h2c, PE_CTRL_BASE, 0x0)


def pe_start(
    h2c: BinaryIO,
    c2h: BinaryIO,
    wsrc_base: int,
    asrc_base: int,
    dst_base: int,
    raw_rows: int,
    acc: int,
    timeout_sec: float = 5.0,
) -> dict:
    assert wsrc_base % BRAM_WORD_BYTES == 0
    assert asrc_base % BRAM_WORD_BYTES == 0
    assert dst_base % BRAM_WORD_BYTES == 0

    pe_clear_done_if_needed(h2c, c2h)
    for base, value in [
        (PE_CFG0_BASE, wsrc_base),
        (PE_CFG1_BASE, asrc_base),
        (PE_CFG2_BASE, dst_base),
        (PE_CFG3_BASE, raw_rows),
    ]:
        _mmio_write_u32(h2c, base, value)

    ctrl = pe_ctrl_value(acc, start=False, config_valid=True)
    _mmio_write_u32(h2c, PE_CTRL_BASE, ctrl)
    time.sleep(0.002)
    _mmio_write_u32(h2c, PE_CTRL_BASE, pe_ctrl_value(acc, start=True, config_valid=True))
    time.sleep(0.002)
    _mmio_write_u32(h2c, PE_CTRL_BASE, ctrl)

    deadline = time.time() + timeout_sec
    last: dict = {}
    while time.time() < deadline:
        last = pe_status(h2c, c2h)
        if last["error"]:
            raise RuntimeError(f"PE/VPU error: {last}")
        if last["done"]:
            return last
        time.sleep(0.001)
    raise TimeoutError(f"PE/VPU timeout, last={last}")


def h2c_write_blob(h2c: BinaryIO, card_addr: int, data: bytes) -> None:
    h2c.seek(card_addr)
    h2c.write(data)
    h2c.flush()


def c2h_read_blob(c2h: BinaryIO, card_addr: int, nbytes: int) -> bytes:
    c2h.seek(card_addr)
    data = c2h.read(nbytes)
    if len(data) != nbytes:
        raise OSError(f"short DMA read at 0x{card_addr:08X}")
    return data


class VpuBramSession:
    """
    global_bram 暂存 → CDMA → PE ibuf → GPIO 启动 VPU → CDMA obuf → global_bram 读回。
    默认缓冲布局与 tests/xdma_dcim_bram/rw_test.ipynb 中 run_dcim_case 一致。
    """

    def __init__(self, device_base: str):
        self.device_base = device_base
        self.h2c = open(f"{device_base}_h2c_0", "wb")
        self.c2h = open(f"{device_base}_c2h_0", "rb")

    def close(self) -> None:
        self.h2c.close()
        self.c2h.close()

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
        h2c, c2h = self.h2c, self.c2h

        h2c_write_blob(h2c, GLOBAL_BASE + w_global_off, weight_payload)
        h2c_write_blob(h2c, GLOBAL_BASE + a_global_off, act_payload)

        cdma_reset(h2c, c2h)
        cdma_memcpy(
            h2c,
            c2h,
            GLOBAL_BASE + w_global_off,
            IBUF_BASE + w_ibuf_off,
            len(weight_payload),
        )
        cdma_memcpy(
            h2c,
            c2h,
            GLOBAL_BASE + a_global_off,
            IBUF_BASE + a_ibuf_off,
            len(act_payload),
        )

        pe_start(
            h2c,
            c2h,
            w_ibuf_off,
            a_ibuf_off,
            r_obuf_off,
            raw_rows,
            acc,
        )

        cdma_memcpy(
            h2c,
            c2h,
            OBUF_BASE + r_obuf_off,
            GLOBAL_BASE + r_global_off,
            expected_nbytes,
        )
        return c2h_read_blob(c2h, GLOBAL_BASE + r_global_off, expected_nbytes)
