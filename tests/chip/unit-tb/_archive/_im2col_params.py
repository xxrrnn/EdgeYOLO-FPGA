"""Verify im2col parameters with CORRECT field mapping."""
# Correct decoding:
# body[0]=unit_choose=7, body[1]=src_addr=0, body[2]=src2_addr=0
# body[3]=src_c=3, body[4]=src_h=12, body[5]=src_w=12
# body[6]=bias_addr=0, body[7]=scale_addr=0
# body[8]=dst_addr=0x900, body[9]=addr_break=0x06062222
# body[10]=addr_s(OH)=6, body[11]=addr_t(OW)=6

src_addr = 0x000000
dst_addr = 0x000900
src_c = 3   # CH_IN
src_h = 12  # H
src_w = 12  # W
addr_break = 0x06062222
kH = (addr_break >> 24) & 0xFF   # 6
kW = (addr_break >> 16) & 0xFF   # 6
strideH = (addr_break >> 12) & 0xF   # 2
strideW = (addr_break >> 8) & 0xF    # 2
padH = (addr_break >> 4) & 0xF      # 2
padW = addr_break & 0xF             # 2
OH = 6
OW = 6

print(f"im2col params:")
print(f"  input: {src_h}x{src_w}x{src_c} @ src=0x{src_addr:X}")
print(f"  kernel: {kH}x{kW}, stride={strideH}x{strideW}, pad={padH}x{padW}")
print(f"  output: OH={OH}, OW={OW} → {OH*OW} output pixels")
print(f"  dst=0x{dst_addr:X}")

# Verify OH/OW formula
oh_expect = (src_h + 2*padH - kH) // strideH + 1
ow_expect = (src_w + 2*padW - kW) // strideW + 1
print(f"  Verify: OH=(12+4-6)/2+1={oh_expect}, OW={ow_expect} ✓" if oh_expect == OH else f"  !! OH mismatch: expect {oh_expect}")

# Compute memory layout
elem_bytes = 1  # INT8
elem_total_bytes = src_c * elem_bytes  # 3
in_col_stride = ((elem_total_bytes + 15) // 16) * 16  # 16
kw_times_c = kW * elem_total_bytes  # 18
kH_kw_c = kH * kw_times_c  # 108

# row_stride from RTL: ceil(kH_kw_c/64)*64 (for INT8, DCIM_CH_IN=64)
row_stride = ((kH_kw_c + 63) // 64) * 64  # ceil(108/64)*64 = 128
total_output_bytes = OH * OW * row_stride  # 36 * 128 = 4608
total_output_words = total_output_bytes // 16  # 288

print(f"\nOutput layout:")
print(f"  elem_total_bytes = {elem_total_bytes}")
print(f"  in_col_stride    = {in_col_stride}")
print(f"  kH*kW*CH_IN      = {kH_kw_c}")
print(f"  row_stride        = {row_stride} bytes = {row_stride//16} words")
print(f"  total output      = {total_output_bytes} bytes = {total_output_words} words")
print(f"  dst range: 0x{dst_addr:X} .. 0x{dst_addr + total_output_bytes:X}")
print(f"  check_words = 256 (first 256 out of {total_output_words})")

# Check input data range
src_size = src_h * src_w * in_col_stride  # 12*12*16 = 2304
print(f"\nInput layout:")
print(f"  src range: 0x{src_addr:X} .. 0x{src_addr + src_size:X} ({src_size} bytes = {src_size//16} words)")

# VPU_BUF capacity
VPU_BUF_SIZE = 0x800000  # 8MB
print(f"\n  dst end 0x{dst_addr + total_output_bytes:X} < VPU_BUF {VPU_BUF_SIZE:#X}: {'OK' if dst_addr + total_output_bytes < VPU_BUF_SIZE else 'OVERFLOW!'}")

# Check for overlap between src and dst
if dst_addr < src_addr + src_size and src_addr < dst_addr + total_output_bytes:
    print(f"\n  !! SRC and DST OVERLAP: src=[0x{src_addr:X}..0x{src_addr+src_size:X}] dst=[0x{dst_addr:X}..0x{dst_addr+total_output_bytes:X}]")
    # Check specific overlap region
    overlap_start = max(src_addr, dst_addr)
    overlap_end = min(src_addr + src_size, dst_addr + total_output_bytes)
    print(f"  !! Overlap region: 0x{overlap_start:X} .. 0x{overlap_end:X} ({overlap_end - overlap_start} bytes)")
    print(f"  !! This means im2col will overwrite its own input data!")
else:
    print(f"\n  No src/dst overlap (src ends at 0x{src_addr+src_size:X}, dst starts at 0x{dst_addr:X})")
