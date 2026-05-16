# ==============================================================================
# run_bd_sim.tcl - Block Design 级仿真（使用真实 Xilinx IP）
#
# 用法: vivado -mode batch -source scripts/vpu/run_bd_sim.tcl
#
# 创建仿真专用 BD：
#   - AXI VIP (Master) 替代 XDMA
#   - 真实 AXI CDMA IP
#   - 真实 SmartConnect
#   - 真实 AXI BRAM Controller + Block Memory
#   - 我们的 RTL: INST_Decoder, CDMA_Controller, VPU_AXI_Regs, INST_BRAM, Global_VPU_top
# ==============================================================================

set scriptDir [file dirname [file normalize [info script]]]
source [file normalize "$scriptDir/config.tcl"]

# 仿真输出目录
set simOut [file normalize "$buildDir/vpu_bd_sim"]
file mkdir $simOut

# 清理旧项目
set projPath [file normalize "$simOut/bd_sim"]
if {[file exists $projPath]} {
    file delete -force $projPath
}

puts "================================================================"
puts "  创建 BD 仿真项目"
puts "================================================================"

create_project bd_sim $projPath -part $part -force

# 添加所有 VPU RTL 文件（包括子目录，排除 testbench）
set vpuRtlFiles {}
foreach pattern {*.v *.sv */*.v */*.sv} {
    foreach f [glob -nocomplain [file normalize "$vpuRtlDir/$pattern"]] {
        if {![regexp {(tb_.*)\.(v|sv)$} [file tail $f]]} {
            lappend vpuRtlFiles $f
        }
    }
}
add_files -norecurse $vpuRtlFiles
set_property include_dirs [list $vpuRtlDir "$vpuRtlDir/fp array"] [current_fileset]
update_compile_order -fileset sources_1

# 添加 floating point IP (VPU 依赖)
source [file normalize "$scriptsDir/ip/floating_point_fp32.tcl"]
if {[llength [get_ips -quiet fp32_mult_lane]] == 0 || [llength [get_ips -quiet fp32_add_lane]] == 0} {
    fp32_mac_ips_create
}

# ==============================================================================
# 创建仿真 Block Design
# ==============================================================================
set simBdName "sim_bd"
create_bd_design $simBdName

# --- AXI VIP 作为 Master (替代 XDMA) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vip:1.1 axi_vip_master
set_property -dict [list \
    CONFIG.INTERFACE_MODE {MASTER} \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
] [get_bd_cells axi_vip_master]

# --- 我们的 RTL 模块 ---
set_property top Global_VPU_top [current_fileset]
update_compile_order -fileset sources_1

create_bd_cell -type module -reference Global_VPU_top vpu_0
create_bd_cell -type module -reference VPU_AXI_Regs vpu_regs
create_bd_cell -type module -reference INST_BRAM inst_bram
create_bd_cell -type module -reference INST_Decoder_wrapper inst_decoder
create_bd_cell -type module -reference CDMA_Controller_wrapper cdma_ctrl

# --- 真实 Xilinx IP ---
# AXI CDMA
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_cdma:4.1 axi_cdma_0
set_property -dict [list \
    CONFIG.C_ADDR_WIDTH {32} \
    CONFIG.C_INCLUDE_SG {0} \
    CONFIG.C_M_AXI_DATA_WIDTH {32} \
    CONFIG.C_INCLUDE_DRE {1} \
] [get_bd_cells axi_cdma_0]

# Global BRAM Controller + BRAM
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 global_bram_ctrl
set_property -dict [list \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells global_bram_ctrl]

create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 global_bram
set_property -dict [list \
    CONFIG.use_bram_block {BRAM_Controller} \
    CONFIG.EN_SAFETY_CKT {false} \
    CONFIG.Memory_Type {Single_Port_RAM} \
    CONFIG.Write_Depth_A {16384} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Read_Width_A {32} \
] [get_bd_cells global_bram]

# VPU GB Controller (匹配 VPU 的 256 位接口)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_gb_ctrl
set_property -dict [list \
    CONFIG.DATA_WIDTH {256} \
    CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells vpu_gb_ctrl]

