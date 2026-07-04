# EdgeYOLO-FPGA-lite compile output — yolov5n

- mode: `int8`
- input_shape: [1, 3, 320, 320]
- output_shape: [1, 6300, 8]
- compiled: {'schema_version': '1', 'mode': 'int8', 'num_conv_layers_compiled': 2, 'num_conv_layers_total': 60, 'stop_reason': 'max_layers reached'}

## Address map
- `vpu_buf_base` = 0x102000000
- `obuf_base` = 0x102000000
- `vpu_buf_size` = 0x800000
- `ibuf_base` = 0x100000000
- `ibuf_size` = 0x80000
- `wb_base` = 0x103000000
- `wb_size` = 0x8000
- `hbm_base` = 0x0
- `tile_obuf_base` = 0x101000000

## Per-layer memory plan
| layer | in_off | out_off | im2col_off | input HxW | output HxW | acc_depth | tiles |
|---|---|---|---|---|---|---|---|
| model.0.conv | 0x00000000 | 0x00400000 | 0x00400000 | 320x320 | 160x160 | 2 | 1 |
| model.1.conv | 0x00400000 | 0x00000000 | 0x00000000 | 160x160 | 80x80 | 3 | 2 |

## Unsupported nodes (fail-loud)
- model.24.Slice: Slice: no rule for Slice
- model.24.Slice_1: Slice: no rule for Slice
- model.24.Mul: Mul: no rule for Mul
- model.24.Mul_1: Mul: no rule for Mul
- model.24.Mul_2: Mul: no rule for Mul
- model.24.Mul_3: Mul: no rule for Mul
- model.24.Mul_4: Mul: no rule for Mul
- model.24.Slice_2: Slice: no rule for Slice
- model.24.Slice_3: Slice: no rule for Slice
- model.24.Mul_5: Mul: no rule for Mul
- model.24.Slice_4: Slice: no rule for Slice
- model.24.Mul_6: Mul: no rule for Mul
- model.24.Slice_5: Slice: no rule for Slice
- model.24.Slice_6: Slice: no rule for Slice
- model.24.Slice_7: Slice: no rule for Slice
- model.24.Mul_7: Mul: no rule for Mul
- model.24.Mul_8: Mul: no rule for Mul
- model.24.Mul_9: Mul: no rule for Mul
- model.24.Mul_10: Mul: no rule for Mul
- model.24.Mul_11: Mul: no rule for Mul
- model.24.Slice_8: Slice: no rule for Slice
- model.24.Slice_9: Slice: no rule for Slice
- model.24.Mul_12: Mul: no rule for Mul
- model.24.Slice_10: Slice: no rule for Slice
- model.24.Mul_13: Mul: no rule for Mul
- model.24.Slice_11: Slice: no rule for Slice
- model.24.Slice_12: Slice: no rule for Slice
- model.24.Slice_13: Slice: no rule for Slice
- model.24.Mul_14: Mul: no rule for Mul
- model.24.Mul_15: Mul: no rule for Mul
- model.24.Mul_16: Mul: no rule for Mul
- model.24.Mul_17: Mul: no rule for Mul
- model.24.Mul_18: Mul: no rule for Mul
- model.24.Slice_14: Slice: no rule for Slice
- model.24.Slice_15: Slice: no rule for Slice
- model.24.Mul_19: Mul: no rule for Mul
- model.24.Slice_16: Slice: no rule for Slice
- model.24.Mul_20: Mul: no rule for Mul
- model.24.Slice_17: Slice: no rule for Slice
- model.0.conv: Conv: IBUF activation overflow (3276800 bytes needed, 507904 free).  Requires OH-tiling (not yet implemented).
- ...1 more
