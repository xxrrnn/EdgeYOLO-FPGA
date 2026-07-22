# EdgeYOLO-FPGA-lite compile output — resnet18

- mode: `int8`
- input_shape: [1, 3, 224, 224]
- output_shape: [1, 1000]
- compiled: {'schema_version': '1', 'mode': 'int8', 'num_conv_layers_compiled': 20, 'num_conv_layers_total': 20, 'stop_reason': 'resnet18 full schedule', 'weights_loaded_from_hbm': True, 'program_segments': 1}

## Address map
- `hbm_base` = 0x0
- `ibuf_base` = 0x100000000
- `ibuf_size` = 0x80000
- `tile_obuf_base` = 0x101000000
- `tile_obuf_size` = 0x40000
- `vpu_buf_base` = 0x102000000
- `vpu_buf_size` = 0x800000
- `obuf_base` = 0x102000000
- `obuf_size` = 0x800000
- `wb_base` = 0x103000000
- `wb_size` = 0x8000
- `inst_base` = 0x104000000
- `inst_size` = 0x20000
- `regs_base` = 0x105000000
- `regs_size` = 0x1000

## Per-layer memory plan
| layer | in_off | out_off | im2col_off | input HxW | output HxW | acc_depth | tiles |
|---|---|---|---|---|---|---|---|
| conv1.Conv | 0x00000000 | 0x001a0000 | 0x004c0000 | 224x224 | 112x112 | 3 | 4 |
| layer1.0.conv1.Conv | 0x00000000 | 0x001a0000 | 0x004c0000 | 56x56 | 56x56 | 9 | 4 |
| layer1.0.conv2.Conv | 0x001a0000 | 0x005a0000 | 0x004c0000 | 56x56 | 56x56 | 9 | 4 |
| layer1.1.conv1.Conv | 0x001a0000 | 0x00000000 | 0x004c0000 | 56x56 | 56x56 | 9 | 4 |
| layer1.1.conv2.Conv | 0x00000000 | 0x005a0000 | 0x004c0000 | 56x56 | 56x56 | 9 | 4 |
| layer2.0.conv1.Conv | 0x00000000 | 0x001a0000 | 0x004c0000 | 56x56 | 28x28 | 9 | 8 |
| layer2.0.conv2.Conv | 0x001a0000 | 0x005a0000 | 0x004c0000 | 28x28 | 28x28 | 18 | 8 |
| layer2.0.downsample.0.Conv | 0x00000000 | 0x00602000 | 0x004c0000 | 56x56 | 28x28 | 1 | 8 |
| layer2.1.conv1.Conv | 0x001a0000 | 0x00000000 | 0x004c0000 | 28x28 | 28x28 | 18 | 8 |
| layer2.1.conv2.Conv | 0x00000000 | 0x005a0000 | 0x004c0000 | 28x28 | 28x28 | 18 | 8 |
| layer3.0.conv1.Conv | 0x00000000 | 0x001a0000 | 0x004c0000 | 28x28 | 14x14 | 18 | 16 |
| layer3.0.conv2.Conv | 0x001a0000 | 0x005a0000 | 0x004c0000 | 14x14 | 14x14 | 36 | 16 |
| layer3.0.downsample.0.Conv | 0x00000000 | 0x005d1000 | 0x004c0000 | 28x28 | 14x14 | 2 | 16 |
| layer3.1.conv1.Conv | 0x001a0000 | 0x00000000 | 0x004c0000 | 14x14 | 14x14 | 36 | 16 |
| layer3.1.conv2.Conv | 0x00000000 | 0x005a0000 | 0x004c0000 | 14x14 | 14x14 | 36 | 16 |
| layer4.0.conv1.Conv | 0x00000000 | 0x001a0000 | 0x004c0000 | 14x14 | 7x7 | 36 | 32 |
| layer4.0.conv2.Conv | 0x001a0000 | 0x005a0000 | 0x004c0000 | 7x7 | 7x7 | 72 | 32 |
| layer4.0.downsample.0.Conv | 0x00000000 | 0x005b8800 | 0x004c0000 | 14x14 | 7x7 | 4 | 32 |
| layer4.1.conv1.Conv | 0x001a0000 | 0x00000000 | 0x004c0000 | 7x7 | 7x7 | 72 | 32 |
| layer4.1.conv2.Conv | 0x00000000 | 0x005a0000 | 0x004c0000 | 7x7 | 7x7 | 72 | 32 |

## Unsupported nodes (fail-loud)
None.
