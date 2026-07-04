# Global BRAM初始化说明

## 问题
当前global_bram配置为`use_bram_block = BRAM_Controller`模式，通过外部AXI BRAM Controller访问。在此模式下，Xilinx IP的`Load_Init_File`和`Coe_File`参数被禁用，**无法通过COE文件在综合/仿真时初始化BRAM内容**。

## 当前架构
```
XDMA --> AXI Interconnect --> global_bram_ctrl (axi_bram_ctrl) --> global_bram (blk_mem_gen)
```

global_bram被配置为由外部控制器管理，因此不支持直接的初始化文件。

## 测试建议

### 方案1：仅验证控制信号（当前testbench采用）
测试重点：
- INST_Decoder能否正确解析CDMA指令
- cdma_start信号是否触发
- CDMA参数传递是否正确

验证方法：
- 在testbench中检测cdma_start脉冲
- 在波形中观察CDMA AXI接口信号

### 方案2：Python脚本进行端到端测试
使用`tests/vpu/test_inst_decoder.py`进行实际硬件测试：
1. 通过XDMA写入测试数据到global_bram
2. 通过INST_Decoder控制CDMA搬运
3. 读回VPU_GB验证数据

### 方案3：修改BD架构（不推荐，工作量大）
将global_bram改为Native模式（不使用AXI BRAM Controller），但这会：
- 需要修改整个AXI总线架构
- 影响XDMA访问方式
- 需要大量regression测试

## 结论
由于当前架构限制，**建议采用方案1+方案2组合**：
- Testbench验证控制逻辑和信号
- Python脚本验证实际数据传输
- 在GUI波形中手动观察CDMA AXI传输行为
