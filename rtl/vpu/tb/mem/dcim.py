import numpy as np
from pathlib import Path
from utils import numpy_to_verilog_mem
import re
np.random.seed(30)

ko, kc, kh, kw = (32, 64, 3, 3)
act = np.random.randint(-128, 127, size=(kh, kw, kc), dtype=np.int8)
weight = np.random.randint(-128, 127, size=(ko, kh, kw, kc), dtype=np.int8)

print(act)
# print(weight)
# 转换为 int32，避免溢出
res = np.tensordot(weight.astype(np.int32), act.astype(np.int32), axes=([1, 2, 3], [0, 1, 2]))

print(res.shape)      # (32,)
print(res)      # int32


















folder = r"G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/DCIM_MACRO/mem"

verilog_parts = []
verilog_parts.append(numpy_to_verilog_mem(act, "act", "act_data", "int8", folder, "mac"))
verilog_parts.append(numpy_to_verilog_mem(weight, "weight", "weight_data", "int8", folder, "mac"))
verilog_parts.append(numpy_to_verilog_mem(res, "expected", "expected_data", "int32", folder, "mac"))

# 合并为整体字符串
merged_verilog_code = "\n\n".join(verilog_parts)

# ==============================
# 3️⃣ 用正则表达式替换 .sv 文件中的内容
# ==============================
sv_path = Path(r"G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/DCIM_MACRO/new/tb_DCIM_Macro.sv")

with open(sv_path, "r", encoding="utf-8") as f:
    sv_content = f.read()

# 用正则匹配 /*{task}*/ ... /*{task}*/
pattern = re.compile(r"/\*\s*mem\s*\*/.*?/\*\s*mem\s*\*/", re.DOTALL)
new_sv_content = re.sub(
    pattern,
    lambda _: f"/* mem */\n{merged_verilog_code}\n/* mem */",
    sv_content
)

# 写回文件
with open(sv_path, "w", encoding="utf-8") as f:
    f.write(new_sv_content)

print(f"✅ 已成功更新 {sv_path} 中 /* mem */ 区域内容！")