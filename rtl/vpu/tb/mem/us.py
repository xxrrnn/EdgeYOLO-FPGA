import numpy as np
from pathlib import Path
import re
from utils import numpy_to_verilog_mem
import torch
import torch.nn as nn

# 输入的维度
c, h, w = 128, 22, 22  # 输入张量的形状
task = "us"

# 设置随机种子以保证结果可复现
np.random.seed(42)

# 生成一个随机的输入张量，值的范围在[-128, 127]
x = torch.randn(1, c, w, h, dtype=torch.float32)

# 定义上采样层，使用最近邻算法，放大因子为2
upsample = nn.Upsample(scale_factor=2.0, mode='nearest')

# 执行上采样操作
output = upsample(x)

# 将输入张量 `x` 和输出张量 `output` 转换为所需的形状： (1, H, W, C)
# 这里，我们使用 .permute 将维度从 (1, C, H, W) 转换为 (1, H, W, C)
x_reshaped = x.permute(0, 2, 3, 1).numpy()  # 变成 (1, H, W, C)
output_reshaped = output.permute(0, 2, 3, 1).numpy()  # 变成 (1, H, W, C)

# mem_path 存储 mem 文件的路径
mem_path = r"G:\PKU\Yolo_on_FPGA\Architecture\YOLO rtl\TB\mem"
tb_path = r"G:\PKU\Yolo_on_FPGA\Architecture\YOLO rtl\TB\tb_us_unit.sv"

# 用于存储 Verilog 部分的列表
verilog_parts = []

# 将张量转换为 Verilog 内存格式（对于 x 和 output）
verilog_parts.append(numpy_to_verilog_mem(x_reshaped, "act", "act_data", "fp32", mem_path, task))
verilog_parts.append(numpy_to_verilog_mem(output_reshaped, "output", "output_data", "fp32", mem_path, task))

# 合并生成的 Verilog 代码
merged_verilog_code = "\n\n".join(verilog_parts)

# 读取并修改 sv 文件
sv_path = Path(tb_path)
with open(sv_path, "r", encoding="utf-8") as f:
    sv_content = f.read()

# 使用正则表达式匹配 /* mem */ ... /* mem */ 区域
# 使用原始字符串，避免不必要的转义
pattern = re.compile(r"/\*\s*mem\s*\*/.*?/\*\s*mem\s*\*/", re.DOTALL)
new_sv_content = re.sub(
    pattern,
    f"/* mem */\n{merged_verilog_code}\n/* mem */",  # 使用f-string确保替换正确
    sv_content
)

# 写回修改后的 sv 文件
with open(sv_path, "w", encoding="utf-8") as f:
    f.write(new_sv_content)

print(f"✅ 已成功更新 {sv_path} 中 /* mem */ 区域内容！")
