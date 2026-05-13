import numpy as np
from pathlib import Path
import re
from utils import numpy_to_verilog_mem
np.random.seed(42)
# 总元素数量
shape = [
    (16, 176, 176),
    (32, 88, 88),
    (16, 88, 88), #(16, 96, 88)
    (64, 44, 44),
    (32, 44, 44),  #(32, 48, 44)
    (128, 22, 22),
    (64, 22, 22),
    (256, 11, 11),
    (128, 11, 11), #(128, 12, 11)
    (24, 44, 44),  #(32, 48, 44)
    (24, 22, 22),  #(32, 24, 22)
    (24, 11, 11)   #(32, 16, 11)
]
task = "dqa"   # Change
test_index = 1

c, h, w = shape[test_index]
h = 1
# N = c * h * w

# 生成 int32 数据（不超出 fp16 可表示范围）
x = np.random.randint(low=-10000, high=10000, size=(1, h, w, c), dtype=np.int32)
# x = np.linspace(1500, -1500, num=N, dtype=np.int32).reshape((1, h, w, c))
# x = np.ones((1, h, w, c), dtype=np.int32)

# clip 到 float16 可表示的范围，防止 overflow
# fp16_max = np.finfo(np.float16).max
# fp16_min = np.finfo(np.float16).min

# x_clipped = np.clip(x, fp16_min, fp16_max)

# 转为 fp16
# x_fp16 = x_clipped.astype(np.float16)
x_fp = x.astype(np.float32)

# 生成一个 (1, 64) 的 fp16 向量
scale = (np.random.rand(1, c) * 0.5).astype(np.float32)
# scale = np.ones((1, c)).astype(np.float32)

# 想要 [-5, 5]
bias = (np.random.rand(1, c) * 10 - 5).astype(np.float32)
# bias = np.ones((1, c)).astype(np.float32) * 5

# 按最后一个维度（通道维）逐元素乘法（广播）
y = x_fp * scale + bias

print(x_fp, scale, y)

folder = r"G:\PKU\Yolo_on_FPGA\Architecture\YOLO rtl\TB\mem"
verilog_parts = []
verilog_parts.append(numpy_to_verilog_mem(x, "act", "act_data", "int32", folder, "dqa"))
verilog_parts.append(numpy_to_verilog_mem(scale, "scale", "scale_data", "fp32", folder, "dqa"))
verilog_parts.append(numpy_to_verilog_mem(bias, "bias", "bias_data", "fp32", folder, "dqa"))
verilog_parts.append(numpy_to_verilog_mem(y, "expected", "expected_data", "fp32", folder, "dqa"))

# 合并为整体字符串
merged_verilog_code = "\n\n".join(verilog_parts)

# ==============================
# 3️⃣ 用正则表达式替换 .sv 文件中的内容
# ==============================
sv_path = Path("/data/home/rn_xu29/Projects/YOLO-On-FPGA/rtl/vpu/tb/dqa_unit_tb.sv")

with open(sv_path, "r") as f:
    sv_content = f.read()

# 用正则匹配 /*{task}*/ ... /*{task}*/
pattern = re.compile(r"/\*\s*mem\s*\*/.*?/\*\s*mem\s*\*/", re.DOTALL)
new_sv_content = re.sub(
    pattern,
    f"/* mem */\n{merged_verilog_code}\n/* mem */",
    sv_content
)

# 写回文件
with open(sv_path, "w") as f:
    f.write(new_sv_content)

print(f"✅ 已成功更新 {sv_path} 中 /* mem */ 区域内容！")