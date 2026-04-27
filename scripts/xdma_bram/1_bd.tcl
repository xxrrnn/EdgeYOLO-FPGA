# create block design
set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists xdmaBramScriptDir]} {
    source [file normalize "$thisScriptDir/0_build.tcl"]
}

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {[llength [get_files -quiet $bdFile]] != 0} {
    remove_files $bdFile
}
if {[file exists [file dirname $bdFile]]} {
    file delete -force [file dirname $bdFile]
}

create_bd_design -dir $bdDir $bdName

source [file normalize "$ipBdDir/xdma.tcl"]
source [file normalize "$ipBdDir/bram.tcl"]
source [file normalize "$ipBdDir/connect.tcl"]

# address edit
set_property offset 0x10000000 [get_bd_addr_segs {xdma_0/M_AXI/SEG_axi_bram_ctrl_0_Mem0}]

validate_bd_design
regenerate_bd_layout
save_bd_design

# Generate BD output products and IP user files. The top-level synthesis later
# depends on the generated BD/IP files and the OOC IP checkpoints.
generate_target all [get_files $bdFile]
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force -quiet

# Create out-of-context synthesis runs for all IP instances inside this BD.
# Without these DCPs, top-level synth_design can fail with "DCP does not exist".
create_ip_run [get_files -of_objects [get_fileset sources_1] $bdFile]
set ipSynthRuns [get_runs -quiet ${bdName}_*_synth_1]
if {[llength $ipSynthRuns] > 0} {
    launch_runs $ipSynthRuns -jobs [get_param general.maxThreads]
    foreach ipRun $ipSynthRuns {
        wait_on_run $ipRun
        set runStatus [get_property STATUS [get_runs $ipRun]]
        if {![string match "*Complete*" $runStatus]} {
            error "IP synthesis run $ipRun failed: $runStatus"
        }
    }
}

# Export simulation scripts for the BD/IPs. This is not required for bitstream
# generation, but keeps the project-generated IP user files complete.
export_simulation \
  -of_objects [get_files $bdFile] \
  -directory [file normalize "$projPath/${projName}.ip_user_files/sim_scripts"] \
  -ip_user_files_dir [file normalize "$projPath/${projName}.ip_user_files"] \
  -ipstatic_source_dir [file normalize "$projPath/${projName}.ip_user_files/ipstatic"] \
  -use_ip_compiled_libs \
  -force \
  -quiet

# Generate and add the BD top wrapper used by 2_synth.tcl.
make_wrapper -files [get_files $bdFile] -top
add_files -norecurse [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]

set topName "${bdName}_wrapper"
update_compile_order -fileset sources_1
