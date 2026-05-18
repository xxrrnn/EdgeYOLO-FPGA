################################################################################
# add_axi_vip.tcl - 添加AXI VIP Master用于仿真
################################################################################

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

puts "================================================================"
puts "  添加 AXI VIP Master 到 BD"
puts "================================================================"

# 打开项目
open_project $projPath/$projName.xpr

# 打开Block Design
open_bd_design [get_files vpu.bd]

# 创建AXI VIP
puts "\n[1] 创建 AXI VIP Master..."
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vip:1.1 axi_vip_master

# 配置为Master模式
set_property -dict [list \
    CONFIG.INTERFACE_MODE {MASTER} \
    CONFIG.PROTOCOL {AXI4LITE} \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {32} \
] [get_bd_cells axi_vip_master]

puts "    ✓ AXI VIP创建完成"

# 注意：我们不改变原有连接，AXI VIP仅作为可选的仿真驱动器
# 在testbench中，我们将使用层次化访问来选择驱动源

puts "\n[2] 连接AXI VIP..."

# 连接时钟和复位
connect_bd_net [get_bd_pins axi_vip_master/aclk] \
               [get_bd_pins xdma_0/axi_aclk]

connect_bd_net [get_bd_pins axi_vip_master/aresetn] \
               [get_bd_pins xdma_0/axi_aresetn]

# 注意：M_AXI端口暂时悬空，在仿真testbench中通过层次化访问连接
puts "    ✓ AXI VIP时钟/复位连接完成"
puts "    注意：M_AXI端口将在仿真testbench中通过force连接"

# 验证地址分配
puts "\n[3] 验证地址分配..."
validate_bd_design

# 保存并生成输出
puts "\n[4] 保存BD并生成..."
save_bd_design

generate_target all [get_files vpu.bd]
export_ip_user_files -of_objects [get_files vpu.bd] -no_script -sync -force -quiet

puts "\n================================================================"
puts "  ✓ AXI VIP 添加完成!"
puts "  
puts "  接下来运行 2_sim.tcl 进行仿真"
puts "================================================================\n"

close_project