# VPU WB Controller
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_wb_ctrl
set_property -dict [list \
    CONFIG.DATA_WIDTH {256} \
    CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells vpu_wb_ctrl]

# SmartConnect: 2 SI (VIP + CDMA), 5 MI
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property -dict [list \
    CONFIG.NUM_SI {2} \
    CONFIG.NUM_MI {5} \
] [get_bd_cells axi_smc]

# ==============================================================================
# 连接
# ==============================================================================
# SmartConnect 输入
connect_bd_intf_net [get_bd_intf_pins axi_vip_master/M_AXI] [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI]     [get_bd_intf_pins axi_smc/S01_AXI]

# SmartConnect 输出
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins global_bram_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins vpu_gb_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M02_AXI] [get_bd_intf_pins vpu_wb_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] [get_bd_intf_pins inst_bram/s_axi]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M04_AXI] [get_bd_intf_pins vpu_regs/s_axi]

# Global BRAM
connect_bd_intf_net [get_bd_intf_pins global_bram/BRAM_PORTA] [get_bd_intf_pins global_bram_ctrl/BRAM_PORTA]

# VPU GB/WB -> VPU 内部 BRAM
connect_bd_intf_net [get_bd_intf_pins vpu_gb_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/gb_bram]
connect_bd_intf_net [get_bd_intf_pins vpu_wb_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/wb_bram]

# CDMA_Controller -> CDMA IP (点对点 AXI-Lite)
connect_bd_intf_net [get_bd_intf_pins cdma_ctrl/cdma_axilm] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]

# INST_Decoder -> CDMA_Controller
connect_bd_net [get_bd_pins inst_decoder/cdma_start]         [get_bd_pins cdma_ctrl/cdma_start]
connect_bd_net [get_bd_pins inst_decoder/cdma_config_valid]  [get_bd_pins cdma_ctrl/cdma_config_valid]
connect_bd_net [get_bd_pins cdma_ctrl/cdma_config_ready]     [get_bd_pins inst_decoder/cdma_config_ready]
connect_bd_net [get_bd_pins inst_decoder/cdma_src_addr_msb]  [get_bd_pins cdma_ctrl/cdma_src_addr_msb]
connect_bd_net [get_bd_pins inst_decoder/cdma_src_addr_lsb]  [get_bd_pins cdma_ctrl/cdma_src_addr_lsb]
connect_bd_net [get_bd_pins inst_decoder/cdma_dst_addr_msb]  [get_bd_pins cdma_ctrl/cdma_dst_addr_msb]
connect_bd_net [get_bd_pins inst_decoder/cdma_dst_addr_lsb]  [get_bd_pins cdma_ctrl/cdma_dst_addr_lsb]
connect_bd_net [get_bd_pins inst_decoder/cdma_length]        [get_bd_pins cdma_ctrl/cdma_length]

# INST_Decoder -> inst_bram
connect_bd_net [get_bd_pins inst_decoder/inst_rd_addr] [get_bd_pins inst_bram/inst_rd_addr]
connect_bd_net [get_bd_pins inst_bram/inst_rd_data]    [get_bd_pins inst_decoder/inst_rd_data]

# VPU_AXI_Regs -> INST_Decoder
connect_bd_net [get_bd_pins vpu_regs/decoder_start]    [get_bd_pins inst_decoder/decoder_start]
connect_bd_net [get_bd_pins vpu_regs/inst_count]       [get_bd_pins inst_decoder/inst_count]
connect_bd_net [get_bd_pins inst_decoder/decoder_busy]   [get_bd_pins vpu_regs/decoder_busy]
connect_bd_net [get_bd_pins inst_decoder/decoder_done]   [get_bd_pins vpu_regs/decoder_done]
connect_bd_net [get_bd_pins inst_decoder/decoder_status] [get_bd_pins vpu_regs/decoder_status]

