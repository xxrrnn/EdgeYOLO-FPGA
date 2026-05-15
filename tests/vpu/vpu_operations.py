#!/usr/bin/env python3
"""
VPU神经网络操作API - 将Python操作翻译为XDMA指令
支持MaxPooling, Upsampling, Add, Quantization, Dequantization等

仅支持 exe 模式（通过 xdma_rw.exe 进行读写）

地址映射（参考 scripts/ip/bd/vpu/address.tcl）：
  0x1000_0000  staging global_bram (1MB) - 数据区
  0x1020_0000  inst_bram (1MB) - 指令区
  0x1040_0000  VPU GB (128KB)
  0x1042_0000  VPU WB (128KB)
  0x1044_0000  VPU_AXI_Regs (4KB) - 配置 + 状态 + 解码器控制
  
注意：软件不再直接访问 CDMA 寄存器，由 INST_Decoder 通过 CDMA_Controller 控制
"""

import numpy as np
import time

from xdma_helpers import (
    XDMADevice, xdma_write, xdma_read, write_reg, read_reg,
    GLOBAL_BRAM_BASE, VPU_GB_BASE, VPU_WB_BASE, CDMA_BASE, VPU_REGS_BASE
)

# VPU寄存器偏移
VPU_REG_CTRL = 0x00         # [0] start
VPU_REG_STATUS = 0x04       # [0] ready
VPU_REG_UNIT_CHOOSE = 0x08
VPU_REG_SRC_ADDR = 0x0C
VPU_REG_SRC2_ADDR = 0x10
VPU_REG_SRC_C = 0x14
VPU_REG_SRC_H = 0x18
VPU_REG_SRC_W = 0x1C
VPU_REG_BIAS_ADDR = 0x20
VPU_REG_SCALE_ADDR = 0x24
VPU_REG_DST_ADDR = 0x28
VPU_REG_ADDR_BREAK = 0x2C
VPU_REG_ADDR_S = 0x30
VPU_REG_ADDR_T = 0x34

# VPU功能单元编号
UNIT_DQA = 1   # Dequantization: INT32 → FP32
UNIT_NN = 2    # NN_LUT (未启用)
UNIT_QA = 3    # Quantization: FP32 → INT8
UNIT_MP = 4    # Max Pooling 2x2
UNIT_US = 5    # Upsampling 2x (nearest neighbor)
UNIT_AD = 6    # Element-wise Addition (FP32)


class VPUDevice:
    """VPU设备抽象 - 封装XDMA读写操作（仅 exe 模式）"""
    
    def __init__(self, channel: int = 0):
        """
        初始化VPU设备
        
        Args:
            channel: DMA 通道号（默认 0）
        """
        self._device = XDMADevice(channel)
        
    def close(self):
        """关闭设备"""
        self._device.close()
        
    def __enter__(self):
        return self
        
    def __exit__(self, *args):
        self.close()
        
    def write_u32(self, addr: int, value: int):
        """写32位寄存器"""
        self._device.write_u32(addr, value)
        
    def read_u32(self, addr: int) -> int:
        """读32位寄存器"""
        return self._device.read_u32(addr)
        
    def write_bram(self, bram_base: int, offset: int, data: bytes):
        """
        写入BRAM数据
        
        Args:
            bram_base: BRAM基地址（GLOBAL_BRAM_BASE, VPU_GB_BASE, VPU_WB_BASE）
            offset: 偏移地址
            data: 要写入的数据
        """
        self._device.write_blob(bram_base + offset, data)
        
    def read_bram(self, bram_base: int, offset: int, nbytes: int) -> bytes:
        """
        从BRAM读取数据
        
        Args:
            bram_base: BRAM基地址
            offset: 偏移地址
            nbytes: 读取字节数
            
        Returns:
            读取的数据
        """
        return self._device.read_blob(bram_base + offset, nbytes)


