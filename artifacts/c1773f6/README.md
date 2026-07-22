# c1773f6 Frozen FPGA Artifacts

These six directories are the exact compiler outputs used for the stable FPGA
acceptance run. `run.py --one-shot` selects them by default. Do not edit them in
place; use `--one-shot-build-dir output/recompiled/<name>` when recompiling.

| Directory | Workload | Parsed model |
| --- | --- | --- |
| `yolo_ir_int8` | Infrared YOLO INT8 | `model/yolov5n/parsed` |
| `yolo_ir_int16_widened` | Infrared YOLO INT16-widened | `model/yolov5n/parsed_int16_widened` |
| `yolo_coco_int8` | COCO YOLO INT8 | `model/yolov5n_coco50k_qat/parsed_int8` |
| `yolo_coco_int16_widened` | COCO YOLO INT16-widened | `model/yolov5n_coco50k_qat/parsed_int16_widened` |
| `resnet18_int8` | ResNet18 VAI INT8 | `model/resnet18/parsed_vai` |
| `resnet18_int16_widened` | ResNet18 INT16-widened | `model/resnet18/parsed_vai_int16_widened` |

Each bundle contains `plan.json`, `program.bin`, `weights.bin`, `wb.bin`, layout
metadata, and any required segmented-program files. `reference_results/`
contains the result image, numeric JSON, timing JSON, and final FPGA feature from
the acceptance run.

The matching root `chip.bit` SHA256 is
`314d65d3711d464d60f8f5d158d270275d9cc2203ddbaa3b41c7e6a64823764d`.
Key binary hashes are listed in `MANIFEST.md`.
