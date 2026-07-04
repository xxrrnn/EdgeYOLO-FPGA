import numpy as np
from pathlib import Path
import re
import torch
import torch.nn as nn
import torch.nn.functional as F
from utils import numpy_to_verilog_mem
np.random.seed(42)
# 总元素数量
shape = [
    (128, 11, 11)
]
task = "mp"   # Change
test_index = 0

c, h, w = shape[test_index]
# h = 1

maxpool = nn.MaxPool2d(kernel_size=5, stride=1, padding=2)

x = torch.randn(1, c, w, h, dtype=torch.float32)

x_paded = F.pad(x, pad=(2,2,2,2))

print(x_paded.shape)
# 前向计算
output = maxpool(x)
# print("\nOutput after MaxPool2d:\n", output)
print("\nOutput shape:", output.shape)

folder = "G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/Global_vpu_tb/NEW_VPU/gm/mem"
verilog_parts = []
verilog_parts.append(numpy_to_verilog_mem(x_paded.permute(0,3,2,1).numpy(), var_name="act", file_prefix="act_data", type="fp32", task="mp", out_dir=folder))

verilog_parts.append(numpy_to_verilog_mem(output.permute(0,3,2,1).numpy(), "expected", file_prefix="expected_data", type="fp32", task="mp", out_dir=folder))


# 合并为整体字符串
merged_verilog_code = "\n\n".join(verilog_parts)

# ==============================
# 3️⃣ 用正则表达式替换 .sv 文件中的内容
# ==============================
sv_path = Path(r"G:\PKU\Yolo_on_FPGA\Architecture\YOLO rtl\Global_vpu_tb\NEW_VPU\mp_unit_top_tb.sv")

with open(sv_path, "r", encoding="utf-8") as f:
    sv_content = f.read()

# 用正则匹配 /*{task}*/ ... /*{task}*/
pattern = re.compile(r"/\*\s*mem\s*\*/.*?/\*\s*mem\s*\*/", re.DOTALL)
new_sv_content = re.sub(
    pattern,
    f"/* mem */\n{merged_verilog_code}\n/* mem */",
    sv_content
)

# 写回文件
with open(sv_path, "w", encoding="utf-8") as f:
    f.write(new_sv_content)

print(f"✅ 已成功更新 {sv_path} 中 /* mem */ 区域内容！")