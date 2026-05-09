#-----------------------------------------------------------------------------
# run_pcie_sim.tcl
#
# Vivado TCL script to run PCIe-level simulation for XDMA DCIM HBM.
# This script compiles the design and testbench, then runs simulation.
#
# Usage:
#   vivado -mode batch -source rtl/tb/xdma_dcim_hbm/run_pcie_sim.tcl
#
# Or from Vivado GUI:
#   source rtl/tb/xdma_dcim_hbm/run_pcie_sim.tcl
#-----------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize "$script_dir/../../.."]

# Source directories
set xdma_dir "$repo_root/rtl/xdma_dcim_bram"
set dcim_dir "$repo_root/rtl/DCIM/src/dcim"
set dcim_inc_dir "$repo_root/rtl/DCIM/src/inc"
set ref_dcim_dir "$repo_root/rtl/ref/DCIM/src/dcim"
set ref_inc_dir "$repo_root/rtl/ref/DCIM/src/inc"
set tb_dir "$script_dir"

# Simulation parameters
set sim_name "tb_pcie_sim"
set top_module "tb_pcie_large_gemm"

# Change to TB directory for output files
cd $tb_dir

# Clean previous simulation
file delete -force xsim.dir
file delete -force {*}[glob -nocomplain *.log]
file delete -force {*}[glob -nocomplain *.jou]
file delete -force {*}[glob -nocomplain *.pb]
file delete -force {*}[glob -nocomplain *.wdb]

puts "============================================================"
puts "PCIe Large GEMM Simulation"
puts "============================================================"
puts "Repository root: $repo_root"
puts "Testbench: $top_module"
puts ""

#-----------------------------------------------------------------------------
# Step 1: Compile RTL sources
#-----------------------------------------------------------------------------
puts "=== Compiling RTL sources with xvlog ==="

# Build include directories list
set inc_dirs [list $xdma_dir $dcim_inc_dir $ref_inc_dir]

# Build source file list
set src_files [list]

# Header files (compile first)
lappend src_files "$xdma_dir/dcim_defs.vh"

# DCIM core modules - try ref directory first, fall back to main
foreach f {dff.v pipe_stage.v counter.v} {
    if {[file exists "$ref_inc_dir/$f"]} {
        lappend src_files "$ref_inc_dir/$f"
    } elseif {[file exists "$dcim_inc_dir/$f"]} {
        lappend src_files "$dcim_inc_dir/$f"
    }
}

# DCIM compute modules
foreach f {multiplier.v adderTree.v maArray.v calculate_core.v sramWrap.v memory.v mergeArray.v ppCache.v accumulateArray.v postProcess.v} {
    if {[file exists "$ref_dcim_dir/$f"]} {
        lappend src_files "$ref_dcim_dir/$f"
    } elseif {[file exists "$dcim_dir/$f"]} {
        lappend src_files "$dcim_dir/$f"
    }
}

# Check for multiplier_dsp.v (may be in main dcim dir)
if {[file exists "$dcim_dir/multiplier_dsp.v"]} {
    lappend src_files "$dcim_dir/multiplier_dsp.v"
}

# XDMA wrapper modules
lappend src_files "$xdma_dir/xdma_dcim_preprocess.v"
lappend src_files "$xdma_dir/DCIM_Macro.sv"
lappend src_files "$xdma_dir/PE.sv"

# Testbench
lappend src_files "$tb_dir/tb_pcie_large_gemm.sv"

# Build xvlog command
set xvlog_cmd [list xvlog -sv]
foreach inc $inc_dirs {
    lappend xvlog_cmd "-i" $inc
}
foreach src $src_files {
    if {[file exists $src]} {
        lappend xvlog_cmd $src
    } else {
        puts "WARNING: Source file not found: $src"
    }
}

puts "Running: $xvlog_cmd"
if {[catch {exec {*}$xvlog_cmd} result]} {
    puts "xvlog output: $result"
    # Check if it's just warnings
    if {[string match "*ERROR*" $result]} {
        error "xvlog compilation failed"
    }
} else {
    puts "xvlog output: $result"
}

#-----------------------------------------------------------------------------
# Step 2: Elaborate design
#-----------------------------------------------------------------------------
puts ""
puts "=== Elaborating design with xelab ==="

set xelab_cmd [list xelab $top_module -debug typical -s $sim_name]
puts "Running: $xelab_cmd"

if {[catch {exec {*}$xelab_cmd} result]} {
    puts "xelab output: $result"
    if {[string match "*ERROR*" $result]} {
        error "xelab elaboration failed"
    }
} else {
    puts "xelab output: $result"
}

#-----------------------------------------------------------------------------
# Step 3: Run simulation
#-----------------------------------------------------------------------------
puts ""
puts "=== Running simulation with xsim ==="

set xsim_cmd [list xsim $sim_name -runall]
puts "Running: $xsim_cmd"

if {[catch {exec {*}$xsim_cmd} result]} {
    puts "xsim output: $result"
    # Simulation may return non-zero on $finish
} else {
    puts "xsim output: $result"
}

puts ""
puts "=== Simulation complete ==="
puts "Check simulation output above for PASS/FAIL status"
