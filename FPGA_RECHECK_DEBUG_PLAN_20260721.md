# FPGA Recheck Debug Plan - 2026-07-21

## Current State

- FPGA was redeployed and reset by the user.
- Decoder soft reset works before running a workload:
  - Command:
    `python tests\chip\runtime\hw_runner_win.py --build-dir output\compile_yolo_int8_full_eff --status-only --soft-reset-decoder --quiet-xdma`
  - Result before the failing run:
    `DECODER_STATUS=0x00000000`.
- `run.py` now supports:
  - `--one-shot-read-chunk-bytes N`
  - This is useful for debugging C2H readback instability without editing code.

## Last Hardware Observation

Workload attempted:

```powershell
$env:PYTHONIOENCODING='utf-8'
python run.py --one-shot --network yolo --yolo-precision int8 `
  --one-shot-poll-timeout-s 300 `
  --one-shot-read-chunk-bytes 4096 `
  --out-dir output\fpga_recheck_20260721\yoloir_int8
```

Observed behavior:

- Weights upload succeeded.
- WB upload succeeded.
- Input upload succeeded.
- Program upload succeeded.
- Decoder executed and returned DONE:
  - `DECODER_STATUS=0x00000001`
  - `DECODER_STATUS=0x00000002`
  - `DONE`
- Failure happened during host C2H readback from VPU_BUF, not during FPGA compute.
- The first failure with 64KB chunks hung while reading named YOLO output `PAN_P3`.
- Retest with 4KB chunks still hung, this time while reading `PAN_P5` at:
  - physical address `0x10268a000`
  - this is VPU_BUF base `0x102000000` + offset `0x68a000`
- After this C2H timeout, a later `--status-only` read failed too, so the XDMA path was likely wedged by the failed C2H transaction.

Do not interpret this as a YOLO arithmetic mismatch yet. The latest evidence says:

1. the one-shot program can reach DONE;
2. readback from high VPU_BUF offsets can wedge C2H/XDMA;
3. correctness compare and host head cannot run until readback is stable.

## Important Address Facts

From `output/compile_yolo_int8_full_eff/plan.json`:

- `vpu_buf_base = 0x102000000`
- `vpu_buf_size = 0x800000` (8MB)
- YOLOir INT8 host outputs:
  - `PAN_P3`: offset `0x5f0000`, size `409600` bytes
  - `PAN_P4`: offset `0x654000`, size `204800` bytes
  - `PAN_P5`: offset `0x686000`, size `102400` bytes
- The failing 4KB C2H read was `0x10268a000`, inside `PAN_P5`.

These offsets are within the software-declared 8MB VPU_BUF. If hardware was synthesized with a smaller or differently decoded VPU_BUF aperture, high-offset reads can fail even though low-offset uploads/execution appear OK.

## Immediate Next Steps

After the user resets FPGA again, do not immediately run full YOLO/ResNet. First probe the readback aperture.

### 1. Status and Soft Reset

```powershell
$env:PYTHONIOENCODING='utf-8'
python tests\chip\runtime\hw_runner_win.py --build-dir output\compile_yolo_int8_full_eff --status-only --soft-reset-decoder --quiet-xdma
```

Expected:

- `DECODER_STATUS=0x00000000`

If this fails, stop. The XDMA path/driver is still wedged.

### 2. Direct VPU_BUF C2H Aperture Probe

Use the XDMA wrapper or add a tiny Python probe to read 16B/4KB from these physical addresses without running the network:

```text
0x102000000  VPU_BUF + 0x000000
0x102400000  VPU_BUF + 0x400000
0x1025f0000  VPU_BUF + PAN_P3 offset
0x102654000  VPU_BUF + PAN_P4 offset
0x102686000  VPU_BUF + PAN_P5 offset
0x10268a000  exact failed address
0x1027ffff0  end of 8MB VPU_BUF minus 16B
```

If low offsets read but high offsets hang, investigate BD/XDC/RTL VPU_BUF size/address decode before touching compiler arithmetic.

### 3. Avoid Named Output Readback Temporarily

For a quick compute-only gate, run the one-shot program but read only one small low-address sentinel output, or temporarily compile a one-output probe whose host output offset is low in VPU_BUF.

The current `run.py` one-shot path reads all named YOLO outputs for host head:

- `PAN_P3`
- `PAN_P4`
- `PAN_P5`

That is correct for final inference, but it is not the best first probe while C2H is unstable.

### 4. Re-run YOLOir INT8 After Aperture Passes

```powershell
$env:PYTHONIOENCODING='utf-8'
python run.py --one-shot --network yolo --yolo-precision int8 `
  --one-shot-poll-timeout-s 300 `
  --one-shot-read-chunk-bytes 4096 `
  --out-dir output\fpga_recheck_20260721\yoloir_int8
```

Acceptance:

- decoder DONE;
- all three PAN outputs read back;
- `compare_one_shot.py` passes with `max_abs <= 1e-3`;
- host head emits the expected infrared YOLO detection;
- timing JSON is written.

### 5. Then Continue Workload Order

Only after YOLOir INT8 readback and correctness pass:

1. YOLOir INT16:
   `python run.py --one-shot --network yolo --yolo-precision int16 --one-shot-read-chunk-bytes 4096 --one-shot-poll-timeout-s 300 --out-dir output\fpga_recheck_20260721\yoloir_int16`
2. COCO/original YOLO INT8:
   use `--one-shot-build-dir output\compile_yolo_coco50k_int8_full`, `--one-shot-yolo-parsed-dir model\yolov5n_coco50k_qat\parsed_int8`, and the COCO sample image.
3. COCO/original YOLO INT16:
   same as above with `int16` paths.
4. ResNet INT8:
   `python run.py --one-shot --network resnet --resnet-precision vai --one-shot-read-chunk-bytes 4096 --one-shot-poll-timeout-s 300 --out-dir output\fpga_recheck_20260721\resnet_int8`
5. ResNet INT16:
   `python run.py --one-shot --network resnet --resnet-precision int16 --one-shot-read-chunk-bytes 4096 --one-shot-poll-timeout-s 300 --out-dir output\fpga_recheck_20260721\resnet_int16`

## Useful Code Changes in This Commit

- `run.py`
  - Adds `--one-shot-read-chunk-bytes` so C2H readback chunk size can be changed from CLI.
- `tests/chip/runtime/hw_runner.py`
  - Updates chip-v3 address map.
  - Supports segmented programs and named host outputs.
  - Pads tight NHWC input to the 16-byte pixel stride expected by `im2col_unit`.
- `tests/chip/runtime/xdma_driver.py`
  - Updates Python-side constants to chip-v3 address map.
- `tests/chip/unit-tb/xdma_win.py`
  - Supports `XDMA_RW_EXE`.
  - Also searches `tests/bin/xdma_rw.exe`.
- `tests/chip/unit-tb/e2e_detect.py`, `resnet_e2e.py`, `verify_e2e.py`
  - Add case reuse / configurable runs-base hooks for faster legacy oracle runs.
- Compiler/lowering/packer Python files
  - Contain the current one-shot/full-network compiler work for INT8/INT16 YOLO/ResNet, including weight tiling, QDQ handling, host output planning, and COCO/original YOLO separation support.

## Do Not Do Next

- Do not run all six workloads back-to-back until C2H readback is stable.
- Do not assume this is an arithmetic bug while the host cannot reliably read VPU_BUF.
- Do not change RTL before proving whether high VPU_BUF addresses are readable through XDMA after reset.
