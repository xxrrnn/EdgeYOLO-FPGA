# RTL regression: yolov5n model.1.conv (single layer)

This directory contains regression assets for running yolov5n's first
"real" conv (`model.1.conv`: in 160×160×16 → out 80×80×32, kernel 3×3
stride 2 pad 1) through the existing `INST_Decoder` + `Global_VPU` +
`DCIM_Array` pipeline as a self-contained RTL simulation.

## Files

| file | format | role |
|---|---|---|
| `golden_instructions.hex`  | 32-bit hex/line | full instruction program (`OP_VPU_EXEC` im2col → `OP_CDMA_COPY` → `OP_DCIM_CFG` → `OP_DCIM_EXEC` → `OP_VPU_EXEC` dqa) |
| `golden_feature.hex`       | 128-bit hex/line | input feature map, NHWC INT8 (uint8 view), `25600` words at OBUF `0x000000` |
| `golden_weight.hex`        | 128-bit hex/line | INT8 nibble-packed weights, 8 tiles × 9 acc_depth × 16 ch_out = 1152 entries at IBUF word 0 |
| `golden_im2col.hex`        | 128-bit hex/line | expected im2col output at OBUF `0x800000`, 80*80 rows × 9 acc_depth = 57600 words |
| `golden_dcim_tile0.hex`    | 128-bit hex/line | expected INT32 DCIM tile-0 output: 80*80*16 INT32 = 25600 words |
| `golden_dcim_tile1.hex`    | 128-bit hex/line | expected INT32 DCIM tile-1 output (next 16 ch_out) |
| `params.json`              | JSON | dimensions and base addresses for the TB |

These files are produced by `tools/tests/gen_regression_l1_hex.py`
(re-run after any compiler / packer / lowering change).

## How to wire into a SystemVerilog TB

The existing `rtl/vpu/tb/tb_inst_driven_im2col_dcim.sv` is hard-coded for
the 8×8×16 / 3×3 test; reusing it verbatim with these files would fail
because the OBUF / IBUF capacities the TB expects are too small.  Two
ways forward:

### Option A — adapt the existing TB (recommended for quick bring-up)

Copy `tb_inst_driven_im2col_dcim.sv` to e.g.
`tb_yolov5n_l1.sv` and:

1. Bump the memory parameters:
   - `FEATURE_BASE = 24'h000000`
   - `IM2COL_BASE  = 24'h800000`
   - `DCIM_OUT_BASE = 24'h400000`
   - `IBUF_WEI_BASE_word = 0`
   - `IBUF_ACT_BASE_word = 1152`
2. Change `$readmemh` paths to `regression_l1/...`.
3. Loop `obuf_write_word` over `25600` feature words (instead of 64).
4. Loop `ibuf_write_word` over `1152` weight words.
5. Lower the verification loop to read just the first 20 im2col words
   and the first INT32 word of each tile output to keep simulation
   time finite; spot-check matches.

### Option B — extend `gen_regression_l1_hex.py` with sub-tiles

If the simulator can't handle 1 MB OBUF mem, split the layer by output
H (`OH` chunks) and emit multiple regression test cases.  Not yet
implemented; the current MVP only emits the full layer.

## How to verify without RTL

`tools/tests/test_sim_runner_layer1.py` already cross-checks the
sim_runner output against `rtl/vpu/tb/e2e/hex/layer1_dqa.hex` (which is
the FP32 reference produced by `golden_e2e.py`).  This is a strong
oracle for the entire `im2col → DCIM → DQA` pipeline; the only thing
RTL adds on top of sim_runner is the actual `INST_Decoder` finite-state
machine.  If you only want to verify the host stack you can skip RTL
entirely and rely on the sim_runner regression.
