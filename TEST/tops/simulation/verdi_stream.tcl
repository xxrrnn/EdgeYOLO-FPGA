# Unified streamed Tile: compact, explanatory waveform view.
if {[llength [wvGetAllWindows]] == 0} {
    wvCreateWindow
}

wvAddGroup "CONTROL"
wvAddSignal -delim . \
    tb_dcim_stream_tile.clk \
    tb_dcim_stream_tile.mode \
    tb_dcim_stream_tile.dut.state \
    tb_dcim_stream_tile.dut.row_index

wvAddGroup "DCIM_ISSUE"
wvAddSignal -delim . \
    tb_dcim_stream_tile.COMPUTE \
    tb_dcim_stream_tile.JOB \
    tb_dcim_stream_tile.PHASE \
    tb_dcim_stream_tile.INPUT_DATA

wvAddGroup "ARITH_PIPE"
wvAddSignal -delim . \
    tb_dcim_stream_tile.MA_VALID \
    tb_dcim_stream_tile.CORE_VALID

wvAddGroup "HOST_RESULT"
wvAddSignal -delim . \
    tb_dcim_stream_tile.RESULT_VALID \
    tb_dcim_stream_tile.RESULT_DATA

set stream_begin_ns 1500
set stream_end_ns 2200
if {[info exists ::env(STREAM_WAVE_BEGIN_NS)]} {
    set stream_begin_ns $::env(STREAM_WAVE_BEGIN_NS)
}
if {[info exists ::env(STREAM_WAVE_END_NS)]} {
    set stream_end_ns $::env(STREAM_WAVE_END_NS)
}
set stream_window [lindex [wvGetAllWindows] 0]
wvZoom -win $stream_window \
    [expr {$stream_begin_ns * 1000}] \
    [expr {$stream_end_ns * 1000}]
puts "STREAM_VERDI_VIEW_READY: control/issue/arithmetic/result signals loaded"
