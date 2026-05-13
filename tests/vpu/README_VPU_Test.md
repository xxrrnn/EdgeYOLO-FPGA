# VPU 测试配置说明（已验证）

## 地址映射（正确版本）

根据 `scripts/ip/bd/vpu/address.tcl` 和 `rtl/vpu/VPU_AXI_Regs.v`：

### 存储器地址
```
0x1000_0000  staging global_bram (64KB)
0x1001_0000  VPU GB (Global Buffer, 64KB)  ← 正确的 GB 地址
0x1002_0000  VPU WB (Weight Buffer, 64KB)  ← 正确的 WB 地址
0x1003_0000  CDMA 寄存器 (64KB)
0x1004_0000  VPU_AXI_Regs (4KB)
```

### VPU 寄存器偏移（VPU_AXI_Regs 内部）
```
0x00: CTRL        - [0] start (写1启动，写0停止)
0x04: STATUS      - [0] ready (只读)
0x08: UNIT_CHOOSE - 选择功能单元
0x0C: SRC_ADDR    - 源地址
0x10: SRC2_ADDR   - 源地址2（用于AD单元）
0x14: SRC_C       - 源通道数
0x18: SRC_H       - 源高度
0x1C: SRC_W       - 源宽度
0x20: BIAS_ADDR   - Bias地址
0x24: SCALE_ADDR  - Scale地址
0x28: DST_ADDR    - 目标地址
0x2C: ADDR_BREAK  - Break地址（NN_LUT用）
0x30: ADDR_S      - S地址（NN_LUT用）
0x34: ADDR_T      - T地址（NN_LUT用）
```

## Unit 编号（unit_choose）

根据 `rtl/vpu/Global_VPU.v` 的 localparam 定义：

```
1  UNIT_DQA  反量化 (Dequantization): INT32 → FP32
2  UNIT_NN   NN_LUT (暂时注释掉)
3  UNIT_QA   量化 (Quantization): FP32 → INT8
4  UNIT_MP   最大池化 (Max Pooling): 2x2
5  UNIT_US   上采样 (Upsampling): 2x 最近邻
6  UNIT_AD   加法 (Addition): FP32 element-wise add
```

## 代码修复记录

### 修复1: AD Unit 信号缺失（已修复）
**问题**: `ad_unit_start` 和 `ad_unit_ready` 信号未定义
**位置**: `rtl/vpu/Global_VPU.v`
**修复**: 
- 添加信号声明
- 添加 `ad_unit_start` 的赋值
- 将 `ad_unit_ready` 加入 ready 信号

## Golden Model 说明

### 1. MP Unit (Max Pooling) - UNIT_MP = 4
- **输入**: UINT8/INT8, [C, H, W]
- **输出**: UINT8/INT8, [C, H/2, W/2]
- **操作**: 2x2窗口最大值
- **地址**: src_addr (输入), dst_addr (输出)
- **配置**: src_c, src_h, src_w

### 2. QA Unit (Quantization) - UNIT_QA = 3
- **输入**: FP32, [N] from GB
- **输出**: INT8, [N] to GB
- **操作**: `output = clip(round(input * scale), -128, 127)`
- **Scale**: FP32 from WB @ scale_addr
- **配置**: src_addr, scale_addr, dst_addr, src_c

### 3. DQA Unit (Dequantization) - UNIT_DQA = 1
- **输入**: INT32, [N] from GB
- **输出**: FP32, [N] to GB
- **操作**: 使用 MAC 阵列 `output = input * scale + bias`
- **Scale/Bias**: FP32 from WB @ scale_addr, bias_addr
- **配置**: src_addr, scale_addr, bias_addr, dst_addr, src_c

### 4. US Unit (Upsampling) - UNIT_US = 5
- **输入**: UINT8/INT8, [C, H, W] from GB
- **输出**: UINT8/INT8, [C, H*2, W*2] to GB
- **操作**: 最近邻插值，每个像素复制到2x2区域
- **配置**: src_addr, dst_addr, src_c, src_h, src_w

### 5. AD Unit (Addition) - UNIT_AD = 6
- **输入**: FP32 a[N] @ src_addr, FP32 b[N] @ src2_addr from GB
- **输出**: FP32, [N] to GB
- **操作**: 使用 FP32 加法阵列 `output[i] = a[i] + b[i]`
- **配置**: src_addr, src2_addr, dst_addr, src_c
- **注意**: 使用 fp32_add_array（32个并行加法器）

## 注意事项

1. **地址对齐**: GB/WB BRAM 地址建议 256 位对齐（32字节）
2. **数据格式**: 
   - INT8/UINT8: 1 byte per element
   - INT32: 4 bytes per element
   - FP32: 4 bytes per element (IEEE 754)
3. **启动流程**:
   ```python
   # 1. 写入数据到 GB/WB BRAM
   # 2. 配置寄存器（unit_choose, src_addr, dst_addr, etc.）
   # 3. 写 CTRL=1 启动
   # 4. 轮询 STATUS 直到 ready=1
   # 5. 写 CTRL=0 停止
   # 6. 读取结果从 GB BRAM
   ```
4. **FP_WIDTH**: 固定为32（FP32），所有FP16相关代码已注释
5. **NN_LUT**: 已注释掉，避免综合错误
6. **MAC 阵列**: DQA 使用 fp32_mult + fp32_add 流水线（每通道 8+11=19 周期延迟）
7. **AD 阵列**: 使用 fp32_add_lane（每通道 11 周期延迟）

## 测试建议

1. 先测试 BRAM 读写，确认 PCIe 通信正常
2. 测试简单单元（MP, US），数据路径短，易于调试
3. 测试浮点单元（QA, DQA, AD），验证 FP32 IP
4. 最后测试组合流程（im2col + MAC）

## 已知问题与修复

### 已修复
- ✅ AD Unit 信号缺失（ad_unit_start, ad_unit_ready）
- ✅ FP16 相关代码已全部注释
- ✅ NN_LUT 单元已注释
- ✅ FP32 MAC 阵列添加 aresetn 信号

### 待测试
- MAC 阵列完整功能测试
- 大规模数据传输（接近 64KB 限制）
- 多单元组合测试
