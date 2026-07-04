# One-time Xilinx simulation library compile for Synopsys VCS.
# Usage (from repo root, ~30-60 min):
#   vivado -mode batch -source scripts/sim/compile_xilinx_vcs_lib.tcl
#
# Output default: /data/home/rn_xu29/Tools/vcs_lib
# Point standalone sim at it with: export XILINX_VCS_LIB=/path/to/vcs_lib

set vivado_home [file normalize $::env(VIVADO_HOME)]
if {![file isdirectory $vivado_home]} {
  set vivado_home /home/EDAtools/Xilinx/Vivado/2024.2
}

set out_dir /data/home/rn_xu29/Tools/vcs_lib
file mkdir $out_dir

puts "INFO: compile_simlib for VCS -> $out_dir"
# Vivado 2024.2: -directory (not -dir / -simulator_lib_path)
compile_simlib -simulator vcs \
  -directory $out_dir \
  -family all \
  -language all \
  -library all \
  -force

puts "INFO: done. Export XILINX_VCS_LIB=$out_dir before running VCS standalone sim."
