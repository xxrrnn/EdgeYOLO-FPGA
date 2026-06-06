# ==============================================================================
# lite BD — 顶层 Makefile
# 工作目录：rtl/tb/lite_bd/
# ==============================================================================
#
# 本目录包含两类流程：
#
# 1) module_tb 数值回归（推荐日常 RTL 验证）
#    实现于 module_tb/Makefile，此处以 module-* 前缀转发：
#      make module-sim-smoke      改 RTL 后：小规模 unit+pipeline，全量 golden（推荐）
#      make module-sim-unit       全部 unit
#      make module-sim-pipeline   全部 pipeline（算子级）
#      make module-sim-all        unit + pipeline 全量
#      make module-sim-results    汇总 PASS/FAIL
#    也可：cd module_tb && make sim-smoke
#
# 2) E2E 系统仿真（整包 BD + Host BFM 模拟 XDMA，3 层 conv 指令链）
#      make sim-fast   快速预加载 OBUF/IBUF（日常）
#      make sim-hbm    HBM-first，最接近硬件（慢）
#      make sim-fsdb   fast + FSDB 波形
#
# 3) Vivado 综合 / 实现 / bitstream（在仓库根目录执行，非本 Makefile）
#    完整流程 0→1→2→3（建工程 → BD → 综合 → 实现 → 报告）：
#      cd <REPO_ROOT>
#      vivado -mode batch -source scripts/chip-lite/run.tcl
#    从 checkpoint 续跑（不重跑 BD/综合）：
#      RESUME_FROM=opt   vivado -mode batch -source scripts/chip-lite/run.tcl
#      RESUME_FROM=place vivado -mode batch -source scripts/chip-lite/run.tcl
#    仅 export 仿真网表（module_tb / E2E 仿真前提）：
#      make export                       # 自动选最新 build
#      make export BUILD_TAG=20260606_143000   # 指定特定 build
#      # 等价：BUILD_TAG=<tag> vivado -mode batch -source scripts/chip-lite/export_sim.tcl
#
# 【何时 make export】
#   增删 Vivado IP、改 BD 拓扑、AXI 地址映射、DCIM module_ref 参数 → 需要 export
#   只改 RTL / Python golden / TB SV → 不必 export，直接 module-sim 或 sim-fast
# ==============================================================================

REPO_ROOT := $(abspath ../../..)
SIM_DIR   := $(abspath sim)
BUILD_DIR := $(SIM_DIR)/build_bd_sim
SIM_LOG   := $(BUILD_DIR)/sim.log
FSDB      := $(BUILD_DIR)/tb_lite_bd_e2e.fsdb
EXPORT_TCL := $(REPO_ROOT)/scripts/chip-lite/export_sim.tcl
CHIP_LITE_RUN_TCL := $(REPO_ROOT)/scripts/chip-lite/run.tcl

# BUILD_TAG：指定要操作哪个 build（与 run.tcl / export_sim.tcl 共用）
#   不指定时 export 自动选取 build/lite/ 下最新的已有工程
#   示例：make export BUILD_TAG=20260606_143000
#         make export BUILD_TAG=aggressive
BUILD_TAG ?=

# E2E 仿真变量
BD_CASE ?= default
BD_SCALE ?= 0.1
BD_VERIFY_WORDS ?= 8
SKIP_LITE_COMPILE ?= 1
XILINX_VCS_LIB ?= /data/home/rn_xu29/Tools/vcs_lib
VIVADO_HOME ?= /home/EDAtools/Xilinx/Vivado/2024.2

# module_tb 转发默认（子目录 Makefile 可覆盖）
MODULE_TB_DIR := $(abspath module_tb)
MODULE_CASE ?= dcim_matmul
MODULE_VARIANT ?= dcim_tiny_1x1
MODULE_VERIFY_WORDS ?= 0
STOP_ON_FAIL ?= 1
BATCH_SUITE ?=
QUANT ?= int8
DIM ?=

MODULE_MAKE = $(MAKE) -C $(MODULE_TB_DIR)

.PHONY: help export sim sim-fast sim-export sim-hbm sim-hbm-export sim-fsdb sim-fsdb-export verdi waves summary clean
.PHONY: module-sim module-sim-export module-export module-sim-smoke module-sim-unit-smoke module-sim-pipeline-smoke
.PHONY: module-sim-unit module-sim-pipeline module-sim-all module-sim-results
.PHONY: module-sim-batch module-fsdb module-help module-clean

# ==============================================================================
# Vivado export（仿真网表，约 5~10 min）
# ==============================================================================

export:
	@echo "[export] Vivado export_simulation → sim/lite_bd_export/ $(if $(BUILD_TAG), (BUILD_TAG=$(BUILD_TAG)))"
	cd $(REPO_ROOT) && $(if $(BUILD_TAG),BUILD_TAG=$(BUILD_TAG),) vivado -mode batch -source $(EXPORT_TCL)

# ==============================================================================
# E2E 仿真（tb_lite_bd_e2e.sv + run_bd_sim.sh）
# ==============================================================================

sim: sim-fast

