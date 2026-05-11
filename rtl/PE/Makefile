# ============================================================================
# PE Array Makefile
# ============================================================================
#
# FSDB：必须 (1) 编译时链接 Verdi PLI  (2) testbench 里 $fsdbDumpfile
#       仅靠 ./simv +fsdbfile+xxx 不会自动生成有效 FSDB。
#
# 使用前设置 VERDI_HOME（或 Makefile 里默认路径）；示例：
#   export VERDI_HOME=/path/to/verdi/V-2023.xx
#

# 工具配置
VCS = vcs
VCS_FLAGS = -sverilog -full64 -debug_access+all -timescale=1ns/1ps
VCS_FLAGS += +incdir+../ref/DCIM/src/inc
VCS_FLAGS += -ignore initializer_driver_checks
VCS_FLAGS += -kdb -lca
VCS_FLAGS += +define+SIM

# Verdi（生成 FSDB 用）
VERDI_HOME ?= /home/EDAtools/synopsys/verdi/V-2023.12-SP1
NOVAS_TAB = $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab
PLI_A     = $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a
ifneq ($(wildcard $(NOVAS_TAB)),)
  VCS_FSDB_PLI = -P $(NOVAS_TAB) $(PLI_A)
else
  VCS_FSDB_PLI =
endif

# FSDB 运行时选项（配合 DUMP_FSDB 编译）
FSDB_FLAGS = +fsdb+autoflush
FSDB_NAME = pe_array.fsdb

# 目录
BUILD_DIR = build
TB_DIR = tb

.PHONY: all clean help compile compile_fsdb sim fsdb verdi

all: sim

help:
	@echo "PE Array Build System"
	@echo "====================="
	@echo "  make compile      - 编译 RTL（无 FSDB PLI）"
	@echo "  make compile_fsdb - 编译 RTL + Verdi PLI + DUMP_FSDB（用于出 FSDB）"
	@echo "  make sim          - 运行仿真（无 FSDB）"
	@echo "  make fsdb         - compile_fsdb 后在 build/$(FSDB_NAME) 生成波形"
	@echo "  make verdi        - 打开 build/$(FSDB_NAME)（须先 make fsdb）"
	@echo ""
	@echo "若 compile_fsdb 失败：检查 VERDI_HOME=$(VERDI_HOME)"
	@echo "若 verdi 找不到文件：先 cd rtl/PE && make fsdb"
	@echo ""
	@echo "  make clean        - 清理构建文件"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# ============================================================================
# 编译（普通）
# ============================================================================
compile: $(BUILD_DIR)
	$(VCS) $(VCS_FLAGS) \
		-f filelist.f \
		$(TB_DIR)/tb_PE_Array.sv \
		-o $(BUILD_DIR)/simv

# ============================================================================
# 编译（含 FSDB：PLI + DUMP_FSDB）
# ============================================================================
compile_fsdb: $(BUILD_DIR)
	@if [ -z "$(strip $(VCS_FSDB_PLI))" ]; then \
		echo "错误: 找不到 $(NOVAS_TAB)"; \
		echo "请设置正确的 VERDI_HOME，例如: export VERDI_HOME=/path/to/verdi/V-xxxx"; \
		exit 1; \
	fi
	$(VCS) $(VCS_FLAGS) $(VCS_FSDB_PLI) +define+DUMP_FSDB \
		-f filelist.f \
		$(TB_DIR)/tb_PE_Array.sv \
		-o $(BUILD_DIR)/simv

# ============================================================================
# 仿真
# ============================================================================
sim: compile
	cd $(BUILD_DIR) && chmod +x simv && ./simv

# 导出 FSDB（波形：build/$(FSDB_NAME)）
fsdb: compile_fsdb
	cd $(BUILD_DIR) && chmod +x simv && ./simv $(FSDB_FLAGS)

# 打开 Verdi（须在 rtl/PE 下执行；波形为 build/$(FSDB_NAME)）
verdi:
	@if [ ! -f $(BUILD_DIR)/$(FSDB_NAME) ]; then \
		echo "缺少 $(BUILD_DIR)/$(FSDB_NAME)，请先在本目录执行: make fsdb"; \
		exit 1; \
	fi
	cd $(BUILD_DIR) && verdi -dbdir simv.daidir -ssf $(FSDB_NAME) &

# ============================================================================
# 清理
# ============================================================================
clean:
	rm -rf $(BUILD_DIR)
	rm -rf csrc *.daidir *.log *.key *.vpd *.vcd *.fsdb
	rm -rf DVEfiles ucli.key
