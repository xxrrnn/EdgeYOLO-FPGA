# DCIM_Macro 测试 Makefile
# 路径: rtl/DCIM_Macro/tb/Makefile

BUILD_DIR = build
REF_DIR = ../../ref/DCIM

VCS = vcs
VCS_FLAGS = -sverilog -full64 -debug_access+all -timescale=1ns/1ps
VCS_FLAGS += +incdir+$(REF_DIR)/src/inc
VCS_FLAGS += -ignore initializer_driver_checks
VCS_FLAGS += -kdb -lca

.PHONY: all clean unit onnx help

all: unit

help:
	@echo "DCIM_Macro Test Suite"
	@echo "====================="
	@echo "  make unit      - 运行模块单元测试"
	@echo "  make onnx      - 运行 ONNX 卷积层测试"
	@echo "  make all       - 运行所有测试"
	@echo "  make clean     - 清理构建文件"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# ============================================================================
# 单元测试 (unit/)
# ============================================================================
compile_unit: $(BUILD_DIR)
	$(VCS) $(VCS_FLAGS) +define+SIM \
		-f filelist.f \
		unit/tb_DCIM_Macro.sv \
		-o $(BUILD_DIR)/simv_unit

unit: compile_unit
	cd $(BUILD_DIR) && chmod +x simv_unit && ./simv_unit

unit_fsdb: compile_unit
	cd $(BUILD_DIR) && ./simv_unit +fsdb+autoflush +fsdbfile+unit_test.fsdb

# ============================================================================
# ONNX 卷积层测试 (onnx/)
# ============================================================================
compile_onnx: $(BUILD_DIR)
	$(VCS) $(VCS_FLAGS) +define+SIM \
		-f filelist.f \
		onnx/tb_onnx_conv_layers.sv \
		-o $(BUILD_DIR)/simv_onnx

onnx: compile_onnx
	cd $(BUILD_DIR) && chmod +x simv_onnx && ./simv_onnx

onnx_fsdb: compile_onnx
	cd $(BUILD_DIR) && ./simv_onnx +fsdb+autoflush +fsdbfile+onnx_test.fsdb

# ============================================================================
# 清理
# ============================================================================
clean:
	rm -rf $(BUILD_DIR) csrc *.daidir *.log *.key *.vpd DVEfiles
