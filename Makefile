# ==============================================================================
# EdgeYOLO-FPGA-lite — 顶层 Makefile
# ==============================================================================
# 用法速查：
#   make synth                        # Project Mode 全流程（默认 tag = git short sha）
#   make synth-np                     # Non-Project Mode 全流程
#   make synth TAG=my_exp             # 自定义 tag
#   make synth-np TAG=np_test         # Non-Project Mode + 自定义 tag
#   make resume TAG=260612_2210 FROM=place   # 从 checkpoint 续跑
#   make bd TAG=my_exp                # 只跑 1_build + 2_bd（生成 IP DCP）
#
# 产物位置：build/lite/<tag>/，其中包含 logs/、SynOutputDir/、ImplOutputDir/、bitstreams/、summary/
# ==============================================================================

VIVADO     ?= vivado
SCRIPT_DIR  = scripts/chip-lite
RUN_TCL     = $(SCRIPT_DIR)/run.tcl

FROM       ?=
VIVADO_THREADS ?= 32
PLACE_THREADS  ?= 32
ROUTE_THREADS  ?= 32
SYNTH_JOBS     ?= 128
IMPL_FLOW      ?= two_stage
IMPL_ROUTE_TOP_K ?= 3
IMPL_JOBS      ?= 4
RACE_PLACE_THREADS ?= 16
RACE_ROUTE_THREADS ?= 16
RACE_STOP_ON_WIN ?= 1
RACE_POLL_SEC  ?= 60
RACE_MIN_WNS_NS ?= 0.05
RACE_MIN_WHS_NS ?= 0.02
RACE_INCREMENTAL_DCP ?=
RACE_INCREMENTAL_ATTEMPTS ?= 4

# TAG：命令行指定则用指定值；否则用当前 git short sha，便于把 bitstream 追溯到源码。
TAG ?= $(shell git rev-parse --short HEAD 2>/dev/null || date +%y%m%d_%H%M)

# BUILD_TAG 统一传入 Vivado（无论用户是否手动指定 TAG 都传入，保证 projPath 确定）
_TAG_ENV = BUILD_TAG=$(TAG) VIVADO_THREADS=$(VIVADO_THREADS) PLACE_THREADS=$(PLACE_THREADS) ROUTE_THREADS=$(ROUTE_THREADS) SYNTH_JOBS=$(SYNTH_JOBS) IMPL_FLOW=$(IMPL_FLOW) IMPL_ROUTE_TOP_K=$(IMPL_ROUTE_TOP_K)

_BUILD_DIR  = build/lite/$(TAG)
_LOG_DIR    = $(_BUILD_DIR)/logs
_LOG_PRJ    = $(_LOG_DIR)/$(TAG)_vivado_project.log
_LOG_NP     = $(_LOG_DIR)/$(TAG)_vivado_nonproj.log
_LOG_BD     = $(_LOG_DIR)/$(TAG)_vivado_bd.log
_LOG_RESUME = $(_LOG_DIR)/$(TAG)_vivado_resume_$(FROM).log

.PHONY: all synth synth-to-opt synth-np bd resume impl-race clean help

all: help

# ------------------------------------------------------------------------------
# synth: Project Mode 完整流程（create project → BD → synth → impl → bitstream）
# ------------------------------------------------------------------------------
synth:
	@mkdir -p $(_BUILD_DIR) $(_LOG_DIR)
	@echo "[Makefile] Project Mode | tag=$(TAG) | threads=$(VIVADO_THREADS) place=$(PLACE_THREADS) route=$(ROUTE_THREADS) jobs=$(SYNTH_JOBS) | log=$(_LOG_PRJ)"
	cd $(CURDIR) && $(_TAG_ENV) FLOW_MODE=project \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(RUN_TCL) \
	            -nojournal \
	            -log $(CURDIR)/$(_LOG_PRJ)

# 只运行到 post_opt.dcp，作为并行 implementation race 的共享起点。
synth-to-opt:
	@mkdir -p $(_BUILD_DIR) $(_LOG_DIR)
	@echo "[Makefile] Project Mode to post_opt | tag=$(TAG) | threads=$(VIVADO_THREADS) jobs=$(SYNTH_JOBS) | log=$(_LOG_PRJ)"
	cd $(CURDIR) && $(_TAG_ENV) FLOW_MODE=project STOP_AFTER=opt \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(RUN_TCL) \
	            -nojournal \
	            -log $(CURDIR)/$(_LOG_PRJ)

# ------------------------------------------------------------------------------
# synth-np: Non-Project Mode 全流程（需先有同 TAG 的 bd 产物）
# ------------------------------------------------------------------------------
synth-np:
	@mkdir -p $(_BUILD_DIR) $(_LOG_DIR)
	@echo "[Makefile] Non-Project Mode | tag=$(TAG) | threads=$(VIVADO_THREADS) place=$(PLACE_THREADS) route=$(ROUTE_THREADS) jobs=$(SYNTH_JOBS) | log=$(_LOG_NP)"
	cd $(CURDIR) && $(_TAG_ENV) FLOW_MODE=nonproj \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(RUN_TCL) \
	            -nojournal \
	            -log $(CURDIR)/$(_LOG_NP)

