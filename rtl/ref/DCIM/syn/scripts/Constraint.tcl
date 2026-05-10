# Reference: /data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/signoff/[2020.08.03] N22ULL v1.1 Sign-off Reference (1).pdf

# -----------------------------------------------------------------------------
# 1. 时钟定义与核心频率设置 (Target: 500MHz)
# -----------------------------------------------------------------------------
set T 2.0
create_clock -name "clk" -period $T [get_ports clk]

# 根据文档Page6/7 建议，Setup需要增加 y ns clock jitter
set_clock_uncertainty -setup 0.25 [get_clocks clk]
set_clock_uncertainty -hold 0.05  [get_clocks clk]

# 前期不要浪费时间综合时钟树，且别动时钟端口
set_ideal_network [get_ports clk]	
set_dont_touch [get_ports clk] true

# 输入输出延时
set_input_delay [expr $T * 0.4] -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay [expr $T * 0.4] -clock clk [all_outputs]



# -----------------------------------------------------------------------------
# 3. OCV Derate 设置 (V&T Margin) [依据文档 Page 14/16/18 表格]
# 	 更细致的分析在后端中完成
# -----------------------------------------------------------------------------
# 在 SSG 0.81V 125C 场景下 (Setup Check):
# OCV_v (Voltage) + OCV_t (Temperature) 综合余量:
# 工艺偏差通常取5%
set alpha_margin 0.05
set temp_margin 0.005
set volt_margin 0.014

# Setup: Late Path 变慢, Early Path 变快
set_timing_derate -cell_delay -late  [expr 1 + $alpha_margin]
set_timing_derate -cell_delay -early [expr 1 - $alpha_margin - $temp_margin - $volt_margin]



# -----------------------------------------------------------------------------
# 4. 驱动与负载约束 (SDC)
# -----------------------------------------------------------------------------
# 转换时间约束[文档21页]
# Max Data Slew  < min(T/3, default_max_transition) -> 2.0 / 3 = 0.66ns
# Max Clock Slew < min(T/6, default_max_transition) -> 2.0 / 6 = 0.33ns
set_max_transition [expr $T / 3] [current_design]
set_max_transition [expr $T / 6] -clock_path [get_clocks clk]

# 电容约束
set_max_capacitance 0.2 [current_design]

# 扇出约束
set_max_fanout 32 [current_design]

# 设置输入驱动（建议使用标准反相器 X4 或 X8 强度）
set_driving_cell					\
	-lib_cell INVSGD4BWP7T30P140	\
	-library tcbn22ullbwp7t30p140sgssg0p81v125c_ccs	\
	[remove_from_collection [all_inputs] [get_ports clk]]



# -----------------------------------------------------------------------------
# 5. 特殊处理: 开启约束波动计算 [依据文档 Page 29/31]
# -----------------------------------------------------------------------------
# 开启 Setup 约束的 RSS 模式（在低压或先进制程中非常重要）
set_app_var timing_enable_constraint_variation true



# -----------------------------------------------------------------------------
# 6. 特殊路径处理: SRAM工艺引脚固定取值（其他取值会产生延迟惩罚）
# -----------------------------------------------------------------------------
# set_case_analysis 0 [get_pins u_memory/u_sramWrap/u_rf/rawl]
# set_case_analysis 0 [get_pins u_memory/u_sramWrap/u_rf/wabl]
# set_case_analysis 1 [get_pins u_memory/u_sramWrap/u_rf/ret1n]


# BC - WC Setup / Hold Timing Analyze
set_operating_conditions -analysis_type bc_wc \
	-min "ffg0p99vm40c" -min_library tcbn22ullbwp7t30p140sgffg0p99vm40c_ccs\
	-max "ssg0p81v125c" -max_library tcbn22ullbwp7t30p140sgssg0p81v125c_ccs

set_leakage_optimization true
set_dynamic_optimization true
set CompileMapEffort high
set hdlin_check_on_latch true
set compile_delete_unloaded_sequential_cells true
set verilogout_no_tri true
set bus_naming_style {%s[%d]}

