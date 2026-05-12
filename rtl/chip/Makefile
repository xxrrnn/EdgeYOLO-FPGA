# DCIM_Array Makefile

# 目录
BUILD_DIR = build
REF_DIR = ../ref/DCIM

# VCS 选项
VCS = vcs
VCS_FLAGS = -sverilog -full64 -debug_access+all -timescale=1ns/1ps
VCS_FLAGS += +incdir+$(REF_DIR)/src/inc
VCS_FLAGS += +incdir+$(REF_DIR)/src/dcim
VCS_FLAGS += -ignore initializer_driver_checks

# Verdi/FSDB 选项
VCS_FLAGS += -kdb -lca
FSDB_FLAGS = +fsdb+autoflush

# 默认目标
.PHONY: all clean compile sim test test_array test_tile compile_tile sim_tile fsdb verdi

all: test

# 创建目录
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# 编译 DCIM_Array 测试
compile: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) +define+SIM \
		-f ../filelist.f \
		../tb_DCIM_Array.sv \
		-o simv

# 仿真
sim: compile
	cd $(BUILD_DIR) && chmod +x simv && ./simv

# 测试
test: sim

# 编译 DCIM_Tile 综合回归测试
compile_tile: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) +define+SIM \
		-f ../filelist.f \
		../tb_DCIM_Tile.sv \
		-o simv_tile

sim_tile: compile_tile
	cd $(BUILD_DIR) && chmod +x simv_tile && ./simv_tile

test_tile: sim_tile

# 阵列 + 单 Tile 测试
test_all: test test_tile

# 生成 FSDB 波形
fsdb: compile
	cd $(BUILD_DIR) && chmod +x simv && ./simv $(FSDB_FLAGS) +fsdbfile+dcim_array.fsdb

# 打开 Verdi 查看波形
verdi:
	cd $(BUILD_DIR) && verdi -dbdir simv.daidir -ssf dcim_array.fsdb &

# 清理
clean:
	rm -rf $(BUILD_DIR) csrc *.daidir *.log *.key *.vpd DVEfiles
