"""Detailed im2col byte-level mismatch analysis: identify which kh/kw position is wrong."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin

runner = ChipRunnerWin(verbose=False)
im_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\im2col_im2col_6x6_s2_c3_qint8")

r = runner.run_case(im_dir, staging="preload")[0]
exp_raw = hex_to_bin(im_dir / "expected.hex")[:256*16]

# Parameters
CH_IN = 3
KH, KW = 6, 6
STRIDE_H, STRIDE_W = 2, 2
PAD_H, PAD_W = 2, 2
H, W = 12, 12
OH, OW = 6, 6
ELEM_BYTES = 1

# row_stride in bytes: ceil(kH*kW*CH_IN / 64)*64 = ceil(108/64)*64 = 128
ROW_STRIDE = 128
# Each word = 16 bytes

mismatches = r.get("mismatches", [])
print(f"Total mismatches: {len(mismatches)}")
print()

for m in mismatches:
    w = m["word"]
    word_byte_offset = w * 16  # byte offset within im2col output
    # Which output pixel?
    pixel = word_byte_offset // ROW_STRIDE
    oh = pixel // OW
    ow = pixel % OW
    # Byte position within this pixel's row
    byte_in_row = word_byte_offset % ROW_STRIDE

    e = bytes.fromhex(m["expected"])
    g = bytes.fromhex(m["got"])
    
    print(f"word {w:3d} | pixel({oh},{ow}) byte_in_row={byte_in_row}..{byte_in_row+15}")
    
    for b in range(16):
        if e[b] != g[b]:
            abs_byte = byte_in_row + b
            # Which (kh, kw) does this byte belong to?
            # Output layout: each (kh,kw) position occupies CH_IN*ELEM_BYTES=3 bytes
            # packed contiguously within the row
            kh_kw_idx = abs_byte // (CH_IN * ELEM_BYTES)
            kh = kh_kw_idx // KW
            kw = kh_kw_idx % KW
            c_idx = abs_byte % (CH_IN * ELEM_BYTES)
            
            # What input pixel does this correspond to?
            ih = oh * STRIDE_H - PAD_H + kh
            iw = ow * STRIDE_W - PAD_W + kw
            in_bounds = (0 <= ih < H) and (0 <= iw < W)
            
            print(f"  byte {abs_byte:3d}: kh={kh},kw={kw},c={c_idx} → ih={ih:+d},iw={iw:+d} "
                  f"{'IN' if in_bounds else 'PAD'} | exp=0x{e[b]:02x} got=0x{g[b]:02x}")
    print()
