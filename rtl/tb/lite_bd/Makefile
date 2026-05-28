# lite BD VCS simulation helpers
#
# ==============================================================================
# 什么时候需要重新 Vivado export_simulation？
# ==============================================================================
# 不需要重新 export 的情况（最常见）：
#   - 只修改 rtl/ 下普通用户 RTL，例如 VPU、DCIM、INST_Decoder、TB、BFM。
#   - 只修改 Python golden / hex 数据生成脚本。
#   - 只修改 tb_lite_bd_e2e.sv、host_axi_master_bfm.sv、lite_bd_hier.svh。
#   处理方式：直接 make sim-fast / make sim-hbm / make sim-fsdb。
#   原因：sim/run_bd_sim.sh 每次都会重新生成 golden，并重新 vlogan 用户 RTL/TB。
#
# 需要重新 export 的情况：
#   - 修改 Vivado BD 结构，例如增删 IP、改 SmartConnect、改端口连接。
#   - 修改 scripts/ip/bd/lite/*.tcl 或 scripts/chip-lite/* 影响 BD/IP 生成。
#   - 修改地址映射，导致 BD address editor 输出变化。
#   - 重新生成 build/lite/lite.xpr 或 bd/lite/lite.bd。
#   - 修改 IP 配置、IP 版本、BD wrapper 端口。
#   处理方式：先 make export，或直接 make sim-export / make sim-hbm-export。
#
# 速度档位：
#   make sim-fast : 层级B，Host 直写 OBUF/IBUF，仍跑 lite BD + axi_cdma/VPU/DCIM。
#   make sim-hbm  : HBM-first，最接近硬件，但非常慢，仅建议 sign-off 用。
#
# FSDB/Verdi：
#   make sim-fsdb : fast 模式 + FSDB dump。
#   make verdi    : 打开生成的 FSDB。
#
# 典型命令：
#   make sim-fast SKIP_LITE_COMPILE=1 BD_VERIFY_WORDS=8
#   make sim-hbm  SKIP_LITE_COMPILE=1 BD_VERIFY_WORDS=8
#   make export
#   make sim-export
#
# module_tb 子测试（从本目录转发，无需 cd module_tb）：
#   make module-sim MODULE_CASE=im2col MODULE_VARIANT=im2col_3x3_s2_c32
#   make module-sim-batch BATCH_SUITE=dcim_smoke
#   make module-list-cases MODULE_CASE=dcim_matmul
# ===============================================================================

REPO_ROOT := $(abspath ../../..)
SIM_DIR   := $(abspath sim)
BUILD_DIR := $(SIM_DIR)/build_bd_sim
SIM_LOG   := $(BUILD_DIR)/sim.log
FSDB      := $(BUILD_DIR)/tb_lite_bd_e2e.fsdb
EXPORT_TCL := $(REPO_ROOT)/scripts/chip-lite/4_export_sim.tcl

BD_CASE ?= default
BD_SCALE ?= 0.1
BD_VERIFY_WORDS ?= 8
BD_MODE ?= fast
SKIP_LITE_COMPILE ?= 1
XILINX_VCS_LIB ?= /data/home/rn_xu29/Tools/vcs_lib
VIVADO_HOME ?= /home/EDAtools/Xilinx/Vivado/2024.2

# module_tb 转发变量（与子目录 Makefile 一致）
MODULE_TB_DIR := $(abspath module_tb)
MODULE_CASE ?= dcim_matmul
MODULE_VARIANT ?= dcim_tiny_1x1
MODULE_VERIFY_WORDS ?= 256
MODULE_RUN_EXPORT ?= 0
BATCH_SUITE ?=
MODULE_VARIANTS ?=
STOP_ON_FAIL ?= 1

MODULE_MAKE = $(MAKE) -C $(MODULE_TB_DIR)

.PHONY: help export sim sim-fast sim-export sim-hbm sim-hbm-export sim-fsdb sim-fsdb-export verdi waves summary clean
.PHONY: module-sim module-sim-export module-fsdb module-fsdb-export module-export
.PHONY: module-verdi module-data module-list-cases module-clean module-help
.PHONY: module-sim-batch module-sim-batch-export module-data-batch module-list-suites
.PHONY: module-sim-ps module-sim-watch module-sim-done

# 只重新导出 Vivado BD 仿真文件，不跑 VCS。
# 用于 BD/IP/address/wrapper 变化后刷新 sim/lite_bd_export/vcs。
export:
	@echo "[export] Vivado export_simulation only"
	@echo "[export] Use this after BD/IP/address/wrapper changes. RTL-only edits do not need it."
	cd $(REPO_ROOT) && VIVADO_HOME=$(VIVADO_HOME) vivado -mode batch -source $(EXPORT_TCL)