class VPUOperator:
    """VPU操作基类"""
    
    def __init__(self, device: VPUDevice):
        self.device = device
        
    def wait_ready(self, timeout: float = 5.0) -> bool:
        """
        等待VPU就绪
        
        Args:
            timeout: 超时时间（秒）
            
        Returns:
            是否就绪
        """
        deadline = time.time() + timeout
        while time.time() < deadline:
            status = self.device.read_u32(VPU_REGS_BASE + VPU_REG_STATUS)
            if status & 0x1:  # ready bit
                return True
            time.sleep(0.001)
        return False
        
    def start_unit(self, unit: int, **config):
        """
        启动VPU单元
        
        Args:
            unit: 功能单元编号（UNIT_DQA, UNIT_QA等）
            **config: 配置参数（src_addr, dst_addr, src_c, src_h, src_w等）
        """
        if not self.wait_ready():
            raise TimeoutError("VPU not ready before start")
            
        self.device.write_u32(VPU_REGS_BASE + VPU_REG_UNIT_CHOOSE, unit)
        
        if 'src_addr' in config:
            self.device.write_u32(VPU_REGS_BASE + VPU_REG_SRC_ADDR, config['src_addr'])
        if 'src2_addr' in config:
            self.device.write_u32(VPU_REGS_BASE + VPU_REG_SRC2_ADDR, config['src2_addr'])
        if 'dst_addr' in config:
            self.device.write_u32(VPU_REGS_BASE + VPU_REG_DST_ADDR, config['dst_addr'])
        if 'src_c' in config:
            self.device.write_u32(VPU_REGS_BASE + VPU_REG_SRC_C, config['src_c'])
        if 'src_h' in config:
            self.device.write_u32(VPU_REGS_BASE + VPU_REG_SRC_H, config['src_h'])
        if 'src_w' in config:
            self.device.write_u32(VPU_REGS_BASE + VPU_REG_SRC_W, config['src_w'])
        if 'scale_addr' in config:
            self.device.write_u32(VPU_REGS_BASE + VPU_REG_SCALE_ADDR, config['scale_addr'])
        if 'bias_addr' in config:
            self.device.write_u32(VPU_REGS_BASE + VPU_REG_BIAS_ADDR, config['bias_addr'])
            
        self.device.write_u32(VPU_REGS_BASE + VPU_REG_CTRL, 1)
        time.sleep(0.001)
        self.device.write_u32(VPU_REGS_BASE + VPU_REG_CTRL, 0)
        
        if not self.wait_ready(timeout=10.0):
            raise TimeoutError("VPU operation timeout")


