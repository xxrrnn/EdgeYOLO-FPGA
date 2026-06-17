"""Analyze im2col bit-error pattern to identify RTL bug."""
# From the byte-level analysis, I notice a clear pattern in the bit differences.
# Let me look at the raw bit differences:

errors = [
    # (byte_pos, exp, got, kh, kw, c, ih, iw, in_bounds)
    (126, 0x00, 0x10, 7, 0, 0, 11, 2, True),   # pix(3,2)
    (127, 0x00, 0x01, 7, 0, 1, 11, 2, True),   # pix(3,2)
    (62,  0x28, 0xb8, 3, 2, 2, 7, 6, True),    # pix(3,3)
    (63,  0x0c, 0x0d, 3, 3, 0, 7, 7, True),    # pix(3,3)
    (69,  0xef, 0xe7, 3, 5, 0, 7, 9, True),    # pix(3,3)
    (74,  0x39, 0xb9, 4, 0, 2, 8, 4, True),    # pix(3,3)
    (6,   0x20, 0x00, 0, 2, 0, 4, 8, True),    # pix(3,4)
    (10,  0x75, 0x71, 0, 3, 1, 4, 9, True),    # pix(3,4)
    (94,  0xe2, 0x62, 5, 1, 1, 9, 7, True),    # pix(3,4)
    (106, 0xcd, 0x4d, 5, 5, 1, 9, 11, True),   # pix(3,4)
    (38,  0xdd, 0xfd, 2, 0, 2, 6, 8, True),    # pix(3,5)
    (43,  0x42, 0xc2, 2, 2, 1, 6, 10, True),   # pix(3,5)
    (126, 0x00, 0x10, 7, 0, 0, 11, 8, True),   # pix(3,5)
    (69,  0xad, 0xa5, 3, 5, 0, 9, 3, True),    # pix(4,0)
    (5,   0xc8, 0xc0, 0, 1, 2, 6, 1, True),    # pix(4,1)
    (6,   0xf3, 0xd3, 0, 2, 0, 6, 2, True),    # pix(4,1)
    (10,  0xc4, 0x40, 0, 3, 1, 6, 3, True),    # pix(4,1)
    (94,  0xe7, 0x67, 5, 1, 1, 11, 1, True),   # pix(4,1)
    (95,  0x16, 0x17, 5, 1, 2, 11, 1, True),   # pix(4,1)
    (102, 0x04, 0x24, 5, 4, 0, 11, 4, True),   # pix(4,1)
    (106, 0xfd, 0x7d, 5, 5, 1, 11, 5, True),   # pix(4,1)
    (107, 0x91, 0x11, 5, 5, 2, 11, 5, True),   # pix(4,1)
    (126, 0x00, 0x90, 7, 0, 0, 13, 2, False),  # pix(4,2) PAD
    (127, 0x00, 0x01, 7, 0, 1, 13, 2, False),  # pix(4,2) PAD
    (69,  0xd1, 0xd9, 3, 5, 0, 9, 9, True),    # pix(4,3)
    (70,  0x53, 0x73, 3, 5, 1, 9, 9, True),    # pix(4,3)
    (74,  0xcf, 0xcb, 4, 0, 2, 10, 4, True),   # pix(4,3)
    (75,  0xba, 0x3a, 4, 1, 0, 10, 5, True),   # pix(4,3)
    (5,   0x4f, 0x47, 0, 1, 2, 6, 7, True),    # pix(4,4)
    (10,  0x9b, 0x1b, 0, 3, 1, 6, 9, True),    # pix(4,4)
    (94,  0xa3, 0x23, 5, 1, 1, 11, 7, True),   # pix(4,4)
    (95,  0xdc, 0xdd, 5, 1, 2, 11, 7, True),   # pix(4,4)
    (102, 0xb7, 0x97, 5, 4, 0, 11, 10, True),  # pix(4,4)
    (37,  0x98, 0x90, 2, 0, 1, 8, 8, True),    # pix(4,5)
    (38,  0xdc, 0xfc, 2, 0, 2, 8, 8, True),    # pix(4,5)
    (70,  0xbf, 0x9f, 3, 5, 1, 11, 3, True),   # pix(5,0)
    (74,  0x00, 0x04, 4, 0, 2, 12, -2, False), # pix(5,0) PAD
    (75,  0x00, 0x80, 4, 1, 0, 12, -1, False), # pix(5,0) PAD
    (6,   0x74, 0x54, 0, 2, 0, 8, 2, True),    # pix(5,1)
    (101, 0x00, 0x08, 5, 3, 2, 13, 3, False),  # pix(5,1) PAD
    (102, 0x00, 0x20, 5, 4, 0, 13, 4, False),  # pix(5,1) PAD
]

print("=== Bit-level XOR analysis ===")
print()

# See if there's a systematic single-bit flip pattern
from collections import Counter
bit_flips = Counter()  # which bit within a byte flips

for pos, exp, got, kh, kw, c, ih, iw, inb in errors:
    xor = exp ^ got
    for bit in range(8):
        if xor & (1 << bit):
            bit_flips[bit] += 1

print("Bit flip frequency (bit0=LSB):")
for bit in range(8):
    print(f"  bit {bit}: {bit_flips[bit]} flips")
print()

# Check if this looks like address offset errors (reading from wrong source position)
# Group by kh to see if specific kernel rows are systematically wrong
from collections import defaultdict
kh_errors = defaultdict(int)
for pos, exp, got, kh, kw, c, ih, iw, inb in errors:
    kh_errors[kh] += 1

print("Errors by kh (kernel row):")
for kh in sorted(kh_errors):
    print(f"  kh={kh}: {kh_errors[kh]} byte errors")
print()

# Look at spurious writes to padding regions (exp=0, got!=0)
print("Padding violations (should be 0 but got data):")
for pos, exp, got, kh, kw, c, ih, iw, inb in errors:
    if not inb:
        print(f"  kh={kh},kw={kw},c={c} ih={ih:+d},iw={iw:+d} got=0x{got:02x}")
print()

# Check if certain byte_in_row offsets repeat
pos_errors = defaultdict(int)
for pos, exp, got, kh, kw, c, ih, iw, inb in errors:
    pos_errors[pos] += 1

print("Recurring byte positions within row:")
for pos in sorted(pos_errors):
    if pos_errors[pos] > 1:
        kh_kw_idx = pos // 3
        kh = kh_kw_idx // 6
        kw = kh_kw_idx % 6
        c = pos % 3
        print(f"  byte {pos:3d} (kh={kh},kw={kw},c={c}): {pos_errors[pos]} occurrences")
print()

# Analyze bit7 specifically (most common)
print("Bit7 flips analysis (most affected bit):")
for pos, exp, got, kh, kw, c, ih, iw, inb in errors:
    xor = exp ^ got
    if xor & 0x80:
        direction = "0→1" if got & 0x80 else "1→0"
        print(f"  byte {pos:3d} kh={kh},kw={kw},c={c} "
              f"ih={ih:+d},iw={iw:+d} {'PAD' if not inb else 'IN '} "
              f"exp=0x{exp:02x} got=0x{got:02x} ({direction})")
