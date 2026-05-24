# QA standalone simulation filelist
# 跑 tb_qa_standalone 所需的最小文件集
#
# 注意：含空格的路径用双引号（xvlog/vlogan 都支持）

# ============================================================================
# Xilinx Floating Point IP library (必须最先编)
# ============================================================================
/home/EDAtools/Xilinx/Vivado/2024.2/data/ip/xilinx/floating_point_v7_1/hdl/floating_point_v7_1_rfs.v

# ============================================================================
# Xilinx FP IP instances (QA 用到的：fp32_mac, fp32_to_int8)
# ============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_mac/sim/fp32_mac.v
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/build/lite/lite.gen/sources_1/ip/fp32_to_int8/sim/fp32_to_int8.v

# ============================================================================
# VPU FP array wrappers (注意目录名含空格)
# ============================================================================
"/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/fp_mac_array.v"
"/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/fp_array/fp32_2_int8_array.sv"

# ============================================================================
# DUT
# ============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/qa_unit.sv

# ============================================================================
# Testbench
# ============================================================================
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite/rtl/vpu/tb/standalone/tb_qa_standalone.sv
