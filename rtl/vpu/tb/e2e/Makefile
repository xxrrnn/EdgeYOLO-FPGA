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

.PHONY: all clean golden compile sim

all: golden sim

# Generate golden hex files
golden:
	python3 golden_e2e.py

# Compile all sources
compile:
	$(XVLOG) $(XVLOG_OPTS) -f filelist_e2e.f tb_e2e_simple.sv
	$(XELAB) $(XELAB_OPTS) tb_e2e_simple -s sim_e2e

# Run simulation
sim: compile
	cp hex/*.hex . 2>/dev/null || true
	$(XSIM) sim_e2e $(XSIM_OPTS)

clean:
	rm -rf xsim.dir .Xil *.jou *.log *.pb *.wdb *.hex
	rm -rf hex/*.hex
