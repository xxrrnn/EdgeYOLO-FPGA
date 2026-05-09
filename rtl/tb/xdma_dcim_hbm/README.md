# XDMA DCIM HBM TB usage

这个目录放的是 `PE` 大矩阵分块乘法相关测试。当前路径已经迁到：

- `rtl/tb/xdma_dcim_hbm/tb_pe_large_gemm.sv`
- `rtl/tb/xdma_dcim_hbm/tb_pe_large_gemm_int16.sv`
- `rtl/tb/xdma_dcim_hbm/tb_pcie_large_gemm.sv` (NEW: PCIe 级仿真)

---

## 0) 快速运行

```bash
# INT8 测试 (默认)
./run_xsim.sh int8

# INT16 测试
./run_xsim.sh int16

# PCIe 级仿真测试 (模拟 large_gemm_test.py 的行为)
./run_xsim.sh pcie
```

---

## 1) INT8*INT8 大矩阵分块测试

文件：`tb_pe_large_gemm.sv`

测试目标：

- 验证 `PE` 在大行数场景（`M_ROWS=128`）下，支持 K 维分块累加。
- `K_TILES=8`，每个 tile 先检查输出不含 `X/Z`（避免未初始化或读时序假通过）。
- 再把 8 个 tile 写回同一目的地址：
  - 第一次 `accumulate_type=0`（初始化）
  - 后续 `accumulate_type=1`（累加）
- 最终结果与"逐 tile 输出结果的 lane-wise 累加"逐行对比。

说明：

- `accumulate_type=2`（减法）已从 RTL 去除，TB 不再覆盖该模式。
- 现在的 TB 先验证单 tile 输出稳定（无 `X/Z`），再验证累加链路。
- 本测试重点仍是单个 `PE` 的分块累加链路，不是 host 侧 AXI/CDMA 系统联调，也不是完整多 `N` tile 的系统级 blocked GEMM。

运行：

```bash
./run_xsim.sh int8
# 或
vivado -mode batch -source rtl/tb/xdma_dcim_hbm/run_xsim_pe_large_gemm.tcl
```

---

## 2) INT16*INT16 大矩阵分块测试

文件：`tb_pe_large_gemm_int16.sv`

测试目标：

- 在 `MODE_INT16` 下验证 K 分块累加链路可用。
- `tb_pe_large_gemm_int16.sv` 使用：
  - `M_ROWS=64`
  - `K_TILES=4`
- 判定标准同 INT8：
  - 每个 tile 的 DUT 输出必须无 `X/Z`
  - 统一目的区结果必须等于每个 tile 输出的 lane-wise 累加

运行：

```bash
./run_xsim.sh int16
# 或
vivado -mode batch -source rtl/tb/xdma_dcim_hbm/run_xsim_pe_large_gemm_int16.tcl
```

---

## 3) PCIe 级仿真测试 (NEW)

文件：`tb_pcie_large_gemm.sv`

### 3.1) 设计思路

这个 testbench 的目标是**在 RTL 仿真中复现 `tests/xdma_dcim_hbm/large_gemm_test.py` 的完整测试流程**，无需真实硬件即可验证 PE 的功能正确性。

**核心思路**：

1. **简化 PCIe/XDMA 层**：Python 测试通过 XDMA 驱动发送 PCIe 事务，但在 RTL 仿真中，我们直接驱动 PE 模块的 IBUF/OBUF 端口，跳过 XDMA IP 和 PCIe 协议栈。这样可以：
   - 避免仿真 XDMA IP 的复杂性（需要 Root Port BFM）
   - 大幅加快仿真速度
   - 保持测试逻辑与 Python 测试完全一致

2. **保持数据流一致**：虽然跳过了 XDMA/CDMA，但数据的打包格式、地址布局、控制寄存器配置都与 Python 测试完全相同。

3. **使用相同的 golden 计算**：testbench 中的 `golden_int8_row_word()` 函数与 Python 测试中的 `golden_int8_matmul_tile()` 使用相同的算法。

### 3.2) 实现细节

#### 文件结构

```
rtl/tb/xdma_dcim_hbm/
├── tb_pcie_large_gemm.sv    # 主 testbench
├── axi_vip_tasks.svh        # AXI VIP 任务包（供未来扩展）
├── run_xsim.sh              # 运行脚本（支持 int8/int16/pcie 模式）
└── run_pcie_sim.tcl         # TCL 仿真脚本
```

#### Python 测试 vs RTL 仿真对照表

