# ==============================================================================
# lite BD VCS 仿真 — 顶层 Makefile
# 工作目录：rtl/tb/lite_bd/
# ==============================================================================
#
# ── 何时需要重新 export？─────────────────────────────────────────────────────
# 不需要（最常见）：修改 RTL / Python golden / TB SV → 直接 make sim-fast
# 需要（约 5~10min）：增删 Vivado IP、改 BD 结构/地址映射 → make export
#
# ── E2E 仿真档位 ─────────────────────────────────────────────────────────────
# make sim-fast   快速（Host 直写 OBUF/IBUF，不经 HBM）  ← 日常推荐
# make sim-hbm    HBM-first（最接近硬件，慢）           ← sign-off 用
#
# ── 完整功能验证（一键）─────────────────────────────────────────────────────
# 覆盖 DCIM INT8/INT16、VPU QA/DQA INT8/INT16、im2col/MP/US、端到端链路：
#
#   make module-sim-all                  # 从本目录调 module_tb sim-all
#
# ── 分类测试快查 ─────────────────────────────────────────────────────────────
# DCIM：
#   make module-sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all
# VPU（量化/反量化）：
#   make module-sim-batch MODULE_CASE=qa  BATCH_SUITE=qa_all
#   make module-sim-batch MODULE_CASE=dqa BATCH_SUITE=dqa_all
#   make module-sim-batch MODULE_CASE=dqa BATCH_SUITE=dqa_int16_all
# im2col：
#   make module-sim-batch MODULE_CASE=im2col BATCH_SUITE=im2col_all
# 端到端链路（im2col→DCIM→DQA→QA）：
#   make module-sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all
# 单用例调试：
#   make module-sim MODULE_CASE=dqa MODULE_VARIANT=dqa_accum16_c32
#   make module-fsdb MODULE_CASE=qa  MODULE_VARIANT=qa_int16_c32_signed
# ==============================================================================

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
QUANT ?= int8
DIM ?=

MODULE_MAKE = $(MAKE) -C $(MODULE_TB_DIR)

.PHONY: help export sim sim-fast sim-export sim-hbm sim-hbm-export sim-fsdb sim-fsdb-export verdi waves summary clean
.PHONY: module-sim module-sim-export module-fsdb module-fsdb-export module-export module-sim-all module-sim-results
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
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) RUN_EXPORT=$(MODULE_RUN_EXPORT) \
		QUANT=$(QUANT) DIM="$(DIM)"

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

module-sim-all:
	$(MODULE_MAKE) sim-all STOP_ON_FAIL=$(STOP_ON_FAIL)

module-sim-results:
	$(MODULE_MAKE) sim-results

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
		RUN_EXPORT=$(MODULE_RUN_EXPORT) STOP_ON_FAIL=$(STOP_ON_FAIL) QUANT=$(QUANT) DIM="$(DIM)"

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
	@echo "lite BD VCS Makefile  (工作目录: rtl/tb/lite_bd/)"
	@echo ""
	@echo "完整功能验证（一键）："
	@echo "  make module-sim-all              覆盖所有模块 INT8+INT16"
	@echo "  make module-sim-results          查看全量 PASS/FAIL 汇总（sim-all 后运行）"
	@echo ""
	@echo "E2E 仿真（整包 BD，含 PCIe/XDMA 路径）："
	@echo "  make sim-fast                    快速 (Host 直写)，日常 RTL 改动后用"
	@echo "  make sim-hbm                     HBM-first，最接近硬件，sign-off 用"
	@echo "  make sim-export                  export 后跑 fast"
	@echo "  make sim-fsdb                    fast + 波形 dump"
	@echo "  make summary                     打印上次仿真 PASS/FAIL 摘要"
	@echo ""
	@echo "module_tb（单模块驱动 BD，速度快，覆盖全）："
	@echo "  make module-sim-all              全量（推荐）"
	@echo "  make module-sim-results          全量 PASS/FAIL 汇总"
	@echo "  make module-sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all QUANT=all"
	@echo "  make module-sim-batch MODULE_CASE=qa          BATCH_SUITE=qa_all   QUANT=all"
	@echo "  make module-sim-batch MODULE_CASE=dqa         BATCH_SUITE=dqa_all  QUANT=all"
	@echo "  make module-sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all"
	@echo "  make module-sim MODULE_CASE=dqa MODULE_VARIANT=dqa_c64_mid QUANT=int16"
	@echo "  make module-sim MODULE_CASE=qa  MODULE_VARIANT=qa_c16_signed DIM=HW=6x6,C=32"
	@echo "  make module-list-suites          列出全部 BATCH_SUITE"
	@echo ""
	@echo "需要重新 export（增删 IP / 改 BD 结构）："
	@echo "  make export"
	@echo "  make module-sim-all              export 后接上面即可"
