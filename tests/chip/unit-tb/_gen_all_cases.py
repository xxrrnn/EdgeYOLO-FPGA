import sys; sys.path.insert(0,'.')
sys.path.insert(0,'../../../rtl/tb/lite_bd/module_tb')
sys.path.insert(0,'../../../tools')
from gen_data import generate_case
from golden_module_tb import MODULE_CASES

cases = [c for c in MODULE_CASES['conv_pipeline']
         if c['name'].startswith('pipe_model') and 'full' not in c['name']]
print(f'Total cases: {len(cases)}')
errors = []
for c in cases:
    try:
        run_dir = generate_case('conv_pipeline', c['name'])
        name = c['name']
        print(f'  OK  {name}')
    except Exception as e:
        name = c['name']
        print(f'  ERR {name}: {e}')
        errors.append((name, str(e)))
print(f'\nErrors: {len(errors)}/{len(cases)}')
for n, e in errors:
    print(f'  {n}: {e}')
