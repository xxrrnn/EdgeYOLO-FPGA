# E2E CNN Simulation filelist
# 包含完整 VPU (含 FP IP) + DCIM_Array + INST_Decoder

# === Xilinx Simulation Libraries ===
# Floating-point 基础库（所有 FP IP 共享）
../../../../../../build/lite/lite.gen/sources_1/ip/fp32_mac/hdl/floating_point_v7_1_rfs.v

# === FP IP Simulation Models ===
../../../../../../build/lite/lite.gen/sources_1/ip/fp32_mac/sim/fp32_mac.v
../../../../../../build/lite/lite.gen/sources_1/ip/int32_2_fp32/sim/int32_2_fp32.v
../../../../../../build/lite/lite.gen/sources_1/ip/fp32_to_int8/sim/fp32_to_int8.v
../../../../../../build/lite/lite.gen/sources_1/ip/fp32_compare_leq/sim/fp32_compare_leq.v
../../../../../../build/lite/lite.gen/sources_1/ip/fp32_add/sim/fp32_add.v
../../../../../../build/lite/lite.gen/sources_1/ip/fp32_to_fixed8/sim/fp32_to_fixed8.v

# === Chip Defines ===
../../../../chip/chip_defines.vh

# === DCIM Core ===
../../../../ref/DCIM/src/inc/para.v
../../../../ref/DCIM/src/inc/counter.v
../../../../ref/DCIM/src/inc/dff.v
../../../../ref/DCIM/src/inc/pipe_stage.v
../../../../ref/DCIM/src/dcim/multiplier.v
../../../../ref/DCIM/src/dcim/adderTree.v
../../../../ref/DCIM/src/dcim/calculate_core.v
../../../../ref/DCIM/src/dcim/sramWrap.v
../../../../ref/DCIM/src/dcim/memory.v
../../../../ref/DCIM/src/dcim/dcim.v
../../../../ref/DCIM/src/dcim/maArray.v
../../../../ref/DCIM/src/dcim/mergeArray.v
../../../../ref/DCIM/src/dcim/accumulateArray.v
../../../../ref/DCIM/src/dcim/ppCache.v
../../../../ref/DCIM/src/dcim/postProcess.v
../../../../ref/DCIM/src/dcim/act_nibble_converter.sv
../../../../ref/DCIM/src/model/model_rf.sv
../../../../ref/DCIM/src/model/model_rf_bram.sv

# === IBUF / OBUF ===
../../../../DCIM_Macro/ibuf.v
../../../../DCIM_Macro/obuf.v

# === DCIM Chip Integration ===
../../../../chip/DCIM_Tile.sv
../../../../chip/ibuf_rd_arbiter.sv
../../../../chip/obuf_wr_arbiter.sv
../../../../chip/DCIM_Array_Group.sv
../../../../chip/DCIM_Array.sv
../../../../chip/DCIM_Array_bd.v

# === VPU Core ===
../../../im2col_unit.sv
../../../dqa_relu_unit.sv
../../../qa_unit.sv
../../../nn_lut_unit.sv
../../../ad_unit.sv
../../../mp_unit_fixed.sv
../../../us_unit_fixed.sv
../../../int8_pack_writer.sv
../../../rst_n_sync.v
../../../global_buffer_bram.v

# === VPU FP Array ===
../../../fp\ array/fp_mac_array.v
../../../fp\ array/int32_2_fp32_array.sv
../../../fp\ array/fp32_2_int8_array.sv
../../../fp\ array/fp_add_array.sv

# === VPU Top ===
../../../Global_VPU.v
../../../Global_VPU_top.v

# === INST_Decoder + Infrastructure ===
../../../INST_Decoder.sv
../../../INST_BRAM.v
../../../CDMA_Controller.sv
../../../VPU_AXI_Regs.v
