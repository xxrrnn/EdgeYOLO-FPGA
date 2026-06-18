"""读取ONNX中各层的activation scale"""
import onnx, numpy as np
model = onnx.load('model/yolov5n/best.quant.onnx')

# The ONNX only has Constant + Identity nodes
# Activation scales are exposed as graph outputs like "a__model.0.act__scale"
# Find the Constant node that feeds each output

# Build output->producer map
output_producer = {}
for node in model.graph.node:
    for o in node.output:
        output_producer[o] = node

act_scales = {}
for out in model.graph.output:
    if 'act__scale' in out.name:
        layer = out.name.replace('a__', '').replace('.act__scale', '')
        # trace back to Constant
        if out.name in output_producer:
            node = output_producer[out.name]
            if node.op_type == 'Constant':
                for attr in node.attribute:
                    if attr.name == 'value':
                        t = attr.t
                        if t.data_type == 1:  # FLOAT
                            val = np.frombuffer(t.raw_data, dtype=np.float32)
                            act_scales[layer] = float(val[0])
            elif node.op_type == 'Identity':
                # trace one more level
                src = node.input[0]
                if src in output_producer:
                    src_node = output_producer[src]
                    if src_node.op_type == 'Constant':
                        for attr in src_node.attribute:
                            if attr.name == 'value':
                                t = attr.t
                                if t.data_type == 1:
                                    val = np.frombuffer(t.raw_data, dtype=np.float32)
                                    act_scales[layer] = float(val[0])

print(f"Total activation scales found: {len(act_scales)}")
print(f"Unique values: {len(set(act_scales.values()))}")
if act_scales:
    vals = list(act_scales.values())
    print(f"Range: [{min(vals):.8f}, {max(vals):.8f}]")
    print()
    for k, v in sorted(act_scales.items()):
        print(f"  {k:40s} act_scale={v:.8f}")
