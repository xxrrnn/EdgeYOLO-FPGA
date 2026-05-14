# Makefile for act_nibble_converter unit test

VCS = vcs
VERDI = verdi
SIM = ./simv

# 源文件
RTL_DIR = ..
TB_DIR = .
SRC = $(RTL_DIR)/act_nibble_converter.sv
TB = $(TB_DIR)/tb_act_nibble_converter.sv

# VCS 编译选项
VCS_FLAGS = -full64 -sverilog +v2k -timescale=1ns/1ps -debug_access+all
VCS_FLAGS += -LDFLAGS -Wl,--no-as-needed
VCS_FLAGS += +warn=all

# Verdi 选项
VERDI_FLAGS = -ssf tb_act_nibble_converter.fsdb -dbdir simv.daidir

.PHONY: all clean test wave

all: test

# 编译
compile: $(SRC) $(TB)
	$(VCS) $(VCS_FLAGS) $(SRC) $(TB) -o $(SIM)

# 运行测试
test: compile
	$(SIM) | tee test.log
	@echo ""
	@echo "检查测试结果..."
	@if grep -q ">>> 所有测试通过 <<<" test.log; then \
		echo "测试通过！"; \
	else \
		echo "测试失败！"; \
		exit 1; \
	fi

# 查看波形
wave:
	$(VERDI) $(VERDI_FLAGS) &

# 清理
clean:
	rm -rf csrc simv.daidir simv ucli.key vc_hdrs.h
	rm -rf *.log *.vpd *.fsdb DVEfiles
