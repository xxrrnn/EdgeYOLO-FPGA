# Debug QA state machine
open_project build/vpu/vpu.xpr
set_property top tb_qa_unit [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run 2us
puts "=== After 2us ==="
puts "c_state = [get_value /tb_qa_unit/dut/c_state]"
puts "qa_done = [get_value /tb_qa_unit/dut/qa_done]"
puts "qa_x_load_done = [get_value /tb_qa_unit/dut/qa_x_load_done]"
puts "qa_x_load_block_done = [get_value /tb_qa_unit/dut/qa_x_load_block_done]"
puts "qa_save_done = [get_value /tb_qa_unit/dut/qa_save_done]"
puts "qa_x_load_cnt = [get_value -radix dec /tb_qa_unit/dut/qa_x_load_cnt]"
puts "qa_x_load_block_cnt = [get_value -radix dec /tb_qa_unit/dut/qa_x_load_block_cnt]"
puts "qa_save_cnt = [get_value -radix dec /tb_qa_unit/dut/qa_save_cnt]"
puts "qa_x_total_blocks = [get_value -radix dec /tb_qa_unit/dut/qa_x_total_blocks]"
puts "qa_single_compute_blocks = [get_value -radix dec /tb_qa_unit/dut/qa_single_compute_blocks]"
puts "qa_single_compute_save_blocks = [get_value -radix dec /tb_qa_unit/dut/qa_single_compute_save_blocks]"
run 500ns
puts "=== After 2.5us ==="
puts "c_state = [get_value /tb_qa_unit/dut/c_state]"
puts "qa_save_cnt = [get_value -radix dec /tb_qa_unit/dut/qa_save_cnt]"
close_sim -force
close_project