# INST_Decoder -> VPU
connect_bd_net [get_bd_pins inst_decoder/vpu_start]      [get_bd_pins vpu_0/vpu_start]
connect_bd_net [get_bd_pins inst_decoder/vpu_unit_choose] [get_bd_pins vpu_0/unit_choose]
connect_bd_net [get_bd_pins inst_decoder/vpu_src_addr]   [get_bd_pins vpu_0/src_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_src2_addr]  [get_bd_pins vpu_0/src2_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_src_c]      [get_bd_pins vpu_0/src_c]
connect_bd_net [get_bd_pins inst_decoder/vpu_src_h]      [get_bd_pins vpu_0/src_h]
connect_bd_net [get_bd_pins inst_decoder/vpu_src_w]      [get_bd_pins vpu_0/src_w]
connect_bd_net [get_bd_pins inst_decoder/vpu_bias_addr]  [get_bd_pins vpu_0/bias_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_scale_addr] [get_bd_pins vpu_0/scale_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_dst_addr]   [get_bd_pins vpu_0/dst_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_addr_break] [get_bd_pins vpu_0/addr_break]
connect_bd_net [get_bd_pins inst_decoder/vpu_addr_s]     [get_bd_pins vpu_0/addr_s]
connect_bd_net [get_bd_pins inst_decoder/vpu_addr_t]     [get_bd_pins vpu_0/addr_t]
connect_bd_net [get_bd_pins vpu_0/ready]                 [get_bd_pins inst_decoder/vpu_ready]
connect_bd_net [get_bd_pins vpu_0/ready]                 [get_bd_pins vpu_regs/ready]

# ==============================================================================
# 时钟/复位
# ==============================================================================
create_bd_port -dir I -type clk aclk
set_property CONFIG.FREQ_HZ 250000000 [get_bd_ports aclk]
create_bd_port -dir I -type rst aresetn
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports aresetn]

connect_bd_net [get_bd_ports aclk] [get_bd_pins axi_vip_master/aclk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins axi_vip_master/aresetn]

connect_bd_net [get_bd_ports aclk] [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins axi_smc/aresetn]

connect_bd_net [get_bd_ports aclk] [get_bd_pins global_bram_ctrl/s_axi_aclk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins global_bram_ctrl/s_axi_aresetn]

connect_bd_net [get_bd_ports aclk] [get_bd_pins vpu_gb_ctrl/s_axi_aclk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins vpu_gb_ctrl/s_axi_aresetn]
connect_bd_net [get_bd_ports aclk] [get_bd_pins vpu_wb_ctrl/s_axi_aclk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins vpu_wb_ctrl/s_axi_aresetn]

connect_bd_net [get_bd_ports aclk] [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_ports aclk] [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]

connect_bd_net [get_bd_ports aclk] [get_bd_pins vpu_regs/clk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins vpu_regs/rst_n]
connect_bd_net [get_bd_ports aclk] [get_bd_pins vpu_0/clk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins vpu_0/rst_n]
connect_bd_net [get_bd_ports aclk] [get_bd_pins inst_bram/clk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins inst_bram/rst_n]
connect_bd_net [get_bd_ports aclk] [get_bd_pins inst_decoder/clk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins inst_decoder/rst_n]
connect_bd_net [get_bd_ports aclk] [get_bd_pins cdma_ctrl/clk]
connect_bd_net [get_bd_ports aresetn] [get_bd_pins cdma_ctrl/rst_n]

# ==============================================================================
# 地址映射
# ==============================================================================
assign_bd_address

# 手动设置地址（与硬件一致）
set_property range 1M   [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_global_bram_ctrl_Mem0}]
set_property offset 0x10000000 [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_global_bram_ctrl_Mem0}]

set_property range 1M   [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_inst_bram_reg0}]
set_property offset 0x10200000 [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_inst_bram_reg0}]

set_property range 128K [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_vpu_gb_ctrl_Mem0}]
set_property offset 0x10400000 [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_vpu_gb_ctrl_Mem0}]

set_property range 128K [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_vpu_wb_ctrl_Mem0}]
set_property offset 0x10420000 [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_vpu_wb_ctrl_Mem0}]

set_property range 4K   [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_vpu_regs_reg0}]
set_property offset 0x10440000 [get_bd_addr_segs {axi_vip_master/Master_AXI/SEG_vpu_regs_reg0}]

