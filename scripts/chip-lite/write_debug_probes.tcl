# Generate a Hardware Manager probe map from an implemented checkpoint.
#
# Usage:
#   vivado -mode batch -source scripts/chip-lite/write_debug_probes.tcl \
#     -tclargs <post_route.dcp> <top.ltx>

if {$argc != 2} {
    puts stderr "Usage: write_debug_probes.tcl <implemented.dcp> <output.ltx>"
    exit 2
}

set input_dcp [file normalize [lindex $argv 0]]
set output_ltx [file normalize [lindex $argv 1]]

if {![file isfile $input_dcp]} {
    puts stderr "ERROR: implemented checkpoint not found: $input_dcp"
    exit 2
}

file mkdir [file dirname $output_ltx]
open_checkpoint $input_dcp

set debug_cores [get_debug_cores -quiet]
if {[llength $debug_cores] == 0} {
    puts stderr "ERROR: no debug cores found in checkpoint: $input_dcp"
    close_design
    exit 3
}

write_debug_probes -force $output_ltx
puts "INFO: wrote [llength $debug_cores] debug core(s) to $output_ltx"
close_design
exit 0
