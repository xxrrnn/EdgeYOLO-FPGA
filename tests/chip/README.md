# Chip tests

This tree contains the maintained full-network compiler, software golden models,
Windows XDMA runtime, host-side YOLO/ResNet heads, and RTL-support tests for the
`80832ec_attempt1` release.

Key entry points:

- `compiler/compile.py`: parsed model to FPGA program/weights/WB.
- `compiler/test_int16_contract.py`: native W16A16 signed-INT64 layout contract.
- `compiler/check_release_repro.py`: compile all four maintained workloads twice.
- `runtime/hw_runner_win.py`: upload and execute one-shot programs through XDMA.
- `runtime/compare_one_shot.py`: compare FPGA features with compiler golden data.
- `runtime/one_shot_host_head.py`: YOLO Detect/NMS and ResNet GAP/FC/Top-k boundary.

Generated compiler and runtime files belong under `output/` and are not versioned.
Use the repository-root `run.py` for normal operation.
