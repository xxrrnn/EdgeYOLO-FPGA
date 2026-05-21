#####################################################################################
# Description:  Innovus Clock Tree Synthesis Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################

# update clock timing constraint for CTS
set_interactive_constraint_modes [all_constraint_modes -active]
source ../../config/cts_constraints_${rm_core_top}.sdc
set_interactive_constraint_modes {}

# create a clock tree network, can be removed by `delete_ccopt_clock_tree_spec`
create_ccopt_clock_tree_spec -file ../scripts/clock_tree/ccopt_cts_spec.tcl
source ../scripts/clock_tree/ccopt_cts_spec.tcl

# perform clock concurrent optimization (CCOpt), optimize both the clock tree and the datapath
# check_prerequisites: check that all prerequisites for running clock tree synthesis are fulfilled without actually doing CTS
clock_opt_design -check_prerequisites
clock_opt_design
# using ccopt command will raise ERROR "The input db is PODv2. Please try clock_opt_design."

# update clock timing constraint for post-CTS
# cause all clock endpoints in the fanout of the specified object to receive propagated clock timing unless there is a set_clock_latency with higher precedence
set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [list clk]
set_interactive_constraint_modes {}

# optimize drv, setup and hold
optDesign -outDir       ../${rm_core_top}/reports/postCTS -postCTS -drv
optDesign -outDir       ../${rm_core_top}/reports/postCTS -postCTS -incr
optDesign -outDir       ../${rm_core_top}/reports/postCTS -postCTS -hold \
          -holdVioData  ../${rm_core_top}/reports/postCTS/holdVio
exec ../scripts/extract_report.csh ../${rm_core_top}/reports/postCTS

# report clocks
report_ccopt_clock_trees -filename ../${rm_core_top}/reports/postCTS/clockopt.clock_trees
report_ccopt_skew_groups -filename ../${rm_core_top}/reports/postCTS/clockopt.skew_groups
report_ccopt_clock_tree_structure -file ../${rm_core_top}/reports/postCTS/clockopt.clock_tree_structure

