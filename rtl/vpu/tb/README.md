# VPU Testbench Layout

This directory is organized by validation scope.

## `standalone/`

Unit-level tests with focused golden checks and minimal dependencies.

- `tb_qa_standalone.sv`: QA unit, lite parameters, Python golden, OBUF-ready/valid behavior.
- `tb_dqa_standalone.sv`: DQA unit, lite parameters, Python golden, real `rtl/DCIM_Macro/obuf.v` Port A/B usage.
- `generated/`: generated standalone golden `.svh` files.
- `tb_im2col_unit.sv`: im2col unit standalone test.
- `tb_INST_Decoder.sv`: instruction decoder unit test.

## `integration/`

Small multi-unit tests that validate important hardware paths without full E2E runtime.

- `tb_im2col_dcim_joint.sv`: im2col + CDMA/IBUF + DCIM joint validation.
- `tb_inst_driven_im2col_dcim.sv`: instruction-driven im2col/DCIM integration.

## `e2e/`

End-to-end simulations and generated golden data.

- `tb_e2e_inst_driven.sv`: full 3-layer instruction-driven E2E. Slow; use after standalone/integration checks pass.
- `golden_e2e_inst.py`: generates E2E input, weights, instructions, and checkpoint goldens.
- `*.hex`: generated data consumed by E2E testbenches.

## `legacy/`

Older or pre-lite testbenches kept for reference. They may use stale parameters or simplified memories and should not be treated as current regression sources unless refreshed.

## `sim/`

Reusable xsim scripts and filelists. Current primary regressions:

```bash
bash rtl/vpu/tb/sim/run_xsim_qa_standalone.sh
bash rtl/vpu/tb/sim/run_xsim_dqa_standalone.sh
```
