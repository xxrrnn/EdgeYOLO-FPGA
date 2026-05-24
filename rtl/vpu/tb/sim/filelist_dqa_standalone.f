# ==============================================================================
# DQA standalone simulation filelist
# ==============================================================================
# 说明：
#   - 跑 tb_dqa_standalone 所需的最小文件集
#   - 包含真实 OBUF（URAM 结构）+ DQA unit + FP IP
#   - 不包含 DCIM/IBUF/INST_Decoder 等 E2E 组件
#
# 编译顺序：
#   1. Xilinx FP IP 库（floating_point_v7_1_rfs.v）
#   2. FP IP 实例（fp32_mac, int32_2_fp32）
#   3. VPU FP array wrappers
#   4. OBUF（真实 URAM 双端口结构）
#   5. DQA unit（DUT）
#   6. Testbench
# ==============================================================================

# ============================================================================
# Xilinx Floating Point IP library (必须最先编)
# ============================================================================
/home/EDAtools/Xilinx/Vivado/2024.2/data/ip/xilinx/floating_point_v7_1/hdl/floating_point_v7_1_rfs.v

# ============================================================================
# Xilinx FP IP instances (DQA 用到的：fp32_mac, int32_to_fp32)
# ============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_mac/sim/fp32_mac.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/int32_2_fp32/sim/int32_2_fp32.v

# ============================================================================
# VPU FP array wrappers
# ============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/fp_mac_array.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/int32_2_fp32_array.sv

# ============================================================================
# OBUF (真实 URAM 双端口结构，带 douta_valid)
# ============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/DCIM_Macro/obuf.v

# ============================================================================
# DUT: DQA unit
# ============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/dqa_relu_unit.sv

# ============================================================================
# Testbench
# ============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/tb/standalone/tb_dqa_standalone.sv