# fast：Host 直写 OBUF/IBUF，不经 HBM 初始化链（改 RTL 后日常用这个）
sim-fast:
	XILINX_VCS_LIB=$(XILINX_VCS_LIB) VIVADO_HOME=$(VIVADO_HOME) \
	BD_MODE=fast BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) \
	BD_VERIFY_WORDS=$(BD_VERIFY_WORDS) SKIP_LITE_COMPILE=$(SKIP_LITE_COMPILE) \
	bash sim/run_bd_sim.sh

sim-export: export
	$(MAKE) sim-fast SKIP_LITE_COMPILE=0 BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) BD_VERIFY_WORDS=$(BD_VERIFY_WORDS)

# hbm：加载 hbm_image.hex，走 HBM→CDMA 预加载（sign-off，很慢）
sim-hbm:
	XILINX_VCS_LIB=$(XILINX_VCS_LIB) VIVADO_HOME=$(VIVADO_HOME) \
	BD_MODE=hbm BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) \
	BD_VERIFY_WORDS=$(BD_VERIFY_WORDS) SKIP_LITE_COMPILE=$(SKIP_LITE_COMPILE) \
	bash sim/run_bd_sim.sh

sim-hbm-export: export
	$(MAKE) sim-hbm SKIP_LITE_COMPILE=0 BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) BD_VERIFY_WORDS=$(BD_VERIFY_WORDS)

sim-fsdb:
	XILINX_VCS_LIB=$(XILINX_VCS_LIB) VIVADO_HOME=$(VIVADO_HOME) \
	BD_MODE=fast BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) \
	BD_VERIFY_WORDS=$(BD_VERIFY_WORDS) SKIP_LITE_COMPILE=$(SKIP_LITE_COMPILE) \
	VCS_DUMP=1 DUMP_FSDB=$(FSDB) bash sim/run_bd_sim.sh

sim-fsdb-export: export
	$(MAKE) sim-fsdb SKIP_LITE_COMPILE=0 BD_CASE=$(BD_CASE) BD_SCALE=$(BD_SCALE) BD_VERIFY_WORDS=$(BD_VERIFY_WORDS)

summary:
	@if [ -f $(SIM_LOG) ]; then \
		grep -E 'compare L|PASS,|FAIL ---|GRAND|ALL CHECKPOINTS|SOME CHECKPOINTS|FATAL|HOST_BFM|BD_E2E' $(SIM_LOG) | tail -60; \
	else echo "No $(SIM_LOG)"; fi

verdi waves:
	@if [ -f $(FSDB) ]; then verdi -ssf $(FSDB) &; \
	else echo "No FSDB: $(FSDB) — run make sim-fsdb"; exit 1; fi

clean:
	rm -rf $(BUILD_DIR)

# ==============================================================================
# module_tb 转发（详见 module_tb/Makefile）
# ==============================================================================

module-export: export

module-sim-smoke:
	$(MODULE_MAKE) sim-smoke STOP_ON_FAIL=$(STOP_ON_FAIL)

module-sim-unit-smoke:
	$(MODULE_MAKE) sim-unit-smoke STOP_ON_FAIL=$(STOP_ON_FAIL)

module-sim-pipeline-smoke:
	$(MODULE_MAKE) sim-pipeline-smoke STOP_ON_FAIL=$(STOP_ON_FAIL)

module-sim-unit:
	$(MODULE_MAKE) sim-unit STOP_ON_FAIL=$(STOP_ON_FAIL)

module-sim-pipeline:
	$(MODULE_MAKE) sim-pipeline STOP_ON_FAIL=$(STOP_ON_FAIL)

module-sim-all:
	$(MODULE_MAKE) sim-all STOP_ON_FAIL=$(STOP_ON_FAIL)

module-sim-results:
	$(MODULE_MAKE) sim-results

module-sim:
	$(MODULE_MAKE) sim MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) QUANT=$(QUANT) DIM="$(DIM)"

module-sim-export:
	$(MODULE_MAKE) sim-export MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS)

module-sim-batch:
	$(MODULE_MAKE) sim-batch MODULE_CASE=$(MODULE_CASE) BATCH_SUITE=$(BATCH_SUITE) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) STOP_ON_FAIL=$(STOP_ON_FAIL) QUANT=$(QUANT) DIM="$(DIM)"

module-fsdb:
	$(MODULE_MAKE) fsdb MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS)

module-clean:
	$(MODULE_MAKE) clean

module-help:
	$(MODULE_MAKE) help

help:
	@echo "lite BD Makefile  (rtl/tb/lite_bd/)"
	@echo ""
	@echo "module_tb 回归："
	@echo "  make module-sim-smoke    RTL 改后小规模冒烟"
	@echo "  make module-sim-unit | module-sim-pipeline | module-sim-all"
	@echo "  make module-sim-results"
	@echo ""
	@echo "E2E：make sim-fast | sim-hbm | sim-fsdb | export"
	@echo ""
	@echo "Vivado 综合实现（在仓库根目录）："
	@echo "  cd $(REPO_ROOT)"
	@echo "  vivado -mode batch -source scripts/chip-lite/run.tcl"
	@echo "  RESUME_FROM=place vivado -mode batch -source scripts/chip-lite/run.tcl"
