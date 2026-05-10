####################################################################################
# 文件名: integrated_floorplan.tcl
####################################################################################

# ==========================================
# 第一阶段: 创建版图区域Floorplan
# ==========================================
# 设置芯片的总宽度和高度 (单位通常为微米 um)
set die_sizex 260
set die_sizey 260

# floorPlan 命令用于初始化设计区域 
# -d: 指定 Die 的尺寸 ($die_sizex $die_sizey)
# 后四个参数 {10 10 10 10} 分别代表 Core 到 Die 边界的间距 (左 下 右 上)
floorPlan -d $die_sizex $die_sizey 10 10 10 10


# ==========================================
# 第二阶段: 摆放硬核Macro Pre-place
# ==========================================
# 定义 Macro 的别名，方便后续脚本引用 
set sram $sram_inst

# placeInstance 用于手动指定 Macro 的坐标和朝向 
# 格式: placeInstance 实例名 X坐标 Y坐标 [朝向]
# 这里的坐标 (120, 20) 是 Macro 的左下角位置 
placeInstance sram_inst 120 20


# ==========================================
# 第三阶段: 设置保护区与布线阻断 (Halo & Blockage)
# ==========================================
# 1. 添加 Halo (光环区): 防止标准单元摆放在 Macro 边缘太近，以缓解拥塞 
# 这里使用 $macro_halo_spc_4 (在 global_define.tcl 定义) 作为四个方向的间距 
# -allMacro 会应用到设计中所有的硬核上 
addHaloToBlock [list $macro_halo_spc_4 $macro_halo_spc_4 $macro_halo_spc_4 $macro_halo_spc_4] -allMacro

# 2. 创建布线阻断 (Routing Blockage): 防止信号线走在 Macro 上方的特定金属层 
# 对于 DCO，阻断 M1 到 M6 层，防止噪声干扰 
# -cover: 阻断区域等同于实例大小 
# -exceptpgnet: 允许电源和地线 (PG) 走线，只阻断信号线 
# -spacing: 在阻断区边缘留出一定的间距 
# set macro_domain [list dco_inst]
# foreach {macro_inst} $macro_domain {
#    createRouteBlk -cover -inst $macro_inst -exceptpgnet -layer {M1 M2 M3 M4 M5 M6} -spacing $macro_halo_spc
#}
# 对于 SRAM，通常金属层资源较多，这里阻断 M1 到 M4 层 
createRouteBlk -cover -inst sram_inst -exceptpgnet -layer {M1 M2 M3 M4} -spacing $macro_halo_spc [cite: 15]

# ==========================================
# 第四阶段: 放置引脚 (Pin Assignment)
# ==========================================
# 开启批量编辑模式，提高大量引脚处理的效率 
setPinAssignMode -pinEditInBatch true

# editPin 命令详解:
# -pinWidth / -pinDepth: 引脚的物理尺寸 
# -layer: 指定引脚所在的金属层 (层数越高，电阻通常越小) 
# -side / -edge: 指定放置在芯片的哪一边 (Left=0, Top=1, Right=2, Bottom=3) 
# -spreadType center/start: 引脚在边沿的排布方式 
# -spacing: 引脚中心之间的距离 
# 1. 放置左侧引脚 (DCO 控制信号) 
editPin -pinWidth 0.05 -pinDepth 0.34 -fixOverlap 1 -unit MICRON -spreadDirection clockwise \
	-side Left -layer 5 -spreadType center -spacing 10	\
	-pin {}

# 2. 放置顶侧引脚 (IRQ 中断信号) 
editPin -pinWidth 0.05 -pinDepth 0.34 -fixOverlap 1 -unit MICRON -spreadDirection clockwise \
	-side Up -layer 4 -spreadType start -spacing 6 -offsetStart 15 \
	-pin {}
# 3. 放置底侧引脚 (复位与 Trap 信号) 
editPin -pinWidth 0.05 -pinDepth 0.34 -fixOverlap 1 -unit MICRON -spreadDirection counterclockwise \
	-edge 3 -layer 4 -spreadType start -spacing 30.0 -offsetStart 30\ 
	-pin {}

# 4. 退出批量模式
setPinAssignMode -pinEditInBatch false
