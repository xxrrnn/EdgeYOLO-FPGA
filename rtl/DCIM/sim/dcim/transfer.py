import numpy as np

def _compact_bits(s: str) -> str:
	"""Remove all ASCII whitespace from a bitstring line."""
	return ''.join(s.split())

def _twos_complement_int(bits: str) -> int:
	"""Convert a two's complement bit string to int."""
	width = len(bits)
	value = int(bits, 2)
	if bits[0] == '1':
		value -= (1 << width)
	return value

def _parse_row_bitstring(row_bits: str, WD1: int, CH_OUT: int, signed: bool) -> np.ndarray:
	"""
	Parse one row bitstring into a numpy array of length CH_OUT.

	Each element occupies WD1 bits; elements are taken left-to-right.
	"""
	expected_len = WD1 * CH_OUT
	row_bits = _compact_bits(row_bits)
	if len(row_bits) != expected_len:
		raise ValueError(f"Row length {len(row_bits)} != expected {expected_len}({WD1}x{CH_OUT})")
	elems = []
	for i in range(CH_OUT):
		start = i * WD1
		end = start + WD1
		chunk = row_bits[start:end]
		if signed:
			elems.append(_twos_complement_int(chunk))
		else:
			elems.append(int(chunk, 2))
		# Use Python ints (object dtype) to avoid overflow when width exceeds 32 bits.
	return np.array(elems, dtype=object)

def transfer_weight(file_name_in, file_name_out=None, WD=4, ROWS=4, COLS=4, sign=0):
	"""
	从文件中读取二进制权重矩阵。

	参数:
	- file_name_in: 输入文件路径，每行是 COLS*WD1 位的二进制字符串，表示一行权重。
	- file_name_out: 可选，输出文件路径；若提供则将解析后的十进制矩阵写出，每行空格分隔。
	- WD1: 元素位宽。
	- ROWS: 行数；若为 -1，则不指定行数，读取到文件末尾。
	- COLS: 列数。
	- sign: 1 表示有符号(二进制补码)，0 表示无符号。

	返回:
	- 形状为 (实际行数, COLS) 的 numpy 数组。
	"""
	signed = bool(sign)
	rows = []
	with open(file_name_in, 'r') as f:
		for line in f:
			norm = _compact_bits(line)
			if not norm:
				continue
			rows.append(norm)

	# 处理 ROWS = -1：使用文件的全部有效行
	if ROWS == -1:
		num_rows = len(rows)
	else:
		if len(rows) < ROWS:
			raise ValueError(f"文件行数 {len(rows)} 少于 ROWS={ROWS}")
		# 若文件行数更多，只取前 ROWS 行
		if len(rows) > ROWS:
			rows = rows[:ROWS]
		num_rows = ROWS

	matrix = np.zeros((num_rows, COLS), dtype=object)
	for r in range(num_rows):
		matrix[r, :] = _parse_row_bitstring(rows[r], WD, COLS, signed)

	if file_name_out:
		with open(file_name_out, 'w') as fo:
			for r in range(num_rows):
				fo.write(' '.join(str(int(x)) for x in matrix[r, :]))
				fo.write('\n')

	return matrix