| Python 测试函数 | RTL 仿真实现 | 说明 |
|----------------|-------------|------|
| `xdma_write(addr, file)` | `ibuf_write_word(addr, data)` | 直接写 IBUF，跳过 HBM |
| `xdma_read(addr, size, file)` | `obuf_read_word(addr, data)` | 直接读 OBUF，跳过 HBM |
| `cdma_memcpy(src, dst, size)` | 跳过 | 数据直接写入 IBUF |
| `mmio_write_u32(PE_CFG*, val)` | `pe_*` 信号直接赋值 | 直接驱动 PE 配置端口 |
| `pe_start()` | `run_pe_tile()` task | 配置+启动+等待完成 |
| `pack_int8_weight_tile()` | `load_weight_tile()` task | 相同的打包格式 |
| `pack_int8_activation_rows()` | `load_activation_tile()` task | 相同的打包格式 |
| `golden_int8_matmul_tile()` | `golden_int8_row_word()` function | 相同的计算逻辑 |

#### 测试数据生成

使用确定性伪随机函数生成测试数据，与 Python 测试保持一致：

```systemverilog
// 权重数据生成（与 Python 测试相同的公式）
function automatic logic signed [7:0] gen_weight_byte(int kt, int r, int c);
    int v;
    v = (kt * 37 + r * 11 + c * 7 + 19) & 8'hFF;
    return v[7:0];
endfunction

// 激活数据生成
function automatic logic signed [7:0] gen_act_byte(int kt, int r, int c);
    int v;
    v = (kt * 53 + r * 5 + c * 13 + 3) & 8'hFF;
    return v[7:0];
endfunction
```

#### 数据打包格式

**权重 tile [16, 8]**：
- 16 行 × 8 列 = 128 字节
- 按行优先顺序存储
- 每 32 字节（256 位）写入一个 IBUF word

**激活 tile [M, 16]**：
- 每两行打包成一个 256 位 word
- 低 128 位 = 第 2k 行的 16 个 int8
- 高 128 位 = 第 2k+1 行的 16 个 int8

#### 测试流程

```
Step 1: 收集每个 K-tile 的独立输出
        ┌─────────────────────────────────────────┐
        │ for kt in 0..K_TILES:                   │
        │   1. 清空 OBUF 目标区域                  │
        │   2. 加载权重 tile 到 IBUF              │
        │   3. 加载激活 tile 到 IBUF              │
        │   4. 运行 PE (accumulate_type=0)        │
        │   5. 读回结果，与 golden 比较            │
        └─────────────────────────────────────────┘

Step 2: 运行 K-tiling 累加
        ┌─────────────────────────────────────────┐
        │ 清空累加目标区域                         │
        │ for kt in 0..K_TILES:                   │
        │   1. 加载权重 tile 到 IBUF              │
        │   2. 加载激活 tile 到 IBUF              │
        │   3. 运行 PE:                           │
        │      - kt=0: accumulate_type=0 (覆盖)   │
        │      - kt>0: accumulate_type=1 (累加)   │
        └─────────────────────────────────────────┘

Step 3: 验证累加结果
        ┌─────────────────────────────────────────┐
        │ expected = lane_wise_sum(all golden)    │
        │ actual = read_obuf(累加目标区)          │
        │ assert(expected == actual)              │
        └─────────────────────────────────────────┘
```

### 3.3) 测试参数

| 参数 | 值 | 说明 |
|------|-----|------|
| `M_ROWS` | 16 | 激活矩阵行数 |
| `K_TILES` | 2 | K 维度分块数 |
| `K_TILE_SIZE` | 16 | 每个 K tile 的大小 |
| `N_COLS` | 8 | 输出列数（INT8 固定） |
| 总矩阵 | C[16,8] = A[16,32] @ W[32,8] | |

### 3.4) 地址映射

地址映射与 `scripts/ip/bd/xdma_dcim_hbm/address.tcl` 和 Python 测试一致：

| 组件 | 地址 |
|------|------|
| HBM (SAXI_00) | `0x0_0000_0000` |
| PE IBUF | `0x2_0000_0000` |
| PE OBUF | `0x2_0001_0000` |
| CDMA 寄存器 | `0x2_0002_0000` |
| PE CFG0-3 | `0x2_0003_0000` - `0x2_0003_3000` |
| PE CTRL | `0x2_0003_4000` |
| PE STATUS | `0x2_0003_5000` |

### 3.5) 运行结果示例

