# Run mp_unit_fixed and us_unit_fixed testbenches
# Usage: vivado -mode batch -source scripts/vpu/run_mp_us_tests.tcl

open_project build/vpu/vpu.xpr

set mp_tb "[pwd]/rtl/vpu/tb/tb_mp_unit_fixed.sv"
set us_tb "[pwd]/rtl/vpu/tb/tb_us_unit_fixed.sv"

catch {remove_files -fileset sim_1 $mp_tb}
catch {remove_files -fileset sim_1 $us_tb}
add_files -fileset sim_1 $mp_tb
add_files -fileset sim_1 $us_tb
update_compile_order -fileset sim_1

# Run MP test
puts "\n========== Running mp_unit_fixed testbench =========="
set_property top tb_mp_unit_fixed [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run 800us
close_sim -force

# Run US test
puts "\n========== Running us_unit_fixed testbench =========="
set_property top tb_us_unit_fixed [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run 2ms
close_sim -force

# Restore
set_property top tb_ad_unit [get_filesets sim_1]
update_compile_order -fileset sim_1
close_project
puts "\nAll MP/US tests complete!"
