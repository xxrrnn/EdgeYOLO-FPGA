# Setup Synthesis Variables
set WORK_DIR        "./work"

# Library Path
set PATH_SG_7T_SVT	"/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sg_110b/digital/Front_End/timing_power_noise/CCS/tcbn22ullbwp7t30p140sg_110b"
set PATH_SG_7T_LVT  "/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sglvt_110b/digital/Front_End/timing_power_noise/CCS/tcbn22ullbwp7t30p140sglvt_110b"
set PATH_SG_7T_HVT	"/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sghvt_110b/digital/Front_End/timing_power_noise/CCS/tcbn22ullbwp7t30p140sghvt_110b"
set PATH_RF128x128		"/data/home/za_xiao31/workplace/DCIM/src/sram/rf128x128/db"
set PATH_RF64x128		"/data/home/za_xiao31/workplace/DCIM/src/sram/rf64x128/db"
set PATH_RF64x64		"/data/home/za_xiao31/workplace/DCIM/src/sram/rf64x64/db"


set search_path [concat $search_path [list \
	$PATH_SG_7T_SVT \
	$PATH_SG_7T_LVT \
	$PATH_SG_7T_HVT \
	$PATH_RF128x128	\
	$PATH_RF64x128	\
	$PATH_RF64x64	]]

# Multi Corner 
# Target Voltage: 0.8V; Target Frequence: 500MHz;
# -----------------------------------------------------------------------------
# 场景A (Max/Setup): 最慢环境 (SSG, 0.81V, 125C) -> 用于检查建立时间
# 包含 LVT, SVT, HVT 三种阈值，让工具挑选
# -----------------------------------------------------------------------------
set DB_LVT_SSG			"tcbn22ullbwp7t30p140sglvtssg0p81v125c_hm_ccs.db"
set DB_SVT_SSG			"tcbn22ullbwp7t30p140sgssg0p81v125c_hm_ccs.db"
set DB_HVT_SSG			"tcbn22ullbwp7t30p140sghvtssg0p81v125c_hm_ccs.db"
set DB_RF128x128_SSG	"rf128x128_ssg_cworstt_0p81v_0p81v_125c.db"
set DB_RF64x128_SSG		"rf64x128_ssg_cworstt_0p81v_0p81v_125c.db"
set DB_RF64x64_SSG		"rf64x64_ssg_cworstt_0p81v_0p81v_125c.db"

## -----------------------------------------------------------------------------
## 场景B (Min/Hold): 最快环境 (FFG, 0.99V, -40C) -> 用于检查保持时间
## -----------------------------------------------------------------------------
set DB_LVT_FFG			"tcbn22ullbwp7t30p140sglvtffg0p99vm40c_hm_ccs.db"
set DB_SVT_FFG			"tcbn22ullbwp7t30p140sgffg0p99vm40c_hm_ccs.db"
set DB_HVT_FFG			"tcbn22ullbwp7t30p140sghvtffg0p99vm40c_hm_ccs.db"
set DB_RF128x128_FFG	"rf128x128_ffg_cbestt_0p99v_0p99v_m40c.db"
set DB_RF64x128_FFG		"rf64x128_ffg_cbestt_0p99v_0p99v_m40c.db"
set DB_RF64x64_FFG		"rf64x64_ffg_cbestt_0p99v_0p99v_m40c.db"

# -----------------------------------------------------------------------------
# 场景C (Typical/Setup): Typical 环境 (TT, 0.9V, 25C) -> 用于输出标准延迟
# 包LVT, SVT, HVT 三种阈值，让工具挑选
# -----------------------------------------------------------------------------
# set DB_LVT_TT			"tcbn22ullbwp7t30p140sglvttt0p9v25c_hm_ccs.db"
# set DB_SVT_TT			"tcbn22ullbwp7t30p140sgtt0p9v25c_hm_ccs.db"
# set DB_HVT_TT			"tcbn22ullbwp7t30p140sghvttt0p9v25c_hm_ccs.db"
# set DB_RF128x128_TT	"rf128x128_tt_typical_0p90v_0p90v_25c.db"
# set DB_RF64x128_TT	"rf64x128_tt_typical_0p90v_0p90v_25c.db"
# set DB_RF64x64_TT		"rf64x64_tt_typical_0p90v_0p90v_25c.db"

set_min_library $DB_LVT_SSG 		-min_version	$DB_LVT_FFG
set_min_library $DB_SVT_SSG 		-min_version	$DB_SVT_FFG
set_min_library $DB_HVT_SSG			-min_version	$DB_HVT_FFG
set_min_library $DB_RF128x128_SSG	-min_version	$DB_RF128x128_FFG
set_min_library $DB_RF64x128_SSG	-min_version	$DB_RF64x128_FFG
set_min_library $DB_RF64x64_SSG		-min_version	$DB_RF64x64_FFG

# Multi-Vt
# target_library: 综合工具可以将逻辑映射到这些库里的单元
set target_library  [list 	\
	$DB_LVT_SSG 			\
	$DB_SVT_SSG				\
	$DB_HVT_SSG				\
	$DB_RF128x128_SSG		\
	$DB_RF64x128_SSG		\
	$DB_RF64x64_SSG]

set HOLD_LIB [list 			\
	$DB_LVT_FFG				\
	$DB_SVT_FFG				\
	$DB_HVT_FFG				\
	$DB_RF128x128_FFG		\
	$DB_RF64x128_FFG		\
	$DB_RF64x64_FFG]

set synthetic_library [list dw_foundation.sldb]

set link_library [concat * $target_library $HOLD_LIB $synthetic_library]