```
============================================================
PCIe Large GEMM Test
M=16, K=32 (tiles=2), N=8
============================================================

[TB] Step 1: Collect per-K reference outputs
[TB] Loading weight tile 0 to IBUF
[TB] Loading activation tile 0 to IBUF
[TB] Running PE tile: ref_k0, dst=0x00002000, accum_type=0
[TB] PE tile ref_k0 completed in 131 cycles
[TB] K-tile 0: single-tile verification PASSED
[TB] Loading weight tile 1 to IBUF
[TB] Loading activation tile 1 to IBUF
[TB] Running PE tile: ref_k1, dst=0x00003000, accum_type=0
[TB] PE tile ref_k1 completed in 131 cycles
[TB] K-tile 1: single-tile verification PASSED

[TB] Step 2: Run K-tiling accumulation on single C tile
[TB] Loading weight tile 0 to IBUF
[TB] Loading activation tile 0 to IBUF
[TB] Running PE tile: acc_k0, dst=0x00000000, accum_type=0
[TB] PE tile acc_k0 completed in 131 cycles
[TB] Loading weight tile 1 to IBUF
[TB] Loading activation tile 1 to IBUF
[TB] Running PE tile: acc_k1, dst=0x00000000, accum_type=1
[TB] PE tile acc_k1 completed in 131 cycles

[TB] Step 3: Compare against lane-wise sum of references

============================================================
[TB][PASS] PCIe Large GEMM test passed!
  - Verified 2 K-tiles independently
  - Verified K-tiling accumulation
  - Total matrix: C[16,8] = A[16,32] @ W[32,8]
============================================================
```

### 3.6) 运行方式

```bash
./run_xsim.sh pcie
# 或
vivado -mode batch -source rtl/tb/xdma_dcim_hbm/run_pcie_sim.tcl
```

### 3.7) 辅助文件

- `axi_vip_tasks.svh` - AXI VIP 任务包，提供 AXI 读写和 CDMA 操作的高级任务（供未来扩展到完整系统级仿真使用）

---

## 4) 关键执行流程（所有 TB 都一样）

每个 tile 的执行顺序：

1. 往 IBUF 写权重 tile（`W_BASE_BYTE`）
2. 往 IBUF 写激活 tile（`A_BASE_BYTE`）
3. 配置 `dcim_*` 控制信号并 `dcim_start` 启动
4. 轮询 `dcim_done`，若 `dcim_error` 则 `fatal`
5. 从 OBUF 读回结果，先检查无 `X/Z`
6. 所有 tile 跑完后，再检查累加目标区是否等于所有 tile 输出的 lane-wise 累加

补充：

- INT16 激活按照每行 16 个 `int16` 存放（每行 32B，1 行/word）。
- INT16 权重按照 `16x4 int16` tile 存放（总 128B，4 words）。
- `accumulate_type=1` 的 OBUF 合并逻辑在 RTL 中是按 `WD3` lane 局部相加，不带跨 lane 进位，所以 TB 对累加目标区也按同样的 lane-wise 语义构造期望值。

---

## 5) 这个 TB 现在验证了什么

- 单个 INT8 / INT16 tile 的输出是否稳定（无 `X/Z`）。
- K 分块多次回写同一目的区时，`accumulate_type=0/1` 的行为是否与 RTL 规定的 lane-wise 累加一致。
- 大行数下地址生成、FSM、done/error 流程是否能稳定跑通。
- **PCIe 级仿真验证了与 Python 测试相同的数据流和控制流**

仍未覆盖：

- `dcim_acc=2/4/8/16` 的 `postProcess` 行折叠模式。
- 多个 `N` tile 拼接成完整大矩阵 `C` 的系统级 blocked GEMM。
- 完整的 AXI/XDMA/CDMA 联调（需要 Xilinx AXI VIP 或 Example Design）。

---

## 6) 关于 Python 测试与 BRAM IP

- 这个 TB 是纯 RTL 级（`dcim_tdp_byte_ram` 推断 RAM），理论上可以改造成 Python/cocotb 驱动。
- 若要直接仿真 Xilinx `.xci` Block Memory IP，建议继续使用 Vivado `xsim`（或已编译 Xilinx 仿真库的第三方仿真器）。
- 当前目录下脚本默认走 Vivado `xsim`，避免 IP 库兼容问题。

---

## 7) 完整系统级 PCIe 仿真（高级）

如果需要完整的 PCIe TLP 级仿真（包含 XDMA IP 的 Root Port BFM），需要：

1. 生成 XDMA IP 的 Example Design：
   ```tcl
   open_project build/xdma_dcim_hbm/xdma_dcim_hbm.xpr
   open_bd_design [get_files xdma_dcim_hbm.bd]
   set xdma_ip [get_bd_cells -filter {VLNV =~ *xdma*}]
   open_example_project -force -dir ./sim_example [get_ips ${xdma_ip}_0]
   ```

2. Example Design 包含：
   - PCIe Root Port BFM（模拟 PC 端 PCIe 控制器）
   - 完整的 TLP 事务生成器
   - 可以发送真实的 PCIe 读写命令

3. 将 `tb_pcie_large_gemm.sv` 中的 AXI 任务替换为 Example Design 的 PCIe 任务
