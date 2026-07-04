# 修改命名规则，使其符合 Verilog 标准
change_names -rules verilog -hierarchy

file mkdir ./output/
# 写入网表 (Netlist)
write_file -format verilog -hierarchy -output ./output/${DESIGN_NAME}_syn.v
# 写入 DDC (数据库)
write_file -format ddc     -hierarchy -output ./output/${DESIGN_NAME}_syn.ddc
# 写入 SDC (约束)
write_sdc -nosplit ./output/${DESIGN_NAME}_syn.sdc
# 生成报告
file mkdir ./report/
report_timing -delay max -max_paths 20 -significant_digits 3 > ./report/timing_setup.rpt
report_timing -delay min -max_paths 20 -significant_digits 3 > ./report/timing_hold.rpt
report_power                           > ./report/power.rpt
report_power -hierarchy -nosplit	   > ./report/power_hierarchy.rpt
report_area                            > ./report/area.rpt
report_area -hierarchy -nosplit        > ./report/area_hierarchy.rpt
report_ref -hierarchy -nosplit		   > ./report/ref_hierarchy.rpt
report_qor 							   > ./report/qor_summary.rpt

report_constraint -all_violators -nosplit	> ./report/all_violators.rpt
report_constraint -max_transition  		  	> ./report/drc_transition.rpt
report_constraint -max_capacitance 			> ./report/drc_capacitance.rpt
report_constraint -max_fanout      			> ./report/drc_fanout.rpt
report_net -nosplit 						> ./report/net.rpt

check_timing				> 	./report/check_timing.rpt