# 默认：fast BD 模式。RTL-only 修改后跑这个即可。
sim: sim-fast

# 层级B fast 模式：
#   - golden 使用 --bd-sim-fast
#   - TB 使用 +FAST_ONCHIP_LOAD 直接预加载 OBUF/IBUF
#   - 仍使用导出的 lite BD、SmartConnect、axi_cdma、VPU、DCIM
sim-fast:
	XILINX_VCS_LIB=$(XILINX_VCS_LIB) \
	VIVADO_HOME=$(VIVADO_HOME) \
	BD_MODE=fast BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) \
	BD_VERIFY_WORDS=$(BD_VERIFY_WORDS) SKIP_LITE_COMPILE=$(SKIP_LITE_COMPILE) \
	bash sim/run_bd_sim.sh

# 先 export，再跑 fast 模式。
# 用于 BD/IP/address/wrapper 变化后的一键流程。
sim-export: export
	$(MAKE) sim-fast SKIP_LITE_COMPILE=0 BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) BD_VERIFY_WORDS=$(BD_VERIFY_WORDS)

# HBM-first 模式：
#   - golden 使用 --bd-sim
#   - 生成并加载 hbm_image.hex
#   - 指令包含 HBM -> OBUF/IBUF 的初始 CDMA copy
#   - 最接近硬件，但很慢
sim-hbm:
	XILINX_VCS_LIB=$(XILINX_VCS_LIB) \
	VIVADO_HOME=$(VIVADO_HOME) \
	BD_MODE=hbm BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) \
	BD_VERIFY_WORDS=$(BD_VERIFY_WORDS) SKIP_LITE_COMPILE=$(SKIP_LITE_COMPILE) \
	bash sim/run_bd_sim.sh

# 先 export，再跑 HBM-first。用于最终 sign-off。
sim-hbm-export: export
	$(MAKE) sim-hbm SKIP_LITE_COMPILE=0 BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) BD_VERIFY_WORDS=$(BD_VERIFY_WORDS)

# fast 模式 + FSDB dump。
# FSDB 默认输出：sim/build_bd_sim/tb_lite_bd_e2e.fsdb
sim-fsdb:
	XILINX_VCS_LIB=$(XILINX_VCS_LIB) \
	VIVADO_HOME=$(VIVADO_HOME) \
	BD_MODE=fast BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) \
	BD_VERIFY_WORDS=$(BD_VERIFY_WORDS) SKIP_LITE_COMPILE=$(SKIP_LITE_COMPILE) \
	VCS_DUMP=1 DUMP_FSDB=$(FSDB) bash sim/run_bd_sim.sh

# 先 export，再跑 fast + FSDB。
sim-fsdb-export: export
	$(MAKE) sim-fsdb SKIP_LITE_COMPILE=0 BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) BD_VERIFY_WORDS=$(BD_VERIFY_WORDS)

# 打印最近一次仿真摘要。
summary:
	@if [ -f $(SIM_LOG) ]; then \
		grep -E 'compare L|PASS,|FAIL ---|GRAND|ALL CHECKPOINTS|SOME CHECKPOINTS|FATAL|HOST_BFM|BD_E2E' $(SIM_LOG) | tail -60; \
	else \
		echo "No $(SIM_LOG)"; \
	fi

# 打开 FSDB。若没有 FSDB，先 make sim-fsdb。
verdi waves:
	@if [ -f $(FSDB) ]; then \
		verdi -ssf $(FSDB) & \
	else \
		echo "No FSDB found: $(FSDB)"; \
		echo "Run: make sim-fsdb"; \
		exit 1; \
	fi

clean:
	rm -rf $(BUILD_DIR)

# ── module_tb 转发（实现见 module_tb/Makefile）────────────────────────────────
module-sim:
	$(MODULE_MAKE) sim MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) RUN_EXPORT=$(MODULE_RUN_EXPORT)

module-sim-export:
	$(MODULE_MAKE) sim-export MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS)

module-fsdb:
	$(MODULE_MAKE) fsdb MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) RUN_EXPORT=$(MODULE_RUN_EXPORT)

module-fsdb-export:
	$(MODULE_MAKE) fsdb-export MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS)

# BD/IP 变更后：与 E2E 共用同一套 Vivado export
module-export: export

module-verdi:
	$(MODULE_MAKE) verdi

