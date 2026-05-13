# ==============================================================================
# DCIM 集成测试 Makefile
# ==============================================================================
# 测试：Preprocess (act_nibble_converter) + DCIM 矩阵乘法
# ==============================================================================

include sim_vars.mk

# ==============================================================================
# 配置
# ==============================================================================
VCS         ?= vcs
PYTHON      ?= python3
VERDI       ?= verdi

BUILD_DIR   := build
LOG_DIR     := $(BUILD_DIR)/logs
WAVE_DIR    := $(BUILD_DIR)/waves
DATA_DIR    := $(BUILD_DIR)/data
RESULT_DIR  := $(BUILD_DIR)/results

EXEC        := simv
COMPILE_LOG := $(LOG_DIR)/compile.log
RUN_LOG     := $(LOG_DIR)/run.log
VERIFY_LOG  := $(LOG_DIR)/verify.log
WAVE_FILE   := $(WAVE_DIR)/waveform.vcd

# ==============================================================================
# VCS 编译选项
# ==============================================================================
VCS_FLAGS   := -full64 -sverilog +v2k
VCS_FLAGS   += -debug_access+all -kdb
VCS_FLAGS   += -timescale=1ns/1ps
VCS_FLAGS   += -ignore initializer_driver_checks
VCS_FLAGS   += +define+SIM +define+VCS

# ==============================================================================
# 伪目标
# ==============================================================================
.PHONY: all test_int8 test_int16 test_all compile run clean cleanall help wave setup

# ==============================================================================
# 默认目标
# ==============================================================================
all: test_all

# ==============================================================================
# 完整测试
# ==============================================================================
test_int8: setup
	@echo ""
	@echo "═══════════════════════════════════════════"
	@echo "  INT8 Integration Test with Golden Model"
	@echo "═══════════════════════════════════════════"
	$(MAKE) compile TYPE=INT8 ACC=0
	$(MAKE) run TYPE=INT8
	@echo "✓ INT8 test completed (results in simulation log)"

test_int16: setup
	@echo ""
	@echo "═══════════════════════════════════════════"
	@echo "  INT16 Integration Test with Golden Model"
	@echo "═══════════════════════════════════════════"
	$(MAKE) compile TYPE=INT16 ACC=0
	$(MAKE) run TYPE=INT16
	@echo "✓ INT16 test completed (results in simulation log)"

test_int16_simple: setup
	@echo ""
	@echo "═══════════════════════════════════════════"
	@echo "  INT16 Simple Test (all weights=1, act=1)"
	@echo "═══════════════════════════════════════════"
	$(MAKE) compile TYPE=INT16 ACC=0 EXTRA_DEFS="+define+TEST_INT16_SIMPLE"
	$(MAKE) run TYPE=INT16
	@echo "✓ INT16 simple test completed"

test_int16_channel: setup
	@echo ""
	@echo "═══════════════════════════════════════════"
	@echo "  INT16 Channel Test (weight=ch+1, act[0]=1)"
	@echo "═══════════════════════════════════════════"
	$(MAKE) compile TYPE=INT16 ACC=0 EXTRA_DEFS="+define+TEST_INT16_CHANNEL"
	$(MAKE) run TYPE=INT16
	@echo "✓ INT16 channel test completed"

# ==============================================================================
# 累加测试
# ==============================================================================
test_int8_acc2: setup
	@echo ""
	@echo "═══════════════════════════════════════════"
	@echo "  INT8 Accumulation Test (ACC=2)"
	@echo "═══════════════════════════════════════════"
	$(MAKE) compile TYPE=INT8 EXTRA_DEFS="+define+TEST_ACC=2"
	$(MAKE) run TYPE=INT8
	@echo "✓ INT8 ACC=2 test completed"

test_int8_acc4: setup
	@echo ""
	@echo "═══════════════════════════════════════════"
	@echo "  INT8 Accumulation Test (ACC=4)"
	@echo "═══════════════════════════════════════════"
	$(MAKE) compile TYPE=INT8 EXTRA_DEFS="+define+TEST_ACC=4"
	$(MAKE) run TYPE=INT8
	@echo "✓ INT8 ACC=4 test completed"

test_int8_acc8: setup
	@echo ""
	@echo "═══════════════════════════════════════════"
	@echo "  INT8 Accumulation Test (ACC=8)"
	@echo "═══════════════════════════════════════════"
	$(MAKE) compile TYPE=INT8 EXTRA_DEFS="+define+TEST_ACC=8"
	$(MAKE) run TYPE=INT8
	@echo "✓ INT8 ACC=8 test completed"

test_all: test_int8 test_int16
	@echo ""
	@echo "═══════════════════════════════════════════"
	@echo "  ✓ All Tests Completed"
	@echo "═══════════════════════════════════════════"

