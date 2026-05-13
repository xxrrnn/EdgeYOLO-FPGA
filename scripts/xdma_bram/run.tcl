# XDMA BRAM full build entry point.
#
# This is the recommended script to source from Vivado Tcl:
#   source fpga/local/scripts/xdma_bram/run.tcl
#
# Keep the order fixed. 0_build creates a fresh project, 1_bd creates and
# validates the block design, and 2_synth generates IP products before running
# synthesis, implementation, and bitstream generation.

set thisScriptDir [file dirname [file normalize [info script]]]

source [file normalize "$thisScriptDir/0_build.tcl"]
source [file normalize "$thisScriptDir/1_bd.tcl"]
source [file normalize "$thisScriptDir/2_synth.tcl"]
