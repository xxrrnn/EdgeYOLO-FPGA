"""Analyze: which (kh,kw) positions consistently show errors across output pixels."""
# From the detailed output, bytes that repeat:
# byte 5 (kh=0,kw=1,c=2), byte 6 (kh=0,kw=2,c=0), byte 10 (kh=0,kw=3,c=1)
# byte 38 (kh=2,kw=0,c=2)
# byte 69 (kh=3,kw=5,c=0), byte 70 (kh=3,kw=5,c=1)
# byte 74 (kh=4,kw=0,c=2), byte 75 (kh=4,kw=1,c=0)
# byte 94 (kh=5,kw=1,c=1), byte 95 (kh=5,kw=1,c=2)
# byte 102 (kh=5,kw=4,c=0), byte 106 (kh=5,kw=5,c=1)
# byte 126 (kh=7,kw=0,c=0), byte 127 (kh=7,kw=0,c=1) ← kh=7 doesn't exist! kH=6 → kh=0..5

# Wait: kh=7 is IMPOSSIBLE since kH=6. Let me re-check:
# byte 126 → kh_kw_idx = 126 // 3 = 42 → kh = 42 // 6 = 7(!)
# But kH*kW = 36 positions (indices 0..35). Position 42 is OUT OF RANGE.
# byte 126-127 are in the PADDING area of the row_stride (bytes 108..127 are unused padding to fill 128 bytes).

# So "kh=7" errors mean the im2col unit is WRITING DATA INTO THE ROW PADDING AREA
# where only zeros should exist!

# Now let me re-analyze the valid errors: the ones with kh=0..5
# Focus on the INPUT READ address vs what's actually at that address.
# The error pattern shows single-bit flips (mostly bit 5 and bit 7).
# This is VERY suspicious for a READ address error - if the read address is off by a small amount,
# we'd read a completely different value, not a single-bit flip.

# Single-bit flips of SPECIFIC bits (5, 7) suggest a WRITE masking or WRITE DATA issue.
# Specifically: the gb_web or gb_dinb generation has bit errors.

# Let's check: in RTL, write_din_aligned is computed by:
#   write_din_aligned[write_byte_pos*8 +: 8] = rd_data_reg[rd_byte_idx * 8 +: 8]
# where write_byte_pos = out_byte_in_word + write_mask_i
#       rd_byte_idx = in_byte_in_word_r + write_mask_i

# If rd_byte_idx is wrong by even 1, we'd get completely wrong bytes (unrelated data).
# But we're seeing SINGLE BIT flips. This suggests something else.

# Hypothesis: WRITE COLLISION - two write operations hitting the same OBUF word in the same
# or adjacent cycles. The OBUF is a URAM TDP. If port A (CDMA) and port B (im2col) write
# simultaneously, one write wins. But im2col uses only port B.

# Better hypothesis: The im2col writes at byte 126-127 suggest it's writing BEYOND the
# intended kH*kW*CH region. bytes 108-127 should be untouched (padding to row_stride=128).
# If im2col accidentally writes to those bytes, that's a BUG in the loop bounds.

# Looking at S_WRITE:
#   gb_addrb <= write_byte_addr_aligned  (= out_byte_addr & ~15)
#   out_byte_addr = dst_addr_r + out_row_offset_r + out_col_offset_r + c_chunk_byte_offset
#
# After the last valid (kh=5, kw=5) position:
#   out_col_offset = (5*6+5)*3 = 105
#   out_byte_addr = 2304 + row_offset + 105 + 0 = 2304 + row_offset + 105
# Then in S_NEXT when kw wraps AND kh wraps:
#   out_col_offset_r <= 0 (reset)
# But BEFORE that, in S_NEXT line 531:
#   When (kh+1 >= kH), we go to else branch (line 533): kh=0, in_kh_acc=0, out_col_offset=0
# So no spurious write there.

# But wait - what about the WRITE at (kh=5,kw=5)?
# out_col_offset = (5*6+5)*3 = 105
# write_chunk_nbyte = 3 (CH_IN bytes to write)
# out_byte_in_word = (2304 + row_offset + 105) % 16 = (2304+105) % 16 ... 
# dst_addr = 2304, row_stride = 128
# For pixel (oh,ow): out_byte_addr = 2304 + (oh*6+ow)*128 + 105
# (oh*6+ow)*128 is always 128-aligned, so byte_in_word = (2304 + 105) % 16
# 2304 % 16 = 0, 105 % 16 = 9
# So out_byte_in_word = 9
# write_end_pos = 9 + 3 = 12 ≤ 16 → no tail, OK.

# For byte 126: (oh*6+ow)*128 + 126 relative to dst_addr
# pixel_offset + 126 → out_col_offset would be 126
# 126 / 3 = 42, which is kh*kw position 42. But kH*kW=36. This is IMPOSSIBLE in normal loop.

# The ONLY way byte 126-127 gets written is if there's a STALE write from a PREVIOUS
# iteration bleeding through. OR something else writes those bytes.

