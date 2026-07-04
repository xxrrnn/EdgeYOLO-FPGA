"""Verify im2col RTL address calculation by simulating the Python equivalent."""
# Parameters from the test: 12x12x3 input, 6x6 kernel, stride 2, pad 2, OH=OW=6
# ELEM_BYTES = 1
CH_IN = 3
H, W = 12, 12
KH, KW = 6, 6
STRIDE_H, STRIDE_W = 2, 2
PAD_H, PAD_W = 2, 2
OH, OW = 6, 6
ELEM_BYTES = 1
WORD_BYTES = 16  # GB_BANDWIDTH/8 = 128/8 for lite chip (or 256/8=32 for chip)

# Precompute (mimic RTL S_INIT, S_PRECOMPUTE, S_PRECOMPUTE2, S_PRECOMPUTE3)
elem_total_bytes = CH_IN * ELEM_BYTES   # = 3
c_chunk_max = (elem_total_bytes + 15) >> 4  # = 1 (since 3 < 16)
in_col_stride = ((elem_total_bytes + 15) >> 4) << 4  # = 16
kw_times_c = KW * elem_total_bytes  # = 18
w_times_c = W * in_col_stride  # = 192
stride_w_c = STRIDE_W * in_col_stride  # = 32
kH_kw_c = KH * kw_times_c  # = 108
stride_h_wc = STRIDE_H * w_times_c  # = 384
in_base = 0 - PAD_H * w_times_c - PAD_W * in_col_stride  # src_addr=0
# in_base = 0 - 2*192 - 2*16 = -416
row_stride = (kH_kw_c + 63) & ~63  # INT8: ceil(108/64)*64 = 128

print(f"elem_total_bytes = {elem_total_bytes}")
print(f"c_chunk_max      = {c_chunk_max}")
print(f"in_col_stride    = {in_col_stride}")
print(f"kw_times_c       = {kw_times_c}")
print(f"w_times_c        = {w_times_c}")
print(f"stride_w_c       = {stride_w_c}")
print(f"kH_kw_c          = {kH_kw_c}")
print(f"stride_h_wc      = {stride_h_wc}")
print(f"in_base          = {in_base}")
print(f"row_stride       = {row_stride}")
print()

# Now simulate the loop with incremental accumulators (exactly as RTL does it)
# RTL uses:
#   in_kw_acc_r += in_col_stride  on kw advance
#   in_kh_acc_r += w_times_c      on kh advance (but NOT when kw wraps!)
#   in_ow_acc_r += stride_w_c     on ow advance
#   in_oh_acc_r += stride_h_wc    on oh advance
#
# out_col_offset_r += elem_total_bytes on kw advance
# out_row_offset_r += row_stride on ow advance AND on oh advance

# But check the RTL carefully for the out_col_offset_r on kh advance:
# Line 531: out_col_offset_r <= out_col_offset_r + elem_total_bytes;
# This happens AFTER kw wraps (i.e., when kw+1 >= kW_r).
# So the pattern is:
#   kw=0..5: out_col_offset += elem_total_bytes each time (CORRECT: 6 advances = 18 bytes)
#   kh advance: out_col_offset += elem_total_bytes (one MORE advance)
#   kh=0: col_offset starts at 0, after kw=0..5 we add 5 times(wait no...)
#
# Actually let's trace it carefully:
# S_NEXT: 
#   if (kw + 1 < kW_r):
#       kw++; in_kw_acc_r += in_col_stride; out_col_offset_r += elem_total_bytes
#   else:
#       kw = 0; in_kw_acc_r = 0
#       if (kh + 1 < kH_r):
#           kh++; in_kh_acc_r += w_times_c
#           out_col_offset_r <= out_col_offset_r + elem_total_bytes  # ← HERE
#       else:
#           kh = 0; in_kh_acc_r = 0; out_col_offset_r = 0

# So for kh transition: out_col_offset gets ONE MORE elem_total_bytes added.
# This means: after kw=5 (last kw), the advance happens via the "kh++" branch.
# Let's trace out_col_offset for first two kh rows:
#   kh=0, kw=0: col_offset = 0  → write at dst + 0
#   kh=0, kw=1: col_offset = 3  → write at dst + 3
#   kh=0, kw=2: col_offset = 6  → write at dst + 6
#   kh=0, kw=3: col_offset = 9  → write at dst + 9
#   kh=0, kw=4: col_offset = 12 → write at dst + 12
#   kh=0, kw=5: col_offset = 15 → write at dst + 15
#   -- kw+1=6 >= kW=6, so go to kh branch --
#   kh=1: col_offset = 15 + 3 = 18 → write at dst + 18  ✓ (should be kH=0 done = 6*3=18)
#
# So far correct. Let me verify fully for all kh:
#   kh=1, kw=0: col_offset = 18  ✓ (kh=1, kw=0 → (1*6+0)*3=18)
#   kh=1, kw=1: col_offset = 21  ✓ (kh=1, kw=1 → (1*6+1)*3=21)
#   ... kh=1, kw=5: col_offset = 33 ✓ (1*6+5)*3=33
#   kh=2: col_offset = 33 + 3 = 36 ✓ (2*6+0)*3=36
#   ...
# OK, out_col_offset logic is correct.

# Now check the READ address:
# in_pixel_byte_addr = in_base + in_oh_acc + in_kh_acc + in_ow_acc + in_kw_acc + c_chunk_byte_offset
# = in_base + oh*stride_h_wc + kh*w_times_c + ow*stride_w_c + kw*in_col_stride + 0
# Expected: src_addr + (ih*W + iw) * in_col_stride
#         = 0 + ((oh*stride_H - pad_H + kh)*W + (ow*stride_W - pad_W + kw)) * in_col_stride
#         = ((oh*2 - 2 + kh)*12 + (ow*2 - 2 + kw)) * 16