class MaxPooling2D(VPUOperator):
    """
    2x2最大池化操作
    
    输入: INT8/UINT8 [C, H, W] in GB
    输出: INT8/UINT8 [C, H/2, W/2] in GB
    """
    
    def __call__(self, 
                 input_data: np.ndarray,
                 input_addr: int = 0x0,
                 output_addr: int = 0x8000) -> np.ndarray:
        assert input_data.ndim == 3, "Input must be [C, H, W]"
        assert input_data.dtype in [np.int8, np.uint8], "Input must be INT8/UINT8"
        
        C, H, W = input_data.shape
        assert H % 2 == 0 and W % 2 == 0, "H and W must be divisible by 2"
        
        input_bytes = input_data.tobytes(order='C')
        self.device.write_bram(VPU_GB_BASE, input_addr, input_bytes)
        
        self.start_unit(
            UNIT_MP,
            src_addr=input_addr,
            dst_addr=output_addr,
            src_c=C,
            src_h=H,
            src_w=W
        )
        
        output_size = C * (H // 2) * (W // 2)
        output_bytes = self.device.read_bram(VPU_GB_BASE, output_addr, output_size)
        output_data = np.frombuffer(output_bytes, dtype=input_data.dtype)
        return output_data.reshape(C, H // 2, W // 2)
        
    def golden(self, input_data: np.ndarray) -> np.ndarray:
        """CPU参考实现"""
        C, H, W = input_data.shape
        output = np.zeros((C, H // 2, W // 2), dtype=input_data.dtype)
        for c in range(C):
            for h in range(0, H, 2):
                for w in range(0, W, 2):
                    window = input_data[c, h:h+2, w:w+2]
                    output[c, h//2, w//2] = window.max()
        return output


class Upsampling2D(VPUOperator):
    """
    2x最近邻上采样
    
    输入: INT8/UINT8 [C, H, W] in GB
    输出: INT8/UINT8 [C, H*2, W*2] in GB
    """
    
    def __call__(self,
                 input_data: np.ndarray,
                 input_addr: int = 0x0,
                 output_addr: int = 0x8000) -> np.ndarray:
        assert input_data.ndim == 3, "Input must be [C, H, W]"
        assert input_data.dtype in [np.int8, np.uint8], "Input must be INT8/UINT8"
        
        C, H, W = input_data.shape
        
        input_bytes = input_data.tobytes(order='C')
        self.device.write_bram(VPU_GB_BASE, input_addr, input_bytes)
        
        self.start_unit(
            UNIT_US,
            src_addr=input_addr,
            dst_addr=output_addr,
            src_c=C,
            src_h=H,
            src_w=W
        )
        
        output_size = C * (H * 2) * (W * 2)
        output_bytes = self.device.read_bram(VPU_GB_BASE, output_addr, output_size)
        output_data = np.frombuffer(output_bytes, dtype=input_data.dtype)
        return output_data.reshape(C, H * 2, W * 2)
        
    def golden(self, input_data: np.ndarray) -> np.ndarray:
        """CPU参考实现"""
        C, H, W = input_data.shape
        output = np.zeros((C, H * 2, W * 2), dtype=input_data.dtype)
        for c in range(C):
            for h in range(H):
                for w in range(W):
                    output[c, h*2:h*2+2, w*2:w*2+2] = input_data[c, h, w]
        return output


class ElementwiseAdd(VPUOperator):
    """
    逐元素FP32加法
    
    输入: FP32 a[N], FP32 b[N] in GB
    输出: FP32 [N] in GB
    """
    
    def __call__(self,
                 input_a: np.ndarray,
                 input_b: np.ndarray,
                 input_a_addr: int = 0x0,
                 input_b_addr: int = 0x4000,
                 output_addr: int = 0x8000) -> np.ndarray:
        assert input_a.shape == input_b.shape, "Inputs must have same shape"
        assert input_a.dtype == np.float32 and input_b.dtype == np.float32
        
        a_flat = input_a.flatten()
        b_flat = input_b.flatten()
        
        self.device.write_bram(VPU_GB_BASE, input_a_addr, a_flat.tobytes())
        self.device.write_bram(VPU_GB_BASE, input_b_addr, b_flat.tobytes())
        
        self.start_unit(
            UNIT_AD,
            src_addr=input_a_addr,
            src2_addr=input_b_addr,
            dst_addr=output_addr,
            src_c=len(a_flat),
            src_h=1,
            src_w=1
        )
        
        output_bytes = self.device.read_bram(VPU_GB_BASE, output_addr, len(a_flat) * 4)
        output_data = np.frombuffer(output_bytes, dtype=np.float32)
        return output_data.reshape(input_a.shape)
        
    def golden(self, input_a: np.ndarray, input_b: np.ndarray) -> np.ndarray:
        """CPU参考实现"""
        return input_a + input_b


class Quantization(VPUOperator):
    """
    量化: FP32 → INT8
    
    输入: FP32 [N] in GB
    输出: INT8 [N] in GB
    Scale: FP32 in WB
    """
    
    def __call__(self,
                 input_data: np.ndarray,
                 scale: float,
                 input_addr: int = 0x0,
                 scale_addr: int = 0x0,
                 output_addr: int = 0x8000) -> np.ndarray:
        assert input_data.dtype == np.float32
        
        input_flat = input_data.flatten()
        self.device.write_bram(VPU_GB_BASE, input_addr, input_flat.tobytes())
        
        scale_bytes = np.array([scale], dtype=np.float32).tobytes()
        self.device.write_bram(VPU_WB_BASE, scale_addr, scale_bytes)
        
        self.start_unit(
            UNIT_QA,
            src_addr=input_addr,
            scale_addr=scale_addr,
            dst_addr=output_addr,
            src_c=len(input_flat),
            src_h=1,
            src_w=1
        )
        
        output_bytes = self.device.read_bram(VPU_GB_BASE, output_addr, len(input_flat))
        output_data = np.frombuffer(output_bytes, dtype=np.int8)
        return output_data.reshape(input_data.shape)
        
    def golden(self, input_data: np.ndarray, scale: float) -> np.ndarray:
        """CPU参考实现"""
        return np.clip(np.round(input_data * scale), -128, 127).astype(np.int8)


class Dequantization(VPUOperator):
    """
    反量化: INT32 → FP32
    
    输入: INT32 [N] in GB
    输出: FP32 [N] in GB
    Scale/Bias: FP32 in WB
    """
    
    def __call__(self,
                 input_data: np.ndarray,
                 scale: np.ndarray,
                 bias: np.ndarray,
                 input_addr: int = 0x0,
                 scale_addr: int = 0x0,
                 bias_addr: int = 0x100,
                 output_addr: int = 0x8000) -> np.ndarray:
        assert input_data.dtype == np.int32
        assert scale.dtype == np.float32 and bias.dtype == np.float32
        
        input_flat = input_data.flatten()
        self.device.write_bram(VPU_GB_BASE, input_addr, input_flat.tobytes())
        self.device.write_bram(VPU_WB_BASE, scale_addr, scale.tobytes())
        self.device.write_bram(VPU_WB_BASE, bias_addr, bias.tobytes())
        
        self.start_unit(
            UNIT_DQA,
            src_addr=input_addr,
            scale_addr=scale_addr,
            bias_addr=bias_addr,
            dst_addr=output_addr,
            src_c=len(input_flat),
            src_h=1,
            src_w=1
        )
        
        output_bytes = self.device.read_bram(VPU_GB_BASE, output_addr, len(input_flat) * 4)
        output_data = np.frombuffer(output_bytes, dtype=np.float32)
        return output_data.reshape(input_data.shape)
        
    def golden(self, input_data: np.ndarray, scale: np.ndarray, 
               bias: np.ndarray) -> np.ndarray:
        """CPU参考实现"""
        return input_data.astype(np.float32) * scale + bias


def create_vpu_operators(channel: int = 0):
    """
    创建所有VPU操作符
    
    Args:
        channel: DMA 通道号（默认 0）
    
    Returns:
        字典，包含所有操作符实例
    """
    device = VPUDevice(channel)
    return {
        'device': device,
        'maxpool': MaxPooling2D(device),
        'upsample': Upsampling2D(device),
        'add': ElementwiseAdd(device),
        'quantize': Quantization(device),
        'dequantize': Dequantization(device),
    }
