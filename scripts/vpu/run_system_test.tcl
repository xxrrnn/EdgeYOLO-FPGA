# Run system-level INST_Decoder + Global_VPU testbench
# Usage: vivado -mode batch -source scripts/vpu/run_system_test.tcl

open_project build/vpu/vpu.xpr

# Add testbench file
set tb_file "[pwd]/rtl/vpu/tb/tb_system_inst_decoder.sv"
catch {remove_files -fileset sim_1 $tb_file}
add_files -fileset sim_1 $tb_file

# Set simulation top
set_property top tb_system_inst_decoder [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Running system-level INST_Decoder + Global_VPU testbench..."
launch_simulation
run 5ms
close_sim -force

# Restore original top
set_property top tb_ad_unit [get_filesets sim_1]
update_compile_order -fileset sim_1

close_project
puts "System test complete!"
