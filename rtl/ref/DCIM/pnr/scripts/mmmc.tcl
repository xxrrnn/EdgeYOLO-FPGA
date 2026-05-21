# 1. 定义库集合 (Library Sets) ---
# 将之前整理好的 .lib 列表直接关联到 Corner 名称上
set PATH_SG_7T_SVT		"/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sg_110b/digital/Front_End/timing_power_noise/CCS/tcbn22ullbwp7t30p140sg_110b"
set PATH_SG_7T_LVT  	"/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sglvt_110b/digital/Front_End/timing_power_noise/CCS/tcbn22ullbwp7t30p140sglvt_110b"
set PATH_SG_7T_HVT		"/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sghvt_110b/digital/Front_End/timing_power_noise/CCS/tcbn22ullbwp7t30p140sghvt_110b"
set PATH_SRAM128x128	"/data/home/za_xiao31/workplace/DCIM/src/sram/rf128x128/lib"
set PATH_SRAM64x128		"/data/home/za_xiao31/workplace/DCIM/src/sram/rf64x128/lib"
set PATH_SRAM64x64		"/data/home/za_xiao31/workplace/DCIM/src/sram/rf64x64/lib"

create_library_set -name lib_tt -timing [list 								\
	"${PATH_SG_7T_SVT}/tcbn22ullbwp7t30p140sgtt0p9v25c_hm_ccs.lib"			\
	"${PATH_SG_7T_LVT}/tcbn22ullbwp7t30p140sglvttt0p9v25c_hm_ccs.lib"		\
	"${PATH_SG_7T_HVT}/tcbn22ullbwp7t30p140sghvttt0p9v25c_hm_ccs.lib"		\
	"${PATH_SRAM128x128}/rf128x128_tt_typical_0p90v_0p90v_25c.lib"			\
	"${PATH_SRAM64x128}/rf64x128_tt_typical_0p90v_0p90v_25c.lib"			\
	"${PATH_SRAM64x64}/rf64x64_tt_typical_0p90v_0p90v_25c.lib"				\
]
create_library_set -name lib_ss -timing [list 								\
	"${PATH_SG_7T_SVT}/tcbn22ullbwp7t30p140sgssg0p81v125c_hm_ccs.lib"		\
	"${PATH_SG_7T_LVT}/tcbn22ullbwp7t30p140sglvtssg0p81v125c_hm_ccs.lib"	\
	"${PATH_SG_7T_HVT}/tcbn22ullbwp7t30p140sghvtssg0p81v125c_hm_ccs.lib"	\
	"${PATH_SRAM128x128}/rf128x128_ssg_cworstt_0p81v_0p81v_125c.lib"		\
	"${PATH_SRAM64x128}/rf64x128_ssg_cworstt_0p81v_0p81v_125c.lib"			\
	"${PATH_SRAM64x64}/rf64x64_ssg_cworstt_0p81v_0p81v_125c.lib"			\
]
create_library_set -name lib_ff -timing [list								\
	"${PATH_SG_7T_SVT}/tcbn22ullbwp7t30p140sgffg0p99vm40c_hm_ccs.lib"		\
	"${PATH_SG_7T_LVT}/tcbn22ullbwp7t30p140sglvtffg0p99vm40c_hm_ccs.lib"	\
	"${PATH_SG_7T_HVT}/tcbn22ullbwp7t30p140sghvtffg0p99vm40c_hm_ccs.lib"	\
	"${PATH_SRAM128x128}/rf128x128_ffg_cbestt_0p99v_0p99v_m40c.lib"			\
	"${PATH_SRAM64x128}/rf64x128_ffg_cbestt_0p99v_0p99v_m40c.lib"			\
	"${PATH_SRAM64x64}/rf64x64_ffg_cbestt_0p99v_0p99v_m40c.lib"				\
]


# 2. 定义 RC 寄生参数角 (RC Corners) ---
# 关联不同温度和电容条件的 qrcTechFile
create_rc_corner -name rc_typ -qx_tech_file "/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/PDK/PDK_0.8V_2.5V_1P9M_6X1Z1U_UT_ALRDL_StarRC_QRC/QRC/RC_QRC_cln22ulp_1p09m+ut-alrdl_6x1z1u_typical/qrcTechFile" -T 25
create_rc_corner -name rc_best -qx_tech_file "/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/PDK/PDK_0.8V_2.5V_1P9M_6X1Z1U_UT_ALRDL_StarRC_QRC/QRC/RC_QRC_cln22ulp_1p09m+ut-alrdl_6x1z1u_rcbest_T/qrcTechFile" -T -40
create_rc_corner -name rc_worst -qx_tech_file "/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/PDK/PDK_0.8V_2.5V_1P9M_6X1Z1U_UT_ALRDL_StarRC_QRC/QRC/RC_QRC_cln22ulp_1p09m+ut-alrdl_6x1z1u_rcworst_T/qrcTechFile" -T 125

# 3. 自定义工况（因为库与库之间的工况名称可能并不统一）
# 如果每一个corner下是单一库，直接在create_delay_corner后面指定-opcond <lib文件中的名称>即可
# create_opcond -name OPTT -process 1.0 -voltage 0.90 -temperature 25
# create_opcond -name OPSS -process 1.0 -voltage 0.81 -temperature 125
# create_opcond -name OPFF -process 1.0 -voltage 0.99 -temperature -40


# 3. 定义延迟角 (Delay Corners) ---
# 将 [逻辑库] 与 [RC 参数] 绑定在一起
create_delay_corner -name delay_tt_typ   -library_set lib_tt -rc_corner rc_typ	 
create_delay_corner -name delay_ff_best  -library_set lib_ff -rc_corner rc_best
create_delay_corner -name delay_ss_worst -library_set lib_ss -rc_corner rc_worst


# 4. 定义约束模式 (Constraint Modes) ---
# 读取 SDC 时序约束文件
create_constraint_mode -name mode_func -sdc_files "/data/home/za_xiao31/workplace/DCIM/pnr/src/${TopName}_syn.sdc"


# 5. 定义分析视图 (Analysis Views) ---
# 最终用于分析的视图：[延迟角] + [约束模式]
create_analysis_view -name func_tt_typ	 -constraint_mode mode_func -delay_corner delay_tt_typ 
create_analysis_view -name func_ff_best	 -constraint_mode mode_func	-delay_corner delay_ff_best 
create_analysis_view -name func_ss_worst -constraint_mode mode_func -delay_corner delay_ss_worst


# 6. 设置当前分析目标 ---
# 告诉工具：用哪个视图查 Setup，哪个视图查 Hold
set_analysis_view -setup [list func_ss_worst] -hold [list func_ff_best]
