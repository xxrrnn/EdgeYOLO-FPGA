"""
分析 acc=1, out_ch=in_ch=64 时 FAIL 的具体 pattern
"""
import sys, numpy as np
sys.path.insert(0,'.')
sys.path.insert(0,'../../../rtl/tb/lite_bd/module_tb')
from golden_module_tb import (make_conv_pipeline_case, load_network, conv_meta,
                               write_inst, bytes_to_128_words, write_hex)
from xdma_win import ChipRunnerWin, VPU_BUF_BASE
from pathlib import Path

runner = ChipRunnerWin(verbose=False)
net = load_network('../../../model/yolov5n/parsed/network.json')
H, W = 4, 4
feat_in = np.random.default_rng(42).integers(-128,128,(H,W,64),dtype=np.int16).astype(np.int8)
meta = conv_meta(net, 'model.4.cv3.conv')  # in_ch=64 out_ch=64 acc=1

run_dir = Path('./runs/debug_1x1')
run_dir.mkdir(parents=True, exist_ok=True)
spec = {'name':'debug_1x1', 'layer':'model.4.cv3.conv', 'in_hw':(H,W)}
md = make_conv_pipeline_case(str(run_dir), net, spec, np.random.default_rng(0), feat=feat_in)
write_inst(str(run_dir/'inst.hex'), md['fast_inst'])
(run_dir/'checks.txt').write_text(f"debug_1x1 expected.hex {md['dst']:06x} {md['words']} 0\n")
wb = md.get('wb', b'')
if wb:
    write_hex(str(run_dir/'wb_init.hex'), bytes_to_128_words(wb))
    pf = run_dir / 'preload.txt'
    txt = pf.read_text() if pf.exists() else ''
    if 'wb_init.hex' not in txt:
        with open(pf,'a') as f:
            f.write(f"wb_init.hex {0x1030_0000_0:016x}\n")

results = runner.run_case(run_dir, staging='hbm')
r = results[0]
print(f"Result: {r['pass']}  {r['passed']}/{r['total_words']}")
print(f"first_mismatch: {r['first_mismatch']}")
if r.get('mismatches'):
    print(f"\n所有不匹配 (前 8 个):")
    for i, mm in enumerate(r['mismatches'][:8]):
        print(f"  word {mm['word_idx']:4d}: exp={mm['expected'][:16]}  got={mm['got'][:16]}")

# 看哪些 word 是 PASS（哪些像素正确）
oh = (H + 2*meta.pad_h0 - meta.kh) // meta.stride_h + 1
ow = (W + 2*meta.pad_w0 - meta.kw) // meta.stride_w + 1
eff_ch = meta.num_tiles * 16  # 64
print(f"\noh={oh} ow={ow} eff_ch={eff_ch} words={md['words']}")
print(f"words_per_pixel = {eff_ch//16} (eff_ch/16)")
# If 1/4 words pass, which ones?
# words are organized as: pixel0_ch0..15, pixel0_ch16..31, pixel0_ch32..47, pixel0_ch48..63, pixel1_ch0..15, ...
# so words_per_pixel = 4
