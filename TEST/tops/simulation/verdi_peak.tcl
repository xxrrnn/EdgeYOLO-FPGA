# Focused VCS/FSDB view for the INT8 peak-compute proof.
# The signals are TB-top aliases, so this list is independent of BD hierarchy.

if {[llength [wvGetAllWindows]] == 0} {
    wvCreateWindow
}

set peak_wave_window [lindex [wvGetAllWindows] 0]
# One short group per trace keeps the presentation labels readable in the
# fixed-width signal pane used by the automatic screenshot flow.
foreach {peak_group peak_signal} {
    CLK       tb_lite_bd_module.tb_aclk
    START     tb_lite_bd_module.peak_int8_array_start
    DONE      tb_lite_bd_module.peak_int8_array_done
    MASK8     tb_lite_bd_module.peak_int8_compute_fire
    STATE     tb_lite_bd_module.peak_int8_tile0_state
    ROUND     tb_lite_bd_module.peak_int8_tile0_round
    JOB       tb_lite_bd_module.peak_int8_tile0_job
    PHASE     tb_lite_bd_module.peak_int8_tile0_phase
    INPUT     tb_lite_bd_module.peak_int8_tile0_input
    RVALID    tb_lite_bd_module.peak_int8_result_valid
    RESULT    tb_lite_bd_module.peak_int8_result_data
} {
    wvAddGroup $peak_group
    wvAddSignal -win $peak_wave_window -delim . $peak_signal
}

wvZoomAll

# Default to the compact compute/result evidence window. Override in an
# interactive session with PEAK_WAVE_BEGIN_NS / PEAK_WAVE_END_NS if desired.
set peak_begin_ns 2300
set peak_end_ns   4600
if {[info exists ::env(PEAK_WAVE_BEGIN_NS)]} {
    set peak_begin_ns $::env(PEAK_WAVE_BEGIN_NS)
}
if {[info exists ::env(PEAK_WAVE_END_NS)]} {
    set peak_end_ns $::env(PEAK_WAVE_END_NS)
}
# nWave's command API uses the FSDB precision (1 fs here), whereas the user
# facing knobs above are nanoseconds.
set peak_begin_fs [expr {$peak_begin_ns * 1000000}]
set peak_end_fs   [expr {$peak_end_ns * 1000000}]
wvZoom -win $peak_wave_window $peak_begin_fs $peak_end_fs
puts "PEAK_VERDI_VIEW_READY: 11 focused signals loaded"
