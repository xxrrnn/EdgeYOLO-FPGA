# ==============================================================================
# EdgeYOLO-FPGA-lite — 顶层 Makefile
# ==============================================================================
# 用法速查：
#   make synth                        # Project Mode 全流程（自动时间戳 tag）
#   make synth-np                     # Non-Project Mode 全流程
#   make synth TAG=my_exp             # 自定义 tag
#   make synth-np TAG=np_test         # Non-Project Mode + 自定义 tag
#   make resume TAG=260612_2210 FROM=place   # 从 checkpoint 续跑
#   make bd TAG=my_exp                # 只跑 1_build + 2_bd（生成 IP DCP）
#
# 日志位置：build/lite/<tag>/vivado_<mode>.log
# 产物位置：build/lite/<tag>/SynOutputDir/  build/lite/<tag>/ImplOutputDir/
# ==============================================================================

VIVADO     ?= vivado
SCRIPT_DIR  = scripts/chip-lite
RUN_TCL     = $(SCRIPT_DIR)/run.tcl

FROM       ?=

# TAG：命令行指定则用指定值；否则在 Makefile 层面生成时间戳（与 config.tcl 格式相同 yymmdd_HHMM）
# 这样日志目录与 Vivado 内部 projPath 始终一致。
TAG ?= $(shell date +%y%m%d_%H%M)

# BUILD_TAG 统一传入 Vivado（无论用户是否手动指定 TAG 都传入，保证 projPath 确定）
_TAG_ENV = BUILD_TAG=$(TAG)

_LOG_DIR    = build/lite/$(TAG)
_LOG_PRJ    = $(_LOG_DIR)/vivado_project.log
_LOG_NP     = $(_LOG_DIR)/vivado_nonproj.log
_LOG_BD     = $(_LOG_DIR)/vivado_bd.log
_LOG_RESUME = $(_LOG_DIR)/vivado_resume_$(FROM).log

.PHONY: all synth synth-np bd resume clean help

all: help

# ------------------------------------------------------------------------------
# synth: Project Mode 完整流程（create project → BD → synth → impl → bitstream）
# ------------------------------------------------------------------------------
synth:
	@mkdir -p $(_LOG_DIR)
	@echo "[Makefile] Project Mode | tag=$(TAG) | log=$(_LOG_PRJ)"
	cd $(_LOG_DIR) && $(_TAG_ENV) FLOW_MODE=project \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(RUN_TCL) \
	            -nojournal \
	            -log vivado_project.log

# ------------------------------------------------------------------------------
# synth-np: Non-Project Mode 全流程（需先有同 TAG 的 bd 产物）
# ------------------------------------------------------------------------------
synth-np:
	@mkdir -p $(_LOG_DIR)
	@echo "[Makefile] Non-Project Mode | tag=$(TAG) | log=$(_LOG_NP)"
	cd $(_LOG_DIR) && $(_TAG_ENV) FLOW_MODE=nonproj \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(RUN_TCL) \
	            -nojournal \
	            -log vivado_nonproj.log

# ------------------------------------------------------------------------------
# bd: 只执行 1_build + 2_bd（生成 IP OOC DCP + stubs，为 Non-Project Mode 做准备）
# ------------------------------------------------------------------------------
bd:
	@mkdir -p $(_LOG_DIR)
	@echo "[Makefile] BD only | tag=$(TAG) | log=$(_LOG_BD)"
	cd $(_LOG_DIR) && $(_TAG_ENV) FLOW_MODE=project \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(SCRIPT_DIR)/run_bd_only.tcl \
	            -nojournal \
	            -log vivado_bd.log

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
	@mkdir -p $(_LOG_DIR)
	@echo "[Makefile] Resume from=$(FROM) | tag=$(TAG) | log=$(_LOG_RESUME)"
	cd $(_LOG_DIR) && BUILD_TAG=$(TAG) RESUME_FROM=$(FROM) \
	  $(VIVADO) -mode batch \
	            -source $(CURDIR)/$(RUN_TCL) \
	            -nojournal \
	            -log vivado_resume_$(FROM).log

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
	@echo "  make synth TAG=foo      Project Mode，指定 tag"
	@echo "  make synth-np TAG=foo   Non-Project Mode（需已有同 TAG 的 bd 产物）"
	@echo "  make bd    TAG=foo      只跑 BD（1_build + 2_bd，为 nonproj 做准备）"
	@echo "  make resume TAG=foo FROM=place  从 checkpoint 续跑"
	@echo "    FROM 可选: opt | place | phys_opt"
	@echo ""
	@echo "日志: build/lite/<tag>/vivado_<mode>.log"
	@echo "产物: build/lite/<tag>/SynOutputDir/  ImplOutputDir/"
	@echo ""
