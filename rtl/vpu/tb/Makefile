#===============================================================================
# Makefile for VPU RTL Testing
# 测试所有 VPU 单元的功能正确性和时序优化
#===============================================================================

# Vivado 工具路径
XVLOG = xvlog
XELAB = xelab
XSIM = xsim

# 源文件目录
RTL_DIR = ../
TB_DIR = .

# 通用编译选项
XVLOG_OPTS = -sv
XELAB_OPTS = -debug typical
XSIM_OPTS = -runall -nolog

# 颜色输出
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[1;33m
NC = \033[0m # No Color

#===============================================================================
# 测试目标
#===============================================================================

.PHONY: all clean help timing_test unit_tests full_test report

# 默认目标
all: timing_test unit_tests

# 时序优化测试
timing_test:
	@echo "$(YELLOW)========================================$(NC)"
	@echo "$(YELLOW)运行时序优化测试...$(NC)"
	@echo "$(YELLOW)========================================$(NC)"
	@$(MAKE) run_tb TB=tb_all_units_timing
	@echo ""

# 单元功能测试
unit_tests: test_qa test_dqa test_ad test_us test_mp

test_qa:
	@echo "$(YELLOW)========================================$(NC)"
	@echo "$(YELLOW)测试 QA Unit (Quantization)...$(NC)"
	@echo "$(YELLOW)========================================$(NC)"
	@$(MAKE) run_tb_with_deps TB=tb_qa_unit DEPS="qa_unit.sv"
	@echo ""

test_dqa:
	@echo "$(YELLOW)========================================$(NC)"
	@echo "$(YELLOW)测试 DQA Unit (Dequantization)...$(NC)"
	@echo "$(YELLOW)========================================$(NC)"
	@$(MAKE) run_tb_with_deps TB=tb_dqa_unit DEPS="dqa_unit.sv int32_2_fp32_array.sv fp_mac_array.sv fp32_mac_array_ip.sv"
	@echo ""

test_ad:
	@echo "$(YELLOW)========================================$(NC)"
	@echo "$(YELLOW)测试 AD Unit (Element-wise Add)...$(NC)"
	@echo "$(YELLOW)========================================$(NC)"
	@python3 gen_ad_test.py
	@$(MAKE) compile_and_run TB=tb_ad_unit DEPS="ad_unit.sv"
	@echo ""

test_us:
	@echo "$(YELLOW)========================================$(NC)"
	@echo "$(YELLOW)测试 US Unit (Upsampling)...$(NC)"
	@echo "$(YELLOW)========================================$(NC)"
	@$(MAKE) run_tb_with_deps TB=tb_us_unit DEPS="us_unit.sv"
	@echo ""

test_mp:
	@echo "$(YELLOW)========================================$(NC)"
	@echo "$(YELLOW)测试 MP Unit (Max Pooling)...$(NC)"
	@echo "$(YELLOW)========================================$(NC)"
	@$(MAKE) run_tb_with_deps TB=tb_mp_unit DEPS="mp_unit.sv max_pooling2d5x5.sv"
	@echo ""

# 完整测试（包括整体 VPU 测试）
full_test: timing_test unit_tests
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)所有测试完成！$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@python3 generate_report.py

# 生成测试报告
report:
	@python3 generate_report.py

#===============================================================================
# 内部构建规则
#===============================================================================

# 运行单个测试（不带依赖编译）
run_tb:
	@$(XVLOG) $(XVLOG_OPTS) $(TB_DIR)/$(TB).sv
	@$(XELAB) $(XELAB_OPTS) $(TB) -s $(TB)_sim
	@$(XSIM) $(TB)_sim $(XSIM_OPTS)
	@if [ $$? -eq 0 ]; then \
		echo "$(GREEN)✓ $(TB) 测试通过$(NC)"; \
	else \
		echo "$(RED)✗ $(TB) 测试失败$(NC)"; \
		exit 1; \
	fi

# 运行测试（带依赖编译）
run_tb_with_deps:
	@for dep in $(DEPS); do \
		$(XVLOG) $(XVLOG_OPTS) $(RTL_DIR)/$$dep; \
	done
	@$(XVLOG) $(XVLOG_OPTS) $(TB_DIR)/$(TB).sv
	@$(XELAB) $(XELAB_OPTS) $(TB) -s $(TB)_sim
	@$(XSIM) $(TB)_sim $(XSIM_OPTS)
	@if [ $$? -eq 0 ]; then \
		echo "$(GREEN)✓ $(TB) 测试通过$(NC)"; \
	else \
		echo "$(RED)✗ $(TB) 测试失败$(NC)"; \
		exit 1; \
	fi

# 编译并运行（用于 Python 生成的测试）
compile_and_run:
	@for dep in $(DEPS); do \
		$(XVLOG) $(XVLOG_OPTS) $(RTL_DIR)/$$dep || exit 1; \
	done
	@if [ -f $(TB_DIR)/$(TB).sv ]; then \
		$(XVLOG) $(XVLOG_OPTS) $(TB_DIR)/$(TB).sv || exit 1; \
		$(XELAB) $(XELAB_OPTS) $(TB) -s $(TB)_sim || exit 1; \
		$(XSIM) $(TB)_sim $(XSIM_OPTS); \
		if [ $$? -eq 0 ]; then \
			echo "$(GREEN)✓ $(TB) 测试通过$(NC)"; \
		else \
			echo "$(RED)✗ $(TB) 测试失败$(NC)"; \
			exit 1; \
		fi \
	else \
		echo "$(RED)错误: 测试文件 $(TB).sv 不存在$(NC)"; \
		exit 1; \
	fi

#===============================================================================
# 清理
#===============================================================================

clean:
	@echo "清理生成文件..."
	@rm -rf xsim.dir
	@rm -f *.jou *.log *.pb *.wdb
	@rm -f tb_ad_unit.sv
	@rm -f test_report.txt
	@echo "$(GREEN)清理完成$(NC)"

#===============================================================================
# 帮助
#===============================================================================

help:
	@echo "VPU RTL 测试 Makefile"
	@echo ""
	@echo "目标："
	@echo "  all          - 运行时序测试和单元测试（默认）"
	@echo "  timing_test  - 运行时序优化验证测试"
	@echo "  unit_tests   - 运行所有单元功能测试"
	@echo "  test_qa      - 测试 QA 单元（量化）"
	@echo "  test_dqa     - 测试 DQA 单元（反量化）"
	@echo "  test_ad      - 测试 AD 单元（逐元素加法）"
	@echo "  test_us      - 测试 US 单元（上采样）"
	@echo "  test_mp      - 测试 MP 单元（最大池化）"
	@echo "  full_test    - 运行所有测试并生成报告"
	@echo "  report       - 生成测试报告"
	@echo "  clean        - 清理生成的文件"
	@echo "  help         - 显示此帮助信息"
	@echo ""
	@echo "示例："
	@echo "  make              # 运行默认测试"
	@echo "  make test_qa      # 只测试 QA 单元"
	@echo "  make full_test    # 完整测试"
	@echo "  make clean        # 清理"
