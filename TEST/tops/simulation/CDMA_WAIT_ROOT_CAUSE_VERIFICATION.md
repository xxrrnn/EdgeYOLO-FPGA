# CDMA completion root-cause verification

## Root cause

The board failure is a completion race, but the faulty completion decision is
inside `CDMA_Controller`, not the Decoder's view of the controller `IDLE` state.

After writing the AXI CDMA BTT register, the IP may briefly continue to report
`SR.IDLE=1` before the transfer enters its busy state. The old controller accepts
the first post-BTT `IDLE=1` as completion, waits only the fixed cooldown, and
returns to its own `IDLE`. The Decoder then legally starts DCIM while the AXI
CDMA is still filling IBUF.

The Decoder-only change in `9595833` observes the controller state, not the AXI
CDMA `SR.IDLE` bit, so it cannot distinguish this false completion.

## Decisive Verilator A/B test

The test instantiates the real `INST_Decoder` and `CDMA_Controller` and copies
the real YOLO `model.0.conv` activation vector: 4000 pixels x 8 128-bit words,
512000 bytes. `SR_BUSY_DELAY_CYCLES=64` models the legal launch interval in
which BTT has been accepted but AXI CDMA still reports `SR.IDLE=1`.

Old controller result:

```text
EARLY_DCIM cycle=2087 copied_words=3900/32000 controller_state=0 decoder_state=28
```

Fixed controller result:

```text
CDMA_WAIT_PASS bytes=512000 accept_cycle=51 busy_cycle=136
complete_cycle=16136 dcim_cycle=18151 gap=2015
```

The fixed controller records a post-BTT `SR.IDLE=0` observation and accepts
completion only when a later status response returns `SR.IDLE=1`.

Run with:

```bash
SR_BUSY_DELAY_CYCLES=64 \
RUN_DIR=/tmp/cdma_ctrl_delayed \
bash TEST/tops/simulation/run_cdma_decoder_wait_verilator.sh
```

## Vivado-exported BD / VCS regression

Vivado `export_simulation` does not provide a Verilator target, and the encrypted
Xilinx AXI CDMA model cannot be compiled by Verilator. The adversarial test is
therefore cross-checked on eda02 using the Vivado-exported BD, real AXI CDMA and
SmartConnect simulation models.

Results after the controller fix:

```text
conv_pipeline / pipe_conv1_c16_to16:
  Decoder done at 14822 cycles
  MODULE RESULTS: 16 PASS, 0 FAIL

cdma_memtest / cdma_obuf_ibuf_obuf_c128 (2048 bytes each direction):
  Decoder done at 6624 cycles
  MODULE RESULTS: 128 PASS, 0 FAIL

cdma_memtest / cdma_obuf_ibuf_obuf_16b (minimum non-zero copy):
  Decoder done at 4404 cycles
  MODULE RESULTS: 1 PASS, 0 FAIL

cdma_memtest / cdma_obuf_ibuf_obuf_large (65536 bytes each direction):
  Decoder done at 115772 cycles
  MODULE RESULTS: 4096 PASS, 0 FAIL
```

The earlier controller completed the same small convolution case at 12914
cycles. The additional cycles are the real transfer-completion wait that was
previously skipped; the fixed result remains bit-exact.

## RTL fix

`rtl/vpu/CDMA_Controller.sv` adds one `sr_seen_busy` bit:

1. Clear it for each new command.
2. Set it when a post-BTT status read returns `SR.IDLE=0`.
3. Enter cooldown only for `sr_seen_busy && SR.IDLE=1`.

The host ABI, ISA, address map, data mapping, DCIM arithmetic and pipeline are
unchanged.
