# XDMA + DCIM + HBM block-design build entry point.
#
# This stops after 1_bd.tcl, so it validates the BD without running synthesis,
# implementation, or bitstream generation.

set thisScriptDir [file dirname [file normalize [info script]]]

source [file normalize "$thisScriptDir/0_build.tcl"]
source [file normalize "$thisScriptDir/1_bd.tcl"]
