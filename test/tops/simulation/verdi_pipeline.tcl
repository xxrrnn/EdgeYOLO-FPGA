# Compact Verdi view: continuous input issue, arithmetic stages, checked output.
if {[llength [wvGetAllWindows]] == 0} {
    wvCreateWindow
}

wvAddGroup "ISSUE"
wvAddSignal -delim . \
    tb_dcim_pipeline_peak.clk \
    tb_dcim_pipeline_peak.IJ \
    tb_dcim_pipeline_peak.IP \
    tb_dcim_pipeline_peak.IM \
    tb_dcim_pipeline_peak.ID

wvAddGroup "PIPE"
wvAddSignal -delim . \
    tb_dcim_pipeline_peak.MV \
    tb_dcim_pipeline_peak.GV \
    tb_dcim_pipeline_peak.AV

wvAddGroup "RESULT"
wvAddSignal -delim . \
    tb_dcim_pipeline_peak.RV \
    tb_dcim_pipeline_peak.OJ \
    tb_dcim_pipeline_peak.OD \
    tb_dcim_pipeline_peak.EX

set pipeline_begin_ns 44
set pipeline_end_ns 190
if {[info exists ::env(PIPELINE_WAVE_BEGIN_NS)]} {
    set pipeline_begin_ns $::env(PIPELINE_WAVE_BEGIN_NS)
}
if {[info exists ::env(PIPELINE_WAVE_END_NS)]} {
    set pipeline_end_ns $::env(PIPELINE_WAVE_END_NS)
}
set pipeline_window [lindex [wvGetAllWindows] 0]
# This focused TB uses 1 ps FSDB precision (unlike the full-BD FSDB's 1 fs).
wvZoom -win $pipeline_window \
    [expr {$pipeline_begin_ns * 1000}] \
    [expr {$pipeline_end_ns * 1000}]
puts "PIPELINE_VERDI_VIEW_READY: issue/fill/steady-result signals loaded"
