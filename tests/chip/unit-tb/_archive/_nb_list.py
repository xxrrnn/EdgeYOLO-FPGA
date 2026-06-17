import json
nb=json.load(open('run_unit_test.ipynb'))
for i,c in enumerate(nb['cells']):
    src = ''.join(c['source'])[:80].replace('\n',' ')
    ct = c['cell_type']
    print(f"{i:2d} {ct:8s} | {src}")