# RTL: in_base + oh*stride_h_wc + kh*w_times_c + ow*stride_w_c + kw*in_col_stride
#    = (src - pad_H*w_c - pad_W*col_stride) + oh*stride_H*w_c + kh*w_c + ow*stride_W*col_stride + kw*col_stride
#    = src + (oh*stride_H - pad_H + kh)*w_c + (ow*stride_W - pad_W + kw)*col_stride
# But w_c = W * in_col_stride!
#    = src + (oh*stride_H - pad_H + kh) * W * in_col_stride + (ow*stride_W - pad_W + kw) * in_col_stride
#    = src + ((oh*stride_H - pad_H + kh)*W + (ow*stride_W - pad_W + kw)) * in_col_stride ✓
#
# So the address calculation is MATHEMATICALLY correct. The issue must be somewhere else.

# Let me check: what's WORD_BYTES on the actual chip?
# The im2col uses GB_BANDWIDTH parameter. In the chip, the VPU BUF is 256-bit = 32 bytes wide.
# But src_addr=0, dst_addr=2304:
# dst_addr should be large enough. Let me check if dst_addr + max_output exceeds VPU_BUF.

max_output_byte = (OH * OW - 1) * row_stride + kH_kw_c
print(f"Max output byte from dst_addr=2304: {2304 + max_output_byte}")
print(f"  row_stride = {row_stride}, total rows = {OH*OW} = {OH*OW}")
print(f"  Total output region: {OH * OW * row_stride} bytes")
print(f"  dst end = 2304 + {OH*OW*row_stride} = {2304 + OH*OW*row_stride}")
print()

# Source region: 12x12 with col_stride=16 → 12*12*16 = 2304 bytes, fits in [0, 2303]
print(f"Source region: 0 .. {12*12*16 - 1}")
print(f"Output region: 2304 .. {2304 + OH*OW*row_stride - 1}")
print()

# Check VPU_BUF size:
# From chip_defines.vh or elsewhere... typical OBUF size is much larger.
# The key question is: does the output region OVERLAP the source region?
overlap = (2304 < 12*12*16)
print(f"Source/Output overlap: {overlap}")  # src ends at 2303, dst starts at 2304 → NO OVERLAP ✓

# Now check the WRITE address alignment with WORD_BYTES=32 (chip):
# If chip VPU_BUF is 256-bit wide (32 bytes), out_byte_in_word = out_byte_addr[4:0] (5 bits)
# But RTL line 187: out_byte_in_word = out_byte_addr[3:0] ← ONLY 4 BITS!
# This means the RTL only handles 16-byte words but the actual OBUF may be 32 bytes wide!
print("="*60)
print("CRITICAL: out_byte_in_word = out_byte_addr[3:0] → only 4 bits!")
print("If GB_BANDWIDTH=256 (chip), WORD_BYTES=32, but byte-in-word is only [3:0]!")
print("This means bytes at positions 16..31 within a 32-byte word are WRONG!")
print("="*60)
print()

# Wait - let's check: the write address alignment mask is ~32'd15 (line 201)
# write_byte_addr_aligned = out_byte_addr & ~32'd15
# This aligns to 16 bytes, not to WORD_BYTES (32 bytes)!
# 
# If WORD_BYTES=32 (256-bit bus), then:
#   - The OBUF is addressed in 32-byte words (each address = 32 bytes)
#   - But the code aligns to 16 bytes and uses [3:0] for byte offset
#   - The gb_addrb is GB_ADDR_WIDTH bits, and the OBUF decodes it as word address
#
# Actually wait - gb_addrb is BYTE addressed (look at line 392: gb_addrb <= in_pixel_byte_addr)
# Then the OBUF converts to word address internally. Let me check WORD_BYTES from the parameters.

# The issue might be:
# - On chip: GB_BANDWIDTH=256 → WORD_BYTES=32
# - write_split_at = WORD_BYTES (if WORD_BYTES > C_CHUNK_BYTES which is 16)
#   → write_split_at = 32
# - write_end_pos = out_byte_in_word + write_chunk_nbyte
#   = out_byte_addr[3:0] + 3 = up to 15 + 3 = 18
# - 18 > 16 could cause a tail write, but write_split_at is 32
#   → write_end_pos (18) <= write_split_at (32) → NO tail write
#
# But out_byte_in_word is out_byte_addr[3:0] which only captures bits [3:0].
# If the ACTUAL byte-in-word should be [4:0] (for 32B words), then
# out_byte_in_word is WRONG → data placed at wrong position within the 32B word!

# Actually, re-read line 201:
# write_byte_addr_aligned = out_byte_addr & ~32'd15
# This gives a 16B-aligned address. But if OBUF word is 32B, the gb_addrb given to
# the OBUF should be the WORD address (byte_addr / 32) or byte_addr aligned to 32.
# Using & ~15 gives 16B alignment, not 32B alignment.

# This might be the bug for 256-bit OBUF. But let me check what GB_BANDWIDTH actually is on chip.
# From the instantiation in Global_VPU:
print("Need to check: what is GB_BANDWIDTH for im2col_unit on the actual chip?")
print("If GB_BANDWIDTH=128 (16-byte words), the logic is correct.")
print("If GB_BANDWIDTH=256 (32-byte words), there's a fundamental address bug.")
