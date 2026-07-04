"""Dump the full patched instruction stream as human-readable ops."""
import struct
from pathlib import Path
from hbm_flow import patch_inst_for_hbm, build_hbm_input_cdma, build_hbm_output_drain
from xdma_win import parse_inst_words, HBM_BASE, HBM_OFF_OUTPUT

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")

data = patch_inst_for_hbm(run_dir, drain_output=True)
words = [struct.unpack("<I", data[i:i+4])[0] for i in range(0, len(data), 4)]

OP_NAMES = {0x0: "NOP/UNK", 0x1: "CDMA_COPY", 0x2: "UNK_2", 0x3: "WAIT_CDMA",
            0x4: "UNK_4", 0x5: "UNK_5", 0x6: "UNK_6", 0x7: "UNK_7",
            0x8: "MATMUL", 0x9: "UNK_9", 0xA: "UNK_A", 0xB: "UNK_B",
            0xC: "UNK_C", 0xD: "UNK_D", 0xE: "UNK_E", 0xF: "END"}

# Also read raw inst.hex to find the boundary
raw_words = parse_inst_words(run_dir / "inst.hex")
# Strip END
while raw_words and (raw_words[-1] >> 28) & 0xF == 0xF:
    raw_words.pop()
# input cdma
in_cdma = build_hbm_input_cdma(run_dir)

boundary_in = len(in_cdma)
boundary_core = boundary_in + len(raw_words)

print(f"Input CDMA:  words [{0}:{boundary_in})")
print(f"Core inst:   words [{boundary_in}:{boundary_core})")
print(f"Drain CDMA:  words [{boundary_core}:...)")
print()

i = 0
while i < len(words):
    w = words[i]
    op = (w >> 28) & 0xF
    name = OP_NAMES.get(op, f"OP_{op:X}")
    length = w & 0xFFFFFF
    section = ""
    if i < boundary_in:
        section = "[IN-CDMA]"
    elif i < boundary_core:
        section = "[CORE   ]"
    else:
        section = "[DRAIN  ]"

    print(f"  [{i:4d}] {section} 0x{w:08x}  OP={name}  len={length}")
    if op == 0x1:  # CDMA_COPY: 7 words total (header + 5 + WAIT)
        src = (words[i+1] << 32) | words[i+2]
        dst = (words[i+3] << 32) | words[i+4]
        nb = words[i+5]
        print(f"          src=0x{src:016x} dst=0x{dst:016x} n={nb}")
        i += 6  # skip to WAIT_CDMA
    elif op == 0xF:
        break
    else:
        i += 1
