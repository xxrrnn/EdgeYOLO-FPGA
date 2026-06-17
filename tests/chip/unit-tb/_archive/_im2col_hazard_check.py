"""Check if im2col READ-after-WRITE hazard exists:
does any read hit a URAM word that was recently written by a previous im2col iteration?"""

CH_IN = 3
H, W = 12, 12
STRIDE_H, STRIDE_W = 2, 2
PAD_H, PAD_W = 2, 2
OH, OW = 6, 6
KH, KW = 6, 6
IN_COL_STRIDE = 16
ROW_STRIDE = 128
SRC_ADDR = 0
DST_ADDR = 2304
WORD_BYTES = 16  # 128-bit URAM word

def in_addr(oh, ow, kh, kw):
    """Read address for input pixel (returns word-aligned byte addr)."""
    ih = oh * STRIDE_H - PAD_H + kh
    iw = ow * STRIDE_W - PAD_W + kw
    if ih < 0 or ih >= H or iw < 0 or iw >= W:
        return None  # padding, no read
    byte_addr = SRC_ADDR + (ih * W + iw) * IN_COL_STRIDE
    return byte_addr  # word = byte_addr // 16

def out_addr(oh, ow, kh, kw):
    """Write address for output position (returns byte addr)."""
    row_offset = (oh * OW + ow) * ROW_STRIDE
    col_offset = (kh * KW + kw) * CH_IN
    return DST_ADDR + row_offset + col_offset

# Check: source region [0, 2303] vs dest region [2304, 6911]
# They DON'T overlap! So im2col reads will never hit its own writes!
print("Source region: [0, 2303]")
print("Dest region:   [2304, 6911]")
print("NO OVERLAP - im2col reads from src will never hit dst writes.")
print()
print("Therefore the bit-flip errors are NOT caused by URAM read-after-write hazard")
print("within im2col itself.")
print()

# But wait - could it be that the PRELOADED source data is corrupted?
# Let's read back the VPU_BUF source region AFTER im2col completes and compare with src0.hex
print("NEXT STEP: Read back VPU_BUF source region after im2col to check if")
print("the source data was corrupted during im2col execution.")
print("(im2col writes to dst might have corrupted src via URAM address decode bug)")
print()

# Check if any DESTINATION write word-address accidentally maps to a SOURCE word-address
# This would happen if there's an address decode error in the URAM
# URAM address = byte_addr >> 4 (for 16B words)
src_words = set(range(0, 2304 // WORD_BYTES))  # words 0..143
dst_words = set()
for oh in range(OH):
    for ow in range(OW):
        for kh in range(KH):
            for kw in range(KW):
                addr = out_addr(oh, ow, kh, kw)
                word = addr // WORD_BYTES
                dst_words.add(word)
                # Also check tail writes
                byte_in_word = addr % WORD_BYTES
                if byte_in_word + CH_IN > WORD_BYTES:
                    dst_words.add(word + 1)

print(f"Source word range: 0..{max(src_words)}")
print(f"Dest word range: {min(dst_words)}..{max(dst_words)}")
overlap = src_words & dst_words
print(f"Word overlap: {len(overlap)} words")
if overlap:
    print(f"  OVERLAP DETECTED! Words: {sorted(overlap)[:10]}...")
print()

# Now the critical insight: errors are NOT address-based (no neighbor match, no overlap).
# The bit-flip pattern (mostly bit 5 and bit 7) suggests:
# - Hardware signal integrity issue
# - OR: im2col reads VPU_BUF while CDMA is also accessing it
# - OR: The obuf_rd_valid signal has race conditions (pipeline flush issue)

# Let me check: in the test flow, does CDMA run concurrently with im2col?
# In preload mode: data is preloaded via CDMA, then im2col runs alone.
# So no concurrent access. This means it's a pure im2col internal issue.

# The most likely cause: the im2col unit reads its OWN OUTPUT as input for later pixels.
# Wait - we showed src and dst don't overlap! Unless... the im2col writes CORRUPT
# the read pipeline of the URAM. Let me check the obuf architecture.

# Actually, here's another theory: the OBUF has only ONE port that im2col uses.
# If im2col writes to address X in cycle N, and reads from address Y in cycle N+1,
# and the URAM has NBPIPE stages, the write at X might not yet be visible.
# BUT that only matters if a later read hits the same address as a recent write!
# Since src and dst don't overlap, this shouldn't matter.

# UNLESS: The URAM uses a SINGLE port in TDP mode where read and write share the port,
# and a write to one address CORRUPTS the read pipeline state for a subsequent read
# from a DIFFERENT address.

# This is a known URAM TDP issue in Ultrascale+:
# If port B writes in cycle N, then port B reads in cycle N+1..N+NBPIPE,
# the write-to-read turnaround can corrupt data if the pipeline isn't properly managed.

print("HYPOTHESIS: URAM TDP write-to-read turnaround corruption.")
print("im2col alternates write→read→write→read on the same port (port B).")
print("If URAM has N-stage read pipeline, a write followed by an immediate read")
print("on the SAME port (even to different addresses) can corrupt the read data")
print("if the pipeline registers aren't properly flushed between write and read.")
print()
print("This would explain:")
print("  - Mostly single-bit flips (not random data)")
print("  - Concentrated in middle/late output pixels (after many write→read cycles)")
print("  - Deterministic error positions (same pipeline timing every run)")
