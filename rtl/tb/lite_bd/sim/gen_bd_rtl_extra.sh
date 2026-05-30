#!/usr/bin/env bash
# User RTL not re-exported inside xil_defaultlib by lite.sh (module_ref IP wrappers).
set -euo pipefail
OUT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
LITE_GEN="${LITE_GEN:-$REPO_ROOT/build/lite/lite.gen/sources_1/ip}"

emit() { if [[ -n "$OUT" ]]; then cat >"$OUT"; else cat; fi; }

emit <<EOF
$REPO_ROOT/rtl/ref/DCIM/src/inc/para.v
$REPO_ROOT/rtl/ref/DCIM/src/inc/counter.v
$REPO_ROOT/rtl/ref/DCIM/src/inc/dff.v
$REPO_ROOT/rtl/ref/DCIM/src/inc/pipe_stage.v
$REPO_ROOT/rtl/ref/DCIM/src/macro/rf_sp_hde128x128.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/multiplier.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/adderTree.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/calculate_core.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/sramWrap.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/memory.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/dcim.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/maArray.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/mergeArray.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/accumulateArray.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/ppCache.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/postProcess.v
$REPO_ROOT/rtl/ref/DCIM/src/dcim/act_nibble_converter.sv
$REPO_ROOT/rtl/ref/DCIM/src/model/model_rf.sv
$REPO_ROOT/rtl/ref/DCIM/src/model/model_rf_bram.sv
$REPO_ROOT/rtl/DCIM_Macro/ibuf.v
$REPO_ROOT/rtl/DCIM_Macro/obuf.v
$REPO_ROOT/rtl/chip/DCIM_Tile.sv
$REPO_ROOT/rtl/chip/ibuf_rd_arbiter.sv
$REPO_ROOT/rtl/chip/obuf_wr_arbiter.sv
$REPO_ROOT/rtl/chip/DCIM_Array_Group.sv
$REPO_ROOT/rtl/chip/DCIM_Array.sv
$REPO_ROOT/rtl/chip/DCIM_Array_bd.v
$REPO_ROOT/rtl/vpu/Global_VPU.v
$REPO_ROOT/rtl/vpu/Global_VPU_top.v
$REPO_ROOT/rtl/vpu/im2col_unit.sv
$REPO_ROOT/rtl/vpu/dqa_relu_unit.sv
$REPO_ROOT/rtl/vpu/qa_unit.sv
$REPO_ROOT/rtl/vpu/nn_lut_unit.sv
$REPO_ROOT/rtl/vpu/ad_unit.sv
$REPO_ROOT/rtl/vpu/mp_unit_fixed.sv
$REPO_ROOT/rtl/vpu/us_unit_fixed.sv
$REPO_ROOT/rtl/vpu/rst_n_sync.v
$REPO_ROOT/rtl/vpu/global_buffer_bram.v
$REPO_ROOT/rtl/vpu/fp_array/fp_mac_array.v
$REPO_ROOT/rtl/vpu/fp_array/fp_add_array.sv
$REPO_ROOT/rtl/vpu/fp_array/int32_2_fp32_array.sv
$REPO_ROOT/rtl/vpu/fp_array/fp32_2_int8_array.sv
$REPO_ROOT/rtl/vpu/fp_array/fp32_2_int16_array.sv
$REPO_ROOT/rtl/vpu/fp_array/int32_2_fp16_array.sv
$REPO_ROOT/rtl/vpu/fp_array/fp16_2_int8_array.sv
$REPO_ROOT/rtl/vpu/INST_Decoder.sv
$REPO_ROOT/rtl/vpu/INST_Decoder_wrapper.v
$REPO_ROOT/rtl/vpu/INST_BRAM.v
$REPO_ROOT/rtl/vpu/VPU_AXI_Regs.v
$REPO_ROOT/rtl/vpu/CDMA_Controller.sv
$REPO_ROOT/rtl/vpu/CDMA_Controller_wrapper.v
$REPO_ROOT/bd/lite/hdl/lite_wrapper.v
$LITE_GEN/fp32_mac/sim/fp32_mac.v
$LITE_GEN/fp32_add/sim/fp32_add.v
$LITE_GEN/fp32_compare_leq/sim/fp32_compare_leq.v
$LITE_GEN/fp32_to_int8/sim/fp32_to_int8.v
$LITE_GEN/fp32_to_fixed8/sim/fp32_to_fixed8.v
$LITE_GEN/int32_2_fp32/sim/int32_2_fp32.v
$LITE_GEN/fp32_mult_lane/sim/fp32_mult_lane.v
$LITE_GEN/fp32_add_lane/sim/fp32_add_lane.v
$LITE_GEN/fixed32_to_fp32/sim/fixed32_to_fp32.v
$LITE_GEN/fp16_mac/sim/fp16_mac.v
$LITE_GEN/fp16_add/sim/fp16_add.v
$LITE_GEN/fp16_2_int8/sim/fp16_2_int8.v
$LITE_GEN/fp32_2_fp16/sim/fp32_2_fp16.v
EOF
[[ -n "$OUT" ]] && echo "Wrote extra RTL list -> $OUT"
