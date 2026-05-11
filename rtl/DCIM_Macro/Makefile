# DCIM_Macro Makefile

# 目录
BUILD_DIR = build
SRC_DIR = .
REF_DIR = ../../ref/DCIM

# VCS 选项
VCS = vcs
VCS_FLAGS = -sverilog -full64 -debug_access+all -timescale=1ns/1ps
VCS_FLAGS += +incdir+$(REF_DIR)/src/inc
VCS_FLAGS += -ignore initializer_driver_checks

# Verdi/FSDB 选项
VCS_FLAGS += -kdb -lca
FSDB_FLAGS = +fsdb+autoflush

# 默认目标
.PHONY: all clean compile sim test fsdb verdi

all: test

# 创建目录
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# 编译
compile: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) +define+SIM \
		-f ../filelist.f \
		../tb_DCIM_Macro.sv \
		-o simv

# 仿真
sim: compile
	cd $(BUILD_DIR) && chmod +x simv && ./simv

# 生成 FSDB 波形
fsdb: compile
	cd $(BUILD_DIR) && chmod +x simv && ./simv $(FSDB_FLAGS) +fsdbfile+dcim_macro.fsdb

# 打开 Verdi 查看波形
verdi:
	cd $(BUILD_DIR) && verdi -dbdir simv.daidir -ssf dcim_macro.fsdb &

# 测试
test: sim

# FPGA 编译 (使用 BRAM)
compile_fpga: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) +define+FPGA \
		-f ../filelist.f \
		../tb_DCIM_Macro.sv \
		-o simv_fpga

test_fpga: compile_fpga
	cd $(BUILD_DIR) && chmod +x simv_fpga && ./simv_fpga

# 清理
clean:
	rm -rf $(BUILD_DIR) csrc *.daidir *.log *.key *.vpd DVEfiles
