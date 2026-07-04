"""INT16 hardware verification on FPGA."""
import sys, numpy as np
from pathlib import Path
sys.path.insert(0, r'e:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\rtl\tb\lite_bd\module_tb')
sys.path.insert(0, r'e:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb')
from golden_module_tb import make_conv_pipeline_case, load_network, write_inst, write_hex, bytes_to_128_words
from xdma_win import ChipRunnerWin

net = load_network(r'e:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\model\yolov5n\parsed\network.json')
runner = ChipRunnerWin(verbose=False)

int16_cases = [
    {'name': 'int16_tiny_1x1',      'layer': 'model.2.cv1.conv',  'in_hw': (2, 2),  'int16': True},
    {'name': 'int16_conv3_c32_c64', 'layer': 'model.3.conv',      'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_conv1_c128',    'layer': 'model.6.cv1.conv',  'in_hw': (4, 4),  'int16': True},
]
rng = np.random.default_rng(42)

results = []
for spec in int16_cases:
    name = spec['name']
    run_dir = Path(f'./runs/int16_verify/{name}')
    run_dir.mkdir(parents=True, exist_ok=True)
    md = make_conv_pipeline_case(str(run_dir), net, spec, rng)
    write_inst(str(run_dir / 'inst.hex'), md['fast_inst'])
    (run_dir / 'checks.txt').write_text(f'{name} expected.hex {md["dst"]:06x} {md["words"]} 0\n')
    wb_data = md.get('wb', b'')
    if wb_data:
        write_hex(str(run_dir / 'wb_init.hex'), bytes_to_128_words(wb_data))
        pf = run_dir / 'preload.txt'
        txt = pf.read_text() if pf.exists() else ''
        if 'wb_init.hex' not in txt:
            with open(pf, 'a') as f:
                f.write(f'wb_init.hex {0x1030_0000_0:016x}\n')

    res = runner.run_case(run_dir, staging='hbm')
    ok = all(r.get('pass', False) for r in res)
    passed = sum(r.get('passed', 0) for r in res)
    total = sum(r.get('total_words', 0) for r in res)
    status = 'PASS' if ok else f'FAIL({passed}/{total})'
    results.append((name, status))
    print(f'  [{status}] {name}')

n_pass = sum(1 for _, s in results if s == 'PASS')
print(f'\nINT16 hardware verification: {n_pass}/{len(results)} passed')
