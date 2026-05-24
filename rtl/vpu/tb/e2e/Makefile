# ==============================================================================
# Makefile for E2E CNN simulation (Vivado xsim)
# ==============================================================================

PROJ_ROOT = ../../../..
CHIP_DIR = $(PROJ_ROOT)/rtl/chip
VPU_DIR = $(PROJ_ROOT)/rtl/vpu
REF_DIR = $(PROJ_ROOT)/rtl/ref/DCIM
IP_DIR = $(PROJ_ROOT)/build/lite/lite.gen/sources_1/ip

XVLOG = xvlog
XELAB = xelab
XSIM = xsim

XVLOG_OPTS = -sv -d SIM \
  -i $(CHIP_DIR) \
  -i $(REF_DIR)/src/inc \
  -i $(REF_DIR)/src/dcim \
  -i $(VPU_DIR) \
  -i "$(VPU_DIR)/fp array"

XELAB_OPTS = -debug typical -L floating_point_v7_1_19 -L unisims_ver
XSIM_OPTS = -runall -nolog

.PHONY: all clean golden compile sim e2e-inst e2e-inst-golden e2e-inst-compile e2e-inst-sim

all: golden sim

# Generate golden hex files (legacy tb_e2e_simple)
golden:
	python3 golden_e2e.py

# Compile all sources (legacy tb_e2e_simple)
compile:
	$(XVLOG) $(XVLOG_OPTS) -f filelist_e2e.f tb_e2e_simple.sv
	$(XELAB) $(XELAB_OPTS) tb_e2e_simple -s sim_e2e

# Run simulation (legacy tb_e2e_simple)
sim: compile
	cp hex/*.hex . 2>/dev/null || true
	$(XSIM) sim_e2e $(XSIM_OPTS)

# ==============================================================================
# Instruction-driven E2E with real-YOLO 3-layer goldens (scaled spatial dims)
# ==============================================================================
SCALE ?= 0.2

e2e-inst: e2e-inst-golden e2e-inst-compile e2e-inst-sim

e2e-inst-golden:
	python3 golden_e2e_inst.py --scale $(SCALE)

e2e-inst-compile:
	$(XVLOG) $(XVLOG_OPTS) -f filelist_e2e.f tb_e2e_inst_driven.sv
	$(XELAB) $(XELAB_OPTS) tb_e2e_inst_driven -s sim_e2e_inst

e2e-inst-sim:
	cp hex_inst/*.hex . 2>/dev/null || true
	$(XSIM) sim_e2e_inst $(XSIM_OPTS)

clean:
	rm -rf xsim.dir .Xil *.jou *.log *.pb *.wdb *.hex
	rm -rf hex/*.hex hex_inst/*.hex hex_inst/manifest.txt
