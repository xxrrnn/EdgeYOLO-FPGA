# E2E simulation filelist for Vivado xsim
# All paths absolute

# ==============================================================================
# Xilinx Floating Point IP core library (MUST be compiled first)
# ==============================================================================
/home/EDAtools/Xilinx/Vivado/2024.2/data/ip/xilinx/floating_point_v7_1/hdl/floating_point_v7_1_rfs.v

# ==============================================================================
# Xilinx Floating Point IP instances
# ==============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_mac/sim/fp32_mac.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_add/sim/fp32_add.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_compare_leq/sim/fp32_compare_leq.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_to_int8/sim/fp32_to_int8.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_to_fixed8/sim/fp32_to_fixed8.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/int32_2_fp32/sim/int32_2_fp32.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_mult_lane/sim/fp32_mult_lane.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_add_lane/sim/fp32_add_lane.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fixed32_to_fp32/sim/fixed32_to_fp32.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp16_mac/sim/fp16_mac.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp16_add/sim/fp16_add.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp16_2_int8/sim/fp16_2_int8.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_2_fp16/sim/fp32_2_fp16.v

# ==============================================================================
# Chip defines and DCIM infrastructure
# ==============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/inc/para.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/inc/counter.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/inc/dff.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/inc/pipe_stage.v

# DCIM weight SRAM macro (must precede sramWrap.v)
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/macro/rf_sp_hde128x128.v

# ==============================================================================
# DCIM core
# ==============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/multiplier.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/adderTree.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/calculate_core.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/sramWrap.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/memory.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/dcim.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/maArray.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/mergeArray.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/accumulateArray.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/ppCache.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/postProcess.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/dcim/act_nibble_converter.sv

# SRAM model
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/model/model_rf.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/ref/DCIM/src/model/model_rf_bram.sv

# IBUF/OBUF
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/DCIM_Macro/ibuf.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/DCIM_Macro/obuf.v

# DCIM Array
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/chip/DCIM_Tile.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/chip/ibuf_rd_arbiter.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/chip/obuf_wr_arbiter.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/chip/DCIM_Array_Group.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/chip/DCIM_Array.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/chip/DCIM_Array_bd.v

# ==============================================================================
# VPU (full, with all units)
# ==============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/Global_VPU.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/Global_VPU_top.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/im2col_unit.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/dqa_relu_unit.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/qa_unit.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/nn_lut_unit.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/ad_unit.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/mp_unit_fixed.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/us_unit_fixed.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/rst_n_sync.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/global_buffer_bram.v

# VPU FP arrays
"/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/fp_mac_array.v"
"/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/fp_add_array.sv"
"/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/int32_2_fp32_array.sv"
"/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/fp32_2_int8_array.sv"
"/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/int32_2_fp16_array.sv"
"/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/fp16_2_int8_array.sv"

# ==============================================================================
# Instruction infrastructure
# ==============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/INST_Decoder.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/INST_BRAM.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/VPU_AXI_Regs.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/CDMA_Controller.sv
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/CDMA_Controller_wrapper.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/INST_Decoder_wrapper.v

# ==============================================================================
# Testbench
# ==============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/tb/e2e/tb_e2e_inst_driven.sv
