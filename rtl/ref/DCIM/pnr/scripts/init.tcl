# ----------------------------------------------------------
# 1. Set the LEF File
# ----------------------------------------------------------
set TechLEF "/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/Doc/CL-PR/PRTF_Innovus_22nm_001_Cad_V11_1a/PR_tech/Cadence/LefHeader/HVH/PRTF_Innovus_22nm_9M_6X1Z1UUTRDL_9T.11_1a.tlef"
set StdCellLEF [list \
	"/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sg_110b/digital/Back_End/lef/tcbn22ullbwp7t30p140sg_110a/lef/tcbn22ullbwp7t30p140sg.lef"				\
	"/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sglvt_110b/digital/Back_End/lef/tcbn22ullbwp7t30p140sglvt_110a/lef/tcbn22ullbwp7t30p140sglvt.lef"	\
	"/data/data_eda2/PDK_Tech/TSMC_22NM_RF_ULL/IP/Std_Cell/tcbn22ullbwp7t30p140sghvt_110b/digital/Back_End/lef/tcbn22ullbwp7t30p140sghvt_110a/lef/tcbn22ullbwp7t30p140sghvt.lef"	\
]
set SRAMLEF [list \
	"/data/home/za_xiao31/workplace/DCIM/src/sram/rf128x128/lef/rf128x128.lef"\
	"/data/home/za_xiao31/workplace/DCIM/src/sram/rf64x128/lef/rf64x128.lef"\
	"/data/home/za_xiao31/workplace/DCIM/src/sram/rf64x64/lef/rf64x64.lef"\
]


# ----------------------------------------------------------
# 2. Initialize Innovus
# ----------------------------------------------------------
set TopName "dcim_wrapper"
set MMMCFile "./scripts/mmmc.tcl"
set init_lef_file [concat $TechLEF $StdCellLEF $SRAMLEF]
set init_verilog "/data/home/za_xiao31/workplace/DCIM/pnr/src/${TopName}_syn.v"
set init_top_cell ${TopName}
set init_mmmc_file ${MMMCFile}
set init_pwr_net {VDD VDD_SRAM}
set init_gnd_net {VSS}
set init_design_uniquify {1}
setMultiCpuUsage -localCpu 64 -remoteHost 0 -keepLicense true
init_design

# Macro Alias.
set rf "u_dcim/u_memory/u_sramWrap/u_rf"
set rfact "u_axi_bridge/u_act_sequencer/u_act_buffer/u_rf_act"
set rfresH "u_axi_bridge/u_res_fifo/u_buffer_res/u_rf_res_H"
set rfresL "u_axi_bridge/u_res_fifo/u_buffer_res/u_rf_res_L"