module-data:
	$(MODULE_MAKE) data MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS)

module-list-cases:
	$(MODULE_MAKE) list-cases MODULE_CASE=$(MODULE_CASE)

module-sim-batch:
	$(MODULE_MAKE) sim-batch MODULE_CASE=$(MODULE_CASE) BATCH_SUITE=$(BATCH_SUITE) \
		MODULE_VARIANTS="$(MODULE_VARIANTS)" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
		RUN_EXPORT=$(MODULE_RUN_EXPORT) STOP_ON_FAIL=$(STOP_ON_FAIL)

module-sim-batch-export:
	$(MODULE_MAKE) sim-batch-export MODULE_CASE=$(MODULE_CASE) BATCH_SUITE=$(BATCH_SUITE) \
		MODULE_VARIANTS="$(MODULE_VARIANTS)" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
		STOP_ON_FAIL=$(STOP_ON_FAIL)

module-data-batch:
	$(MODULE_MAKE) data-batch MODULE_CASE=$(MODULE_CASE) BATCH_SUITE=$(BATCH_SUITE) \
		MODULE_VARIANTS="$(MODULE_VARIANTS)" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS)

module-list-suites:
	$(MODULE_MAKE) list-suites

module-sim-ps:
	$(MODULE_MAKE) sim-ps

module-sim-watch:
	$(MODULE_MAKE) sim-watch

module-sim-done:
	$(MODULE_MAKE) sim-done

module-clean:
	$(MODULE_MAKE) clean

module-help:
	$(MODULE_MAKE) help

help:
	@echo "lite BD VCS Makefile"
	@echo ""
	@echo "Re-export rule:"
	@echo "  RTL/TB/Python-only changes: do NOT export; run make sim-fast/sim-hbm/sim-fsdb."
	@echo "  BD/IP/address/wrapper changes: run make export or make sim-export."
	@echo ""
	@echo "Targets:"
	@echo "  make export                Vivado export_simulation only"
	@echo "  make sim / sim-fast        Fast BD mode; recommended daily flow"
	@echo "  make sim-export            Export first, then fast BD mode"
	@echo "  make sim-hbm               HBM-first mode; closest to hardware, slow"
	@echo "  make sim-hbm-export        Export first, then HBM-first mode"
	@echo "  make sim-fsdb              Fast BD mode with FSDB dump"
	@echo "  make sim-fsdb-export       Export first, then FSDB simulation"
	@echo "  make summary               Print key PASS/FAIL lines from sim.log"
	@echo "  make verdi                 Open $(FSDB)"
	@echo "  make clean                 Remove $(BUILD_DIR)"
	@echo ""
	@echo "module_tb (forward to $(MODULE_TB_DIR)):"
	@echo "  make module-sim            Single-module BD test"
	@echo "  make module-sim-batch      BATCH_SUITE=dcim_tiny | dcim_smoke | dcim_network"
	@echo "  make module-sim-export     Export first, then module test"
	@echo "  make module-sim-batch-export  Export first, then batch"
	@echo "  make module-fsdb           Module test with FSDB"
	@echo "  make module-fsdb-export    Export first, then module FSDB"
	@echo "  make module-export         Alias of make export (shared BD export)"
	@echo "  make module-verdi          Open module_tb FSDB / KDB"
	@echo "  make module-data           Generate module hex/manifest only"
	@echo "  make module-list-cases     List variants for MODULE_CASE"
	@echo "  make module-list-suites    List BATCH_SUITE presets"
	@echo "  make module-data-batch     Generate hex for a batch (no sim)"
	@echo "  make module-sim-ps         sim running? (PID, CPU%%)"
	@echo "  make module-sim-watch      refresh every 5s"
	@echo "  make module-sim-done       PASS / FAIL / RUNNING"
	@echo "  make module-clean          Remove module_tb build dir"
	@echo "  make module-help           module_tb target help"
	@echo ""
	@echo "E2E variables:"
	@echo "  BD_CASE=$(BD_CASE)"
	@echo "  BD_SCALE=$(BD_SCALE)"
	@echo "  BD_VERIFY_WORDS=$(BD_VERIFY_WORDS)"
	@echo "  SKIP_LITE_COMPILE=$(SKIP_LITE_COMPILE)"
	@echo ""
	@echo "module_tb variables:"
	@echo "  MODULE_CASE=$(MODULE_CASE)"
	@echo "  MODULE_VARIANT=$(MODULE_VARIANT)"
	@echo "  MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS)"
	@echo "  MODULE_RUN_EXPORT=$(MODULE_RUN_EXPORT)"
