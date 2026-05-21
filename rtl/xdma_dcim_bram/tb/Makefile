# ============================================================================
# Makefile for DCIM_Macro Testbench
# ============================================================================
# 使用 VCS + Verdi 进行仿真和波形查看

# 工具路径
VCS = vcs
VERDI = verdi

# 源文件目录
RTL_DIR = ..
DCIM_DIR = ../../DCIM/src
TB_DIR = .

# 编译选项
VCS_OPTS = -sverilog \
           -full64 \
           -timescale=1ns/1ps \
           -debug_access+all \
           -kdb \
           -lca \
           -ignore initializer_driver_checks \
           -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab \
           $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a \
           +v2k \
           -assert svaext \
           +lint=TFIPC-L \
           -o simv_DCIM_Macro_tb

# 源文件列表
RTL_SRCS = $(RTL_DIR)/dcim_defs.vh \
           $(RTL_DIR)/xdma_dcim_preprocess.v \
           $(RTL_DIR)/DCIM_Macro.sv \
           $(DCIM_DIR)/inc/para.v \
           $(DCIM_DIR)/inc/counter.v \
           $(DCIM_DIR)/inc/dff.v \
           $(DCIM_DIR)/inc/pipe_stage.v \
           $(DCIM_DIR)/dcim/multiplier.v \
           $(DCIM_DIR)/dcim/adderTree.v \
           $(DCIM_DIR)/dcim/maArray.v \
           $(DCIM_DIR)/dcim/calculate_core.v \
           $(DCIM_DIR)/dcim/mergeArray.v \
           $(DCIM_DIR)/dcim/accumulateArray.v \
           $(DCIM_DIR)/dcim/postProcess.v

TB_SRCS = $(TB_DIR)/DCIM_Macro_tb.sv

# Include 路径
INCDIR = +incdir+$(RTL_DIR) \
         +incdir+$(DCIM_DIR)/inc

# 默认目标
all: compile

# 编译
compile: $(RTL_SRCS) $(TB_SRCS)
	@echo "========================================="
	@echo "Compiling DCIM_Macro Testbench..."
	@echo "========================================="
	$(VCS) $(VCS_OPTS) $(INCDIR) $(RTL_SRCS) $(TB_SRCS)
	@echo "Compilation completed."

# 运行仿真（GUI 模式）
run_gui: compile
	@echo "========================================="
	@echo "Running simulation with Verdi GUI..."
	@echo "========================================="
	./simv_DCIM_Macro_tb -gui

# 运行仿真（命令行模式）
run: compile
	@echo "========================================="
	@echo "Running simulation..."
	@echo "========================================="
	./simv_DCIM_Macro_tb

# 仅打开 Verdi 查看波形
verdi: DCIM_Macro_tb.fsdb
	@echo "========================================="
	@echo "Opening Verdi to view waveforms..."
	@echo "========================================="
	$(VERDI) -ssf DCIM_Macro_tb.fsdb &

# 清理
clean:
	@echo "Cleaning up..."
	rm -rf csrc simv* *.daidir *.log *.key *.vpd *.fsdb *.conf
	rm -rf verdiLog novas* *.rc DVEfiles
	@echo "Clean completed."

# 深度清理（包括所有生成的目录）
distclean: clean
	rm -rf *.vdb *.fsdb work.lib++

# 帮助信息
help:
	@echo "========================================="
	@echo "DCIM_Macro Testbench Makefile"
	@echo "========================================="
	@echo "Available targets:"
	@echo "  make all       - Compile the testbench (default)"
	@echo "  make compile   - Compile the testbench"
	@echo "  make run       - Compile and run simulation (CLI mode)"
	@echo "  make run_gui   - Compile and run simulation with Verdi GUI"
	@echo "  make verdi     - Open Verdi to view existing waveform"
	@echo "  make clean     - Remove simulation files"
	@echo "  make distclean - Remove all generated files"
	@echo "  make help      - Show this help message"
	@echo "========================================="

.PHONY: all compile run run_gui verdi clean distclean help
