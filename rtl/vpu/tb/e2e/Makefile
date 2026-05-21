# ==============================================================================
# Makefile for E2E CNN simulation
# ==============================================================================

PROJ_ROOT = ../../../..
BUILD_DIR = build
CHIP_DIR = $(PROJ_ROOT)/rtl/chip
VPU_DIR = $(PROJ_ROOT)/rtl/vpu
REF_DIR = $(PROJ_ROOT)/rtl/ref/DCIM
IP_DIR = $(PROJ_ROOT)/build/lite/lite.gen/sources_1/ip
XILINX_DIR = /home/EDAtools/Xilinx/Vivado/2024.2

VCS = vcs
VCS_FLAGS = -sverilog -full64 -debug_access+all -timescale=1ns/1ps
VCS_FLAGS += +incdir+$(CHIP_DIR)
VCS_FLAGS += +incdir+$(REF_DIR)/src/inc
VCS_FLAGS += +incdir+$(REF_DIR)/src/dcim
VCS_FLAGS += +incdir+$(VPU_DIR)
VCS_FLAGS += "+incdir+$(VPU_DIR)/fp array"
VCS_FLAGS += -ignore initializer_driver_checks
VCS_FLAGS += -kdb -lca +define+SIM
VCS_FLAGS += +libext+.v+.sv
VCS_FLAGS += $(XILINX_DIR)/data/verilog/src/glbl.v

.PHONY: all clean golden compile sim

all: golden sim

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Generate golden hex files
golden:
	python3 golden_e2e.py

# Compile
compile: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) \
		-f ../filelist_e2e.f \
		../tb_e2e_simple.sv \
		-o simv_e2e

# Run simulation
sim: compile
	cd $(BUILD_DIR) && cp ../hex/*.hex . 2>/dev/null; ./simv_e2e

clean:
	rm -rf $(BUILD_DIR) *.log *.key DVEfiles
	rm -rf hex/*.hex