# CDMA 数据空间
set_property range 1M   [get_bd_addr_segs {axi_cdma_0/Data/SEG_global_bram_ctrl_Mem0}]
set_property offset 0x10000000 [get_bd_addr_segs {axi_cdma_0/Data/SEG_global_bram_ctrl_Mem0}]

# Include excluded CDMA segments
startgroup
foreach pattern {
    axi_cdma_0/Data/SEG_vpu_gb_ctrl_Mem0
    axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0
} {
    set seg [get_bd_addr_segs -quiet -excluded $pattern]
    if {[llength $seg] != 0} {
        include_bd_addr_seg $seg
    }
}
endgroup

# CDMA 地址空间中 S_AXI_LITE 的映射
# 重要：将 cdma_ctrl 地址空间中的 CDMA 地址改为 0x0（这样 RTL 中 BASE_ADDR=0 即可）
set cdma_lite_seg [get_bd_addr_segs -quiet {cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg}]
if {[llength $cdma_lite_seg] != 0} {
    set_property offset 0x00000000 $cdma_lite_seg
    set_property range 64K $cdma_lite_seg
    puts "INFO: Set CDMA S_AXI_LITE at 0x0 in cdma_ctrl address space"
} else {
    puts "WARNING: Cannot find cdma_ctrl -> CDMA addr seg, trying alternative..."
    set cdma_lite_seg [get_bd_addr_segs -quiet {cdma_ctrl/cdma_axilm/*}]
    if {[llength $cdma_lite_seg] != 0} {
        foreach seg $cdma_lite_seg {
            set_property offset 0x00000000 $seg
            set_property range 64K $seg
            puts "INFO: Set $seg at offset 0x0"
        }
    }
}

# CDMA 数据空间 VPU GB/WB
catch {
    set_property range 128K [get_bd_addr_segs {axi_cdma_0/Data/SEG_vpu_gb_ctrl_Mem0}]
    set_property offset 0x10400000 [get_bd_addr_segs {axi_cdma_0/Data/SEG_vpu_gb_ctrl_Mem0}]
    set_property range 128K [get_bd_addr_segs {axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0}]
    set_property offset 0x10420000 [get_bd_addr_segs {axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0}]
}

# ==============================================================================
# 验证 BD
# ==============================================================================
validate_bd_design
save_bd_design

# 生成 BD wrapper
generate_target all [get_files [get_bd_designs $simBdName]]
make_wrapper -files [get_files ${simBdName}.bd] -top
set wrapperFiles [glob -nocomplain "$projPath/bd_sim.gen/sources_1/bd/$simBdName/hdl/*_wrapper.v"]
if {[llength $wrapperFiles] == 0} {
    set wrapperFiles [glob -nocomplain "$projPath/bd_sim.srcs/sources_1/bd/$simBdName/hdl/*_wrapper.v"]
}
if {[llength $wrapperFiles] > 0} {
    add_files -norecurse [lindex $wrapperFiles 0]
    puts "INFO: Added wrapper: [lindex $wrapperFiles 0]"
} else {
    puts "ERROR: Cannot find BD wrapper!"
    exit 1
}

# ==============================================================================
# 添加 Testbench 并运行仿真
# 注意：AXI VIP 需要特殊的 include 路径和编译顺序
# Vivado 的 launch_simulation 会自动处理 IP 依赖
# ==============================================================================
set tbFile [file normalize "$vpuRtlDir/tb/tb_bd_cdma_sim.sv"]
add_files -fileset sim_1 -norecurse $tbFile
set_property top tb_bd_cdma_sim [get_filesets sim_1]
update_compile_order -fileset sim_1

# 设置仿真时间
set_property -name {xsim.simulate.runtime} -value {500us} -objects [get_filesets sim_1]

puts "\n================================================================"
puts "  BD 创建完成，开始仿真..."
puts "================================================================\n"

# 运行行为仿真
launch_simulation -mode behavioral
run all
close_sim

puts "\n================================================================"
puts "  仿真完成"
puts "================================================================\n"

exit 0
