source [file normalize "./config.tcl"]
open_project "$projPath/$projName.xpr"
open_bd_design [get_files "${bdName}.bd"]
set result [validate_bd_design -force]
puts "VALIDATE_RESULT: $result"
set num_si [get_property CONFIG.NUM_SI [get_bd_cells axi_mem_smc]]
set num_mi [get_property CONFIG.NUM_MI [get_bd_cells axi_mem_smc]]
puts "SmartConnect: NUM_SI=$num_si NUM_MI=$num_mi"
exit $result
