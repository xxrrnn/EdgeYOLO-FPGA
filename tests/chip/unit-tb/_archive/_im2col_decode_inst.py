"""Decode im2col instruction parameters to verify correctness."""
from pathlib import Path
from xdma_win import hex_to_bin, parse_inst_words, VPU_BUF_BASE, VPU_BUF_SIZE

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\im2col_im2col_6x6_s2_c3_qint8")
insts = parse_inst_words(run_dir / "inst.hex")

print(f"Total instruction words: {len(insts)}")
print()

# inst.hex format for VPU_EXEC:
# word 0: header [31:28]=opcode(0x2=VPU_EXEC), [23:0]=body_length
# word 1..N: body
header = insts[0]
opcode = (header >> 28) & 0xF
body_len = header & 0xFFFFFF
print(f"Header: 0x{header:08X}  opcode={opcode:#x} body_length={body_len}")
print(f"  opcode 0x2 = OP_VPU_EXEC")
print()

# VPU_EXEC body format (from INST_Decoder.sv):
# body[0] = unit_choose (7=im2col)
# body[1] = src_addr
# body[2] = dst_addr  
# body[3] = src_c
# body[4] = src_h
# body[5] = src_w
# body[6] = addr_break
# body[7] = addr_s (OH for im2col)
# body[8] = addr_t (OW for im2col)
# body[9] = dst_addr (alias, or additional)
# body[10] = len1
# body[11] = len2
body = insts[1:1+body_len//4]
print(f"Body ({len(body)} words):")
for i, w in enumerate(body):
    print(f"  body[{i:2d}] = 0x{w:08X} ({w})")

print()
# Parse im2col fields
unit_choose = body[0]
src_addr = body[1]
dst_addr = body[2] if len(body) > 2 else 0
src_c = body[3] if len(body) > 3 else 0
src_h = body[4] if len(body) > 4 else 0
src_w = body[5] if len(body) > 5 else 0
addr_break = body[6] if len(body) > 6 else 0
addr_s = body[7] if len(body) > 7 else 0  # OH
addr_t = body[8] if len(body) > 8 else 0  # OW

print(f"Decoded im2col params:")
print(f"  unit_choose = {unit_choose} {'(im2col=7)' if unit_choose == 7 else '(!!! NOT IM2COL !!!)'}")
print(f"  src_addr    = 0x{src_addr:08X} (VPU_BUF byte offset)")
print(f"  dst_addr    = 0x{dst_addr:08X} (VPU_BUF byte offset)")
print(f"  src_c (CH_IN) = {src_c}")
print(f"  src_h (H)     = {src_h}")
print(f"  src_w (W)     = {src_w}")

kH = (addr_break >> 24) & 0xFF
kW = (addr_break >> 16) & 0xFF
strideH = (addr_break >> 12) & 0xF
strideW = (addr_break >> 8) & 0xF
padH = (addr_break >> 4) & 0xF
padW = addr_break & 0xF
print(f"  addr_break  = 0x{addr_break:08X}")
print(f"    kH={kH}, kW={kW}, strideH={strideH}, strideW={strideW}, padH={padH}, padW={padW}")
print(f"  addr_s (OH) = {addr_s}")
print(f"  addr_t (OW) = {addr_t}")

# Compute expected output size
elem_bytes = 1  # INT8
elem_total = src_c * elem_bytes
in_col_stride = ((elem_total + 15) // 16) * 16
kw_times_c = kW * elem_total
kH_kw_c = kH * kw_times_c
row_stride = ((kH_kw_c + 63) // 64) * 64  # round up to 64 bytes (DCIM_CH_IN=64)
total_output_bytes = addr_s * addr_t * row_stride
total_output_words = total_output_bytes // 16

print(f"\nComputed layout:")
print(f"  elem_total_bytes = {elem_total}")
print(f"  in_col_stride    = {in_col_stride}")
print(f"  kH*kW*CH_IN     = {kH_kw_c}")
print(f"  row_stride       = {row_stride} bytes = {row_stride//16} words")
print(f"  OH*OW            = {addr_s * addr_t}")
print(f"  total output     = {total_output_bytes} bytes = {total_output_words} words")
print(f"  dst_end          = 0x{dst_addr + total_output_bytes:08X}")
print(f"  VPU_BUF_SIZE     = 0x{VPU_BUF_SIZE:08X}")
if dst_addr + total_output_bytes > VPU_BUF_SIZE:
    print(f"  !!! OVERFLOW: dst_end > VPU_BUF_SIZE !!!")
else:
    print(f"  (within VPU_BUF)")

# Also check src range
src_size = src_h * src_w * in_col_stride
print(f"\n  src range: 0x{src_addr:08X} .. 0x{src_addr + src_size:08X} ({src_size} bytes)")
if src_addr + src_size > VPU_BUF_SIZE:
    print(f"  !!! SRC OVERFLOW !!!")

# Check remaining instructions (OP_END)
remaining = insts[1+body_len//4:]
print(f"\nRemaining instructions after VPU_EXEC: {[f'0x{w:08X}' for w in remaining]}")
