# DCIM_Array 测试 Makefile（路径: rtl/chip/tb/Makefile）
# VCS 在 ../build 下执行，以便 ../filelist.f 中相对路径与原先 rtl/chip/Makefile 一致。

CHIP_DIR = ..
BUILD_DIR = $(CHIP_DIR)/build
REF_DIR = $(CHIP_DIR)/../ref/DCIM

VCS = vcs
VCS_FLAGS = -sverilog -full64 -debug_access+all -timescale=1ns/1ps
VCS_FLAGS += +incdir+$(REF_DIR)/src/inc
VCS_FLAGS += +incdir+$(REF_DIR)/src/dcim
VCS_FLAGS += -ignore initializer_driver_checks

VCS_FLAGS += -kdb -lca
FSDB_FLAGS = +fsdb+autoflush

.PHONY: all clean compile sim test test_array test_tile compile_tile sim_tile fsdb verdi test_all

all: test

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

compile: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) +define+SIM \
		-f ../filelist.f \
		../tb/tb_DCIM_Array.sv \
		-o simv

sim: compile
	cd $(BUILD_DIR) && chmod +x simv && ./simv

test: sim

compile_tile: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) +define+SIM \
		-f ../filelist.f \
		../tb/tb_DCIM_Tile.sv \
		-o simv_tile

sim_tile: compile_tile
	cd $(BUILD_DIR) && chmod +x simv_tile && ./simv_tile

test_tile: sim_tile

test_all: test test_tile

fsdb: compile
	cd $(BUILD_DIR) && chmod +x simv && ./simv $(FSDB_FLAGS) +fsdbfile+dcim_array.fsdb

verdi:
	cd $(BUILD_DIR) && verdi -dbdir simv.daidir -ssf dcim_array.fsdb &

clean:
	rm -rf $(BUILD_DIR) $(CHIP_DIR)/csrc $(CHIP_DIR)/*.daidir $(CHIP_DIR)/*.log $(CHIP_DIR)/*.key $(CHIP_DIR)/*.vpd $(CHIP_DIR)/DVEfiles
	rm -rf csrc *.daidir *.log *.key *.vpd DVEfiles
