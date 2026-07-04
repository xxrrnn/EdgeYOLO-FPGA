"""Verify if im2col errors are caused by reading from wrong input position.
Compare got values against adjacent input pixels."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin
import struct

runner = ChipRunnerWin(verbose=False)
im_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\im2col_im2col_6x6_s2_c3_qint8")

# Load source data (what was preloaded into VPU_BUF at address 0)
src_data = hex_to_bin(im_dir / "src0.hex")
print(f"Source data size: {len(src_data)} bytes")

# Parameters
CH_IN = 3
H, W = 12, 12
STRIDE_H, STRIDE_W = 2, 2
PAD_H, PAD_W = 2, 2
OH, OW = 6, 6
KH, KW = 6, 6
IN_COL_STRIDE = 16  # ceil(3/16)*16 = 16 bytes per pixel
ROW_STRIDE = 128

# Source addressing: pixel (ih,iw) data at offset (ih*W+iw)*IN_COL_STRIDE, CH_IN bytes
def get_src_pixel(ih, iw):
    """Get CH_IN bytes of source data for pixel (ih,iw)."""
    if ih < 0 or ih >= H or iw < 0 or iw >= W:
        return bytes(CH_IN)  # zero padding
    offset = (ih * W + iw) * IN_COL_STRIDE
    return src_data[offset:offset+CH_IN]

# Expected output for position (oh, ow, kh, kw, c):
def get_expected_byte(oh, ow, kh, kw, c):
    ih = oh * STRIDE_H - PAD_H + kh
    iw = ow * STRIDE_W - PAD_W + kw
    pixel = get_src_pixel(ih, iw)
    return pixel[c]

# Now check the "got" values against neighbors
errors = [
    # (pixel_oh, pixel_ow, byte_in_row, kh, kw, c, exp, got)
    (3, 3, 62, 3, 2, 2, 0x28, 0xb8),
    (3, 3, 63, 3, 3, 0, 0x0c, 0x0d),
    (3, 3, 69, 3, 5, 0, 0xef, 0xe7),
    (3, 3, 74, 4, 0, 2, 0x39, 0xb9),
    (3, 4, 6, 0, 2, 0, 0x20, 0x00),
    (3, 4, 10, 0, 3, 1, 0x75, 0x71),
    (3, 4, 94, 5, 1, 1, 0xe2, 0x62),
    (3, 4, 106, 5, 5, 1, 0xcd, 0x4d),
    (4, 1, 5, 0, 1, 2, 0xc8, 0xc0),
    (4, 1, 6, 0, 2, 0, 0xf3, 0xd3),
    (4, 1, 10, 0, 3, 1, 0xc4, 0x40),
    (4, 1, 94, 5, 1, 1, 0xe7, 0x67),
    (4, 1, 95, 5, 1, 2, 0x16, 0x17),
    (4, 1, 102, 5, 4, 0, 0x04, 0x24),
    (4, 1, 106, 5, 5, 1, 0xfd, 0x7d),
    (4, 1, 107, 5, 5, 2, 0x91, 0x11),
]

print("Checking if 'got' matches a neighbor pixel (read from wrong address):")
print()
for oh, ow, _, kh, kw, c, exp_val, got_val in errors:
    ih = oh * STRIDE_H - PAD_H + kh
    iw = ow * STRIDE_W - PAD_W + kw
    # Check neighbors
    found_match = False
    for dih in range(-2, 3):
        for diw in range(-2, 3):
            if dih == 0 and diw == 0:
                continue
            nih, niw = ih + dih, iw + diw
            if 0 <= nih < H and 0 <= niw < W:
                neighbor_val = get_src_pixel(nih, niw)[c]
                if neighbor_val == got_val:
                    print(f"  pix({oh},{ow}) kh={kh},kw={kw},c={c}: "
                          f"got=0x{got_val:02x} MATCHES neighbor ({nih},{niw}) offset=({dih:+d},{diw:+d})")
                    found_match = True
    if not found_match:
        # Check if it's a byte from a different channel at same position
        for dc in range(-2, 3):
            if dc == 0:
                continue
            nc = c + dc
            if 0 <= nc < CH_IN:
                same_pos_val = get_src_pixel(ih, iw)[nc]
                if same_pos_val == got_val:
                    print(f"  pix({oh},{ow}) kh={kh},kw={kw},c={c}: "
                          f"got=0x{got_val:02x} MATCHES same pixel c={nc} (channel leak)")
                    found_match = True
        if not found_match:
            xor = exp_val ^ got_val
            print(f"  pix({oh},{ow}) kh={kh},kw={kw},c={c}: "
                  f"exp=0x{exp_val:02x} got=0x{got_val:02x} XOR=0x{xor:02x} (no neighbor match)")
