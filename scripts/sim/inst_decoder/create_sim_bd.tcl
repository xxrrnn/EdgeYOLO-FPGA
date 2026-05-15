################################################################################
# 创建仿真专用 Block Design
# 用于测试 INST_Decoder + CDMA_Controller + Xilinx CDMA IP
# 
# 与生产 BD 的区别：
# - 不包含 XDMA（需要 PCIe）
# - 使用 AXI VIP 作为 Master 来模拟主机访问
################################################################################

# 设置路径
set proj_root [file normalize [file dirname [info script]]/../..]
set rtl_dir   $proj_root/rtl/vpu
set sim_dir   [file dirname [info script]]

# 创建仿真项目
set sim_proj_dir $sim_dir/vivado_sim
file mkdir $sim_proj_dir

create_project sim_inst_decoder $sim_proj_dir -part xcu50-fsvh2104-2-e -force

# 添加 RTL 源文件
add_files -norecurse [glob $rtl_dir/*.v $rtl_dir/*.sv]
update_compile_order -fileset sources_1

# 创建仿真专用 Block Design
create_bd_design "sim_bd"

# ============================================================================
# 创建时钟和复位
# ============================================================================
create_bd_port -dir I -type clk clk
set_property CONFIG.FREQ_HZ 100000000 [get_bd_ports clk]

create_bd_port -dir I -type rst rst_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports rst_n]

# ============================================================================
# 创建 AXI CDMA IP
# ============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_cdma:4.1 axi_cdma_0
set_property -dict [list \
    CONFIG.C_INCLUDE_SG {0} \
    CONFIG.C_M_AXI_DATA_WIDTH {32} \
    CONFIG.C_M_AXI_MAX_BURST_LEN {16} \
] [get_bd_cells axi_cdma_0]

# ============================================================================
# 创建 AXI BRAM Controller + BRAM (数据存储)
# ============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 data_bram_ctrl
set_property -dict [list \
    CONFIG.SINGLE_PORT_BRAM {1} \
    CONFIG.DATA_WIDTH {32} \
] [get_bd_cells data_bram_ctrl]

create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 data_bram
set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Write_Depth_A {16384} \
    CONFIG.Write_Width_A {32} \
] [get_bd_cells data_bram]

connect_bd_intf_net [get_bd_intf_pins data_bram_ctrl/BRAM_PORTA] [get_bd_intf_pins data_bram/BRAM_PORTA]

# ============================================================================
# 创建 INST_BRAM (指令存储)
# ============================================================================
create_bd_cell -type module -reference INST_BRAM inst_bram

# ============================================================================
# 创建 INST_Decoder
# ============================================================================
create_bd_cell -type module -reference INST_Decoder_wrapper inst_decoder

# ============================================================================
# 创建 CDMA_Controller
# ============================================================================
create_bd_cell -type module -reference CDMA_Controller_wrapper cdma_ctrl

# ============================================================================
# 创建 VPU_AXI_Regs (用于控制解码器)
# ============================================================================
create_bd_cell -type module -reference VPU_AXI_Regs vpu_regs

# ============================================================================
# 创建 AXI Interconnect
# ============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {3} \
] [get_bd_cells axi_interconnect_0]

# ============================================================================
# 创建 AXI VIP (模拟主机)
# ============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vip:1.1 axi_vip_master
set_property -dict [list \
    CONFIG.INTERFACE_MODE {MASTER} \
    CONFIG.PROTOCOL {AXI4LITE} \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
] [get_bd_cells axi_vip_master]

# ============================================================================
# 连接
# ============================================================================

# AXI VIP -> Interconnect
connect_bd_intf_net [get_bd_intf_pins axi_vip_master/M_AXI] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# Interconnect -> inst_bram (M00)
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins inst_bram/s_axi]

# Interconnect -> vpu_regs (M01)
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins vpu_regs/s_axi]

# Interconnect -> data_bram_ctrl (M02)
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M02_AXI] [get_bd_intf_pins data_bram_ctrl/S_AXI]

# CDMA_Controller -> CDMA IP
connect_bd_intf_net [get_bd_intf_pins cdma_ctrl/cdma_axilm] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]

# CDMA IP -> data_bram_ctrl (通过另一个端口)
# 注意：这里简化处理，实际需要 AXI Interconnect 来合并多个 Master
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins data_bram/BRAM_PORTB]

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
connect_bd_net [get_bd_pins vpu_regs/decoder_start]  [get_bd_pins inst_decoder/decoder_start]
connect_bd_net [get_bd_pins vpu_regs/inst_count]     [get_bd_pins inst_decoder/inst_count]
connect_bd_net [get_bd_pins inst_decoder/decoder_busy]   [get_bd_pins vpu_regs/decoder_busy]
connect_bd_net [get_bd_pins inst_decoder/decoder_done]   [get_bd_pins vpu_regs/decoder_done]
connect_bd_net [get_bd_pins inst_decoder/decoder_status] [get_bd_pins vpu_regs/decoder_status]

# 时钟和复位
connect_bd_net [get_bd_ports clk] [get_bd_pins axi_vip_master/aclk]
connect_bd_net [get_bd_ports clk] [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net [get_bd_ports clk] [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net [get_bd_ports clk] [get_bd_pins axi_interconnect_0/M00_ACLK]
connect_bd_net [get_bd_ports clk] [get_bd_pins axi_interconnect_0/M01_ACLK]
connect_bd_net [get_bd_ports clk] [get_bd_pins axi_interconnect_0/M02_ACLK]
connect_bd_net [get_bd_ports clk] [get_bd_pins inst_bram/clk]
connect_bd_net [get_bd_ports clk] [get_bd_pins inst_decoder/clk]
connect_bd_net [get_bd_ports clk] [get_bd_pins cdma_ctrl/clk]
connect_bd_net [get_bd_ports clk] [get_bd_pins vpu_regs/clk]
connect_bd_net [get_bd_ports clk] [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_ports clk] [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_ports clk] [get_bd_pins data_bram_ctrl/s_axi_aclk]

connect_bd_net [get_bd_ports rst_n] [get_bd_pins axi_vip_master/aresetn]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins axi_interconnect_0/M00_ARESETN]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins axi_interconnect_0/M01_ARESETN]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins axi_interconnect_0/M02_ARESETN]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins inst_bram/rst_n]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins inst_decoder/rst_n]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins cdma_ctrl/rst_n]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins vpu_regs/rst_n]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins data_bram_ctrl/s_axi_aresetn]

# ============================================================================
# 地址分配
# ============================================================================
assign_bd_address

# ============================================================================
# 验证和保存
# ============================================================================
validate_bd_design
save_bd_design

# 生成输出
generate_target all [get_files sim_bd.bd]

puts "=========================================="
puts "仿真 Block Design 创建完成"
puts "=========================================="
