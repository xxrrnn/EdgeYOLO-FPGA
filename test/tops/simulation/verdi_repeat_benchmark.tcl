if {[llength [wvGetAllWindows]] == 0} {
    wvCreateWindow
}

wvAddGroup "WHOLE_RUN"
wvAddSignal -delim . \
    tb_dcim_repeat_benchmark.clk \
    tb_dcim_repeat_benchmark.START \
    tb_dcim_repeat_benchmark.STATE \
    tb_dcim_repeat_benchmark.COMPUTE \
    tb_dcim_repeat_benchmark.DONE

wvAddGroup "SEAMLESS_ISSUE"
wvAddSignal -delim . \
    tb_dcim_repeat_benchmark.ROUND \
    tb_dcim_repeat_benchmark.JOB \
    tb_dcim_repeat_benchmark.PHASE \
    tb_dcim_repeat_benchmark.INPUT_DATA

wvAddGroup "PIPELINE_AND_RESULT"
wvAddSignal -delim . \
    tb_dcim_repeat_benchmark.MA_VALID \
    tb_dcim_repeat_benchmark.CORE_VALID \
    tb_dcim_repeat_benchmark.RESULT_VALID \
    tb_dcim_repeat_benchmark.RESULT_DATA

set begin_ns 0
set end_ns 2600
if {[info exists ::env(REPEAT_WAVE_BEGIN_NS)]} {
    set begin_ns $::env(REPEAT_WAVE_BEGIN_NS)
}
if {[info exists ::env(REPEAT_WAVE_END_NS)]} {
    set end_ns $::env(REPEAT_WAVE_END_NS)
}
set win [lindex [wvGetAllWindows] 0]
wvZoom -win $win [expr {$begin_ns * 1000}] [expr {$end_ns * 1000}]
puts "REPEAT_BENCHMARK_VERDI_READY"