# Actually - wait. Let me re-read the S_WRITE_TAIL logic.
# S_WRITE_TAIL: gb_addrb <= write_byte_addr_aligned + WORD_BYTES
# This writes to the NEXT 16-byte word. If write_need_tail is erroneously asserted...

# Let's check when write_need_tail occurs for this test:
# write_end_pos = out_byte_in_word + write_chunk_nbyte
# write_chunk_nbyte = 3 (CH_IN=3, c_chunk_max=1 so only one pass)
# out_byte_in_word = out_byte_addr[3:0]
# If out_byte_in_word >= 14 (14+3=17 > 16), we need a tail write.

# When does out_byte_in_word = 14 or 15?
# out_byte_addr = 2304 + (oh*6+ow)*128 + col_offset
# col_offset = (kh*6+kw)*3
# out_byte_addr % 16 = (2304 + col_offset) % 16 = col_offset % 16
# col_offset values that give byte_in_word >= 14:
# col_offset % 16 = 14 → col_offset = 14, 30, 46, 62, 78, 94
# col_offset % 16 = 15 → col_offset = 15, 31, 47, 63, 79, 95

print("Positions where write_need_tail fires (byte_in_word >= 14):")
print("col_offset | kh_kw_idx | kh | kw | byte_in_word | tail_nbyte")
for kh in range(6):
    for kw in range(6):
        col_offset = (kh * 6 + kw) * 3
        byte_in_word = col_offset % 16
        write_end = byte_in_word + 3
        if write_end > 16:
            tail_nbyte = write_end - 16
            first_nbyte = 16 - byte_in_word
            print(f"  {col_offset:3d}       | {kh*6+kw:2d}        | {kh} | {kw} | {byte_in_word:2d}           | {tail_nbyte}")
            # Where does the tail write go?
            # gb_addrb = write_byte_addr_aligned + WORD_BYTES
            # write_byte_addr_aligned = out_byte_addr & ~15
            # For the tail, write_mask covers bytes 0..(tail_nbyte-1) in the NEXT word
            # These bytes correspond to row offsets (col_offset + first_nbyte) .. (col_offset + first_nbyte + tail_nbyte - 1)
            for b in range(tail_nbyte):
                abs_byte = col_offset + first_nbyte + b
                print(f"    → tail writes to row byte {abs_byte}")

print()
print("Now check: do these tail writes ever land in the padding area (bytes 108-127)?")
print("Checking last valid positions near byte 108:")
for kh in range(6):
    for kw in range(6):
        col_offset = (kh * 6 + kw) * 3
        byte_in_word = col_offset % 16
        write_end = byte_in_word + 3
        if write_end > 16:
            first_nbyte = 16 - byte_in_word
            tail_end_byte = col_offset + 3
            if tail_end_byte > 107:
                print(f"  kh={kh},kw={kw}: col_offset={col_offset}, writes bytes {col_offset}..{col_offset+2}, tail covers {col_offset+first_nbyte}..{col_offset+2}")

print()
# Check: the error at byte 126-127 - what word does that correspond to?
# Within each output row, byte 126 is in word [112..127] (word_addr = row_base + 112, aligned to 16)
# Who writes to this word? 
# The last valid write is at col_offset = 35*3 = 105, writes bytes 105,106,107
# byte_in_word = 105 % 16 = 9, write_end = 9 + 3 = 12 ≤ 16 → no tail
# So bytes 108-127 should NEVER be written by im2col. But we see data there!
print("bytes 108-127 should NEVER be written by im2col (kH*kW*CH=108 is the valid data limit)")
print("But OBUF might have RESIDUAL data from the preload/previous operations.")
print()
print("CONCLUSION: The 'spurious writes' at byte 126-127 are actually RESIDUAL DATA")
print("in the output region that was never cleared. The test should zero the output")
print("region before running im2col, or only check bytes 0-107 per row.")
print()

# Now for the BIT FLIP errors in valid positions:
# Let me check if any of the errored positions are in tail-write territory
print("Checking if errored byte positions coincide with write-tail positions:")
errored_positions = [5, 6, 10, 38, 43, 62, 63, 69, 70, 74, 75, 94, 95, 101, 102, 106, 107]
tail_positions = set()
for kh in range(6):
    for kw in range(6):
        col_offset = (kh * 6 + kw) * 3
        byte_in_word = col_offset % 16
        write_end = byte_in_word + 3
        if write_end > 16:
            first_nbyte = 16 - byte_in_word
            for b in range(write_end - 16):
                tail_positions.add(col_offset + first_nbyte + b)
            # Also mark the first-write bytes for debugging
            # Hmm, rather mark which bytes are written in FIRST write (non-tail)
            # and which are tail
print(f"Tail-write byte positions within row: {sorted(tail_positions)}")
print(f"Errored positions: {sorted(errored_positions)}")
overlap = sorted(set(errored_positions) & tail_positions)
print(f"Overlap: {overlap}")