# ------------------------------------------------------------------------------
# bd: 只执行 1_build + 2_bd（生成 IP OOC DCP + stubs，为 Non-Project Mode 做准备）
# ------------------------------------------------------------------------------
bd:
	@mkdir -p $(_BUILD_DIR) $(_LOG_DIR)
	@echo "[Makefile] BD only | tag=$(TAG) | threads=$(VIVADO_THREADS) place=$(PLACE_THREADS) route=$(ROUTE_THREADS) jobs=$(SYNTH_JOBS) | log=$(_LOG_BD)"
	cd $(CURDIR) && $(_TAG_ENV) FLOW_MODE=project \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(SCRIPT_DIR)/run_bd_only.tcl \
	            -nojournal \
	            -log $(CURDIR)/$(_LOG_BD)

# ------------------------------------------------------------------------------
# resume: 从指定 checkpoint 续跑（必须同时指定 TAG 和 FROM）
#   FROM 可选值: opt | place | phys_opt
#   例: make resume TAG=260612_2210 FROM=place
# ------------------------------------------------------------------------------
resume:
ifndef TAG
	$(error 续跑必须指定 TAG，例如: make resume TAG=260612_2210 FROM=place)
endif
ifndef FROM
	$(error 续跑必须指定 FROM，例如: make resume TAG=260612_2210 FROM=place)
endif
	@mkdir -p $(_BUILD_DIR) $(_LOG_DIR)
	@echo "[Makefile] Resume from=$(FROM) | tag=$(TAG) | threads=$(VIVADO_THREADS) place=$(PLACE_THREADS) route=$(ROUTE_THREADS) jobs=$(SYNTH_JOBS) | log=$(_LOG_RESUME)"
	cd $(CURDIR) && $(_TAG_ENV) RESUME_FROM=$(FROM) \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(RUN_TCL) \
	            -nojournal \
	            -log $(CURDIR)/$(_LOG_RESUME)

# 从 post_opt.dcp 并行运行多个 place/route 策略。当前发布 bitstream 使用
# attempt1_clean_ExtraTimingOpt_AggressiveExplore_AggressiveExplore。
impl-race:
	@mkdir -p $(_BUILD_DIR) $(_LOG_DIR)
	@echo "[Makefile] Impl race | tag=$(TAG) | jobs=$(IMPL_JOBS) | place=$(RACE_PLACE_THREADS) route=$(RACE_ROUTE_THREADS)"
	cd $(CURDIR) && TAG=$(TAG) VIVADO=$(VIVADO) \
	  VIVADO_THREADS=$(VIVADO_THREADS) PLACE_THREADS=$(RACE_PLACE_THREADS) ROUTE_THREADS=$(RACE_ROUTE_THREADS) \
	  SYNTH_JOBS=$(SYNTH_JOBS) IMPL_JOBS=$(IMPL_JOBS) \
	  RACE_STOP_ON_WIN=$(RACE_STOP_ON_WIN) RACE_POLL_SEC=$(RACE_POLL_SEC) \
	  RACE_MIN_WNS_NS=$(RACE_MIN_WNS_NS) RACE_MIN_WHS_NS=$(RACE_MIN_WHS_NS) \
	  RACE_INCREMENTAL_DCP="$(RACE_INCREMENTAL_DCP)" RACE_INCREMENTAL_ATTEMPTS=$(RACE_INCREMENTAL_ATTEMPTS) \
	  bash scripts/chip-lite/impl_race.sh

# ------------------------------------------------------------------------------
# clean: 删除 build/ 目录下所有产物（不可恢复！）
# ------------------------------------------------------------------------------
clean:
	@echo "[Makefile] Removing build/"
	rm -rf build/

help:
	@echo ""
	@echo "EdgeYOLO-FPGA-lite Build Targets"
	@echo "================================="
	@echo "  make synth              Project Mode 全流程（auto tag）"
	@echo "  make synth-to-opt       只跑到 post_opt.dcp，用于 impl-race"
	@echo "  make synth TAG=foo      Project Mode，指定 tag"
	@echo "  make synth-np TAG=foo   Non-Project Mode（需已有同 TAG 的 bd 产物）"
	@echo "  make bd    TAG=foo      只跑 BD（1_build + 2_bd，为 nonproj 做准备）"
	@echo "  make resume TAG=foo FROM=opt    从 post_opt 启动两阶段实现竞速"
	@echo "      默认 3 个 place 并行、筛选后只跑 3 个 route；IMPL_ROUTE_TOP_K 可调整"
	@echo "  make resume TAG=foo FROM=place  从单个 post_place checkpoint 续跑"
	@echo "  make impl-race TAG=foo IMPL_JOBS=8 RACE_PLACE_THREADS=16 RACE_ROUTE_THREADS=16"
	@echo "      IMPL_JOBS 最大为 8；可用 RACE_MIN_WNS_NS/RACE_MIN_WHS_NS 设置验收裕量"
	@echo "    FROM 可选: opt | place | phys_opt"
	@echo "  make synth VIVADO_THREADS=32 PLACE_THREADS=32 ROUTE_THREADS=32 SYNTH_JOBS=128"
	@echo "      两阶段流程最多并行 3 个 Vivado 进程，约使用 96 个 CPU 线程"
	@echo ""
	@echo "默认 TAG: git short sha"
	@echo "唯一产物根目录: build/lite/<tag>/"
	@echo "  logs/         Vivado logs and journals"
	@echo "  SynOutputDir/ synthesis checkpoints/reports"
	@echo "  ImplOutputDir implementation checkpoints/reports/race attempts"
	@echo "  bitstreams/   timing-met bitstreams copied from race attempts"
	@echo "  summary/      impl-race TSV/Markdown summary"
	@echo ""
