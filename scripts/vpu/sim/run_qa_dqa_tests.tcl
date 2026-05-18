# Run qa_unit and dqa_unit testbenches
# Usage: vivado -mode batch -source scripts/vpu/run_qa_dqa_tests.tcl

open_project build/vpu/vpu.xpr

# Add QA testbench
set qa_tb_file "[pwd]/rtl/vpu/tb/tb_qa_unit.sv"
set dqa_tb_file "[pwd]/rtl/vpu/tb/tb_dqa_unit.sv"

# Remove existing sim filesets if present (to avoid duplicates)
catch {remove_files -fileset sim_1 $qa_tb_file}
catch {remove_files -fileset sim_1 $dqa_tb_file}

# Add the testbench files
add_files -fileset sim_1 $qa_tb_file
add_files -fileset sim_1 $dqa_tb_file

# Update compile order
update_compile_order -fileset sim_1

# Set QA as top for first test
set_property top tb_qa_unit [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Running qa_unit testbench..."
launch_simulation
run 2ms
close_sim -force

# Now run DQA test
set_property top tb_dqa_unit [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Running dqa_unit testbench..."
launch_simulation
run 500us
close_sim -force

# Restore original top
set_property top tb_ad_unit [get_filesets sim_1]
update_compile_order -fileset sim_1

close_project
puts "All QA/DQA tests complete!"