# ==============================================================================
# 设置目录
# ==============================================================================
setup:
	@mkdir -p $(BUILD_DIR) $(LOG_DIR) $(WAVE_DIR) $(DATA_DIR) $(RESULT_DIR)

# ==============================================================================
# 编译
# ==============================================================================
compile: setup
	@echo "Compiling (TYPE=$(TYPE))..."
	@$(VCS) $(VCS_FLAGS) $(VCS_DEFS) $(EXTRA_DEFS) $(INC_VCS) \
		-f filelist.f \
		-o $(EXEC) \
		-l $(COMPILE_LOG) 2>&1 | grep -E "(Error|Warning)" || true
	@if [ -x ./$(EXEC) ]; then \
		echo "✓ Compilation successful"; \
	else \
		echo "✗ Compilation failed. Check $(COMPILE_LOG)"; \
		exit 1; \
	fi

# ==============================================================================
# 运行仿真（内嵌验证）
# ==============================================================================
run: setup
	@if [ ! -x ./$(EXEC) ]; then \
		echo "Error: $(EXEC) not found. Run 'make compile' first."; \
		exit 1; \
	fi
	@echo "Running simulation with embedded golden model..."
	@chmod +x $(EXEC)
	@./$(EXEC) 2>&1 | tee $(RUN_LOG)
	@echo ""
	@if grep -q "VERIFICATION PASSED" $(RUN_LOG); then \
		echo "✓ Test PASSED"; \
	elif grep -q "VERIFICATION FAILED" $(RUN_LOG); then \
		echo "✗ Test FAILED"; \
		exit 1; \
	else \
		echo "⚠ No verification result found"; \
	fi

# ==============================================================================
# 波形查看
# ==============================================================================
wave:
	@if [ -f $(WAVE_FILE) ]; then \
		echo "Opening waveform..."; \
		if command -v gtkwave > /dev/null 2>&1; then \
			gtkwave $(WAVE_FILE) & \
		else \
			echo "GTKWave not found. Waveform: $(WAVE_FILE)"; \
		fi; \
	else \
		echo "No waveform found: $(WAVE_FILE)"; \
		exit 1; \
	fi

# ==============================================================================
# 清理
# ==============================================================================
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)
	@rm -rf simv.daidir csrc
	@rm -f ucli.key *.daidir *.vpd novas* verdiLog AN.DB DVEfiles
	@rm -f *.mem *.txt *.log *.vcd *.fsdb
	@echo "✓ Clean completed"

cleanall: clean
	@rm -f $(EXEC)
	@echo "✓ Deep clean completed"

# ==============================================================================
# 帮助
# ==============================================================================
help:
	@echo "═══════════════════════════════════════════════════════"
	@echo "  DCIM Integration Test: Preprocess + 矩阵乘法"
	@echo "═══════════════════════════════════════════════════════"
	@echo ""
	@echo "测试链路:"
	@echo "  Raw INT8/INT16 → act_nibble_converter → DCIM → Result"
	@echo ""
	@echo "目录结构:"
	@echo "  build/"
	@echo "    ├── logs/       编译、运行、验证日志"
	@echo "    ├── waves/      波形文件"
	@echo "    ├── data/       仿真数据 (.mem)"
	@echo "    └── results/    验证结果 (.txt)"
	@echo ""
	@echo "快速命令:"
	@echo "  make                完整测试 (INT8 + INT16)"
	@echo "  make test_int8      INT8 测试"
	@echo "  make test_int16     INT16 测试"
	@echo "  make wave           查看波形"
	@echo "  make clean          清理生成文件"
	@echo ""
	@echo "分步执行:"
	@echo "  make compile TYPE=INT8    编译"
	@echo "  make run TYPE=INT8        运行仿真"
	@echo "  make verify TYPE=INT8 ... 验证结果"
	@echo ""
	@echo "参数 (sim_vars.mk):"
	@echo "  TYPE=$(TYPE), ACC=$(ACC), R=$(R)"
	@echo "  CH_IN=$(CH_IN), CH_OUT=$(CH_OUT), WD1=$(WD1)"
	@echo ""
	@echo "═══════════════════════════════════════════════════════"

# ==============================================================================
# 调试信息
# ==============================================================================
info:
	@echo "Configuration:"
	@echo "  TYPE     = $(TYPE)"
	@echo "  ACC      = $(ACC)"
	@echo "  R        = $(R)"
	@echo "  CH_IN    = $(CH_IN)"
	@echo "  CH_OUT   = $(CH_OUT)"
	@echo "  WD1      = $(WD1)"
	@echo "  EXEC     = $(EXEC)"
	@echo "  WAVE     = $(WAVE_FILE)"
