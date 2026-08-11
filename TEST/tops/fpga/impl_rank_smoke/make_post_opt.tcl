set scriptDir [file dirname [file normalize [info script]]]
set repoRoot [file normalize "$scriptDir/../../../.."]
set tag "impl_rank_smoke"
if {$argc >= 1 && [string trim [lindex $argv 0]] ne ""} {
    set tag [string trim [lindex $argv 0]]
}
set outDir [file normalize "$repoRoot/build/lite/$tag/ImplOutputDir"]
file mkdir $outDir

set part "xcvu37p-fsvh2892-2L-e"
read_verilog -sv [file normalize "$scriptDir/mini_rank_top.sv"]
read_xdc [file normalize "$scriptDir/mini_rank.xdc"]
synth_design -mode out_of_context -top mini_rank_top -part $part
opt_design -directive ExploreWithRemap
write_checkpoint -force [file normalize "$outDir/post_opt.dcp"]
report_timing_summary -file [file normalize "$outDir/post_opt_timing_summary.rpt"]
report_utilization -file [file normalize "$outDir/post_opt_util.rpt"]
puts "SMOKE_POST_OPT=$outDir/post_opt.dcp"