def transfer_act(file_name_in, file_name_out=None, WD1=4, C=1, COLS=4, sign=0):
	"""
	读取二进制数据，按 R 行分组，拼接形成激活向量的每个元素，元素位宽为 R*WD1。

	每 R 行表示一个向量：给定一组 R 行，对第 k 个元素（0<=k<CH_IN），
	取每一行的 [k*WD1 : (k+1)*WD1] 位段，按行顺序依次拼接，得到该元素的 R*WD1 位串。

	参数:
	- file_name_in: 输入文件路径（每行长度应为 CH_IN*WD1）。
	- file_name_out: 可选，输出文件路径；若提供则写出十进制矩阵，每行空格分隔。
	- WD1: 单个小段位宽。
	- R: 拼接段数（每组行数）。
	- CH_IN: 激活向量的元素个数（每行包含的段数）。
	- sign: 1 表示有符号（对 R*WD1 位的二进制补码），0 表示无符号。

	返回:
	- 形状为 (N, CH_IN) 的 numpy 数组（N=可从文件行数推得的向量个数；使用 object dtype 以安全承载大位宽）。
	"""
	signed = bool(sign)
	# 读取所有非空行
	lines = []
	with open(file_name_in, 'r') as f:
		for line in f:
			norm = _compact_bits(line)
			if not norm:
				continue
			lines.append(norm)

	# 可生成的向量个数：按 C 行一组
	groups = len(lines) // C
	if groups == 0:
		raise ValueError(f"文件行数不足以形成一个完整的 {C} 行组")
	usable_lines = lines[: groups * C]

	# 校验每行宽度
	expected_len = COLS * WD1
	for idx, row_bits in enumerate(usable_lines):
		if len(row_bits) != expected_len:
			raise ValueError(f"第 {idx} 行长度 {len(row_bits)} != 期望 {expected_len}")

	# 解析：每 R 行为一组，形成一个向量（一行输出）
	result = [[0] * COLS for _ in range(groups)]
	for g_idx in range(groups):
		group = usable_lines[g_idx * C : (g_idx + 1) * C]
		for k in range(COLS):
			chunks = [row[k * WD1 : (k + 1) * WD1] for row in group]
			concat_bits = ''.join(chunks)
			if signed:
				value = _twos_complement_int(concat_bits)
			else:
				value = int(concat_bits, 2)
			result[g_idx][k] = value

	matrix = np.array(result, dtype=object)

	if file_name_out:
		with open(file_name_out, 'w') as fo:
			for r in range(groups):
				fo.write(' '.join(str(int(x)) for x in matrix[r, :]))
				fo.write('\n')

	return matrix


def get_config():
	import os
	config = {
		"type": os.getenv("TYPE", "INT4"),
		"acc": int(os.getenv("ACC", 0)),
		"WD1": int(os.getenv("WD1", 4)),
		"ch_in": int(os.getenv("CH_IN", 16)),
		"ch_out": int(os.getenv("CH_OUT", 16)),
		"R": int(os.getenv("R", 16))
	}
	return config


if __name__ == "__main__":
	import os
	# 示例：读取本目录下的 weight.mem，并打印矩阵与写出到 weight.txt
	cfg = get_config()

	WD1 = cfg["WD1"]
	CH_IN = cfg["ch_in"]
	CH_OUT = cfg["ch_out"]
	R = cfg["R"]


	ACC = cfg["acc"]
	sign = cfg["type"] in ["INT4", "INT8", "INT16"]
	if cfg["type"] in ["INT4", "UINT4"]:
		C = 1
	elif cfg["type"] in ["INT8", "UINT8"]:
		C = 2
	elif cfg["type"] in ["INT16", "UINT16"]:
		C = 4
	else:
		C = 0
	
	print(f"Type: {cfg["type"]}, Acc: {cfg["acc"]}")

	WD2 = 2*WD1 + np.log2(CH_IN).astype(int)
	WD3 = WD2 + np.log2(R).astype(int)


	weight_in_file = os.path.join(os.path.dirname(__file__), "cache.mem")
	weight_out_file = os.path.join(os.path.dirname(__file__), "weight.txt")
	weight_mat = transfer_weight(weight_in_file, weight_out_file, WD=WD1*C, ROWS=CH_IN, COLS=CH_OUT//C, sign=sign)
	act_in_file = os.path.join(os.path.dirname(__file__), "calculate.mem")
	act_out_file = os.path.join(os.path.dirname(__file__), "act.txt")
	act_mat = transfer_act(act_in_file, act_out_file, WD1=WD1, C=C, COLS=CH_IN, sign=sign)
	result_in_file = os.path.join(os.path.dirname(__file__), "result.mem")
	result_out_file = os.path.join(os.path.dirname(__file__), "result.txt")
	result_mat = transfer_weight(result_in_file, result_out_file, WD=WD3*C, ROWS=-1, COLS=CH_OUT//C, sign=sign)
	print("act Matrix:\n", act_mat)
	print("weight Matrix:\n", weight_mat)
	calculated_result = act_mat.dot(weight_mat)

	if(ACC!=0):
		#以ACC行为一组，将行中对应元素累加，输出 ROS//ACC 行
		num_rows = calculated_result.shape[0] // ACC
		accumulated_result = np.zeros((num_rows, calculated_result.shape[1]), dtype=object)
		for r in range(num_rows):
			accumulated_result[r,:] = np.sum(calculated_result[r*ACC:(r+1)*ACC, :], axis=0)
		calculated_result = accumulated_result

	if np.array_equal(calculated_result, result_mat):
		print("Result:\n", result_mat)
		print("验证通过")
	else:
		print("Calculated Result:\n", calculated_result)
		print("Result Matrix from file:\n", result_mat)
		print("验证失败")
