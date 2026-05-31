# ==============================================================================
# module_tb — 模块级 VCS 仿真（直接驱动 lite BD，绕过主机 PCIe/XDMA）
# 工作目录：rtl/tb/lite_bd/module_tb/
# ==============================================================================
#
# ── 前提 ──────────────────────────────────────────────────────────────────────
# Vivado export 仅在以下情况才需要重新执行：
#   BD/IP 结构/版本变化（增删 IP、新 IP 如 fp32_to_int16、地址映射变更）
#   → make export（约 5~10 分钟，共享给 E2E 和 module_tb）
# 日常 RTL/Python 修改后：
#   → make compile          只重编 simv（RTL 改动后必须执行）
#   → make rebuild-suite    重编 + 连跑（RTL 改后推荐）
#
# ── 完整功能验证（一键）──────────────────────────────────────────────────────
# 覆盖所有子模块（DCIM INT8/INT16、VPU INT32/INT16、im2col、MP/US/AD、端到端）：
#
#   make sim-all                    # 顺序跑全量，STOP_ON_FAIL=1（推荐）
#   make sim-all STOP_ON_FAIL=0     # 全跑完再报告
#
# ── 分类测试（按模块单独跑）─────────────────────────────────────────────────
#
#   [DCIM 矩阵乘]                   MODULE_CASE=dcim_matmul
#     make sim-batch BATCH_SUITE=dcim_smoke         # 快速冒烟（5 INT8）
#     make sim-batch BATCH_SUITE=dcim_all           # INT8 + INT16（8 个）
#     make sim-batch BATCH_SUITE=dcim_extreme       # 极限规模（4 个）
#
#   [VPU 量化 / 反量化]             MODULE_CASE=qa 或 dqa
#     make sim-batch MODULE_CASE=qa  BATCH_SUITE=qa_all    # fp32→int8/int16（4）
#     make sim-batch MODULE_CASE=dqa BATCH_SUITE=dqa_all   # int32/accum16→fp32（5）
#
#   [im2col / 上下采样 / MaxPool]
#     make sim-batch MODULE_CASE=im2col BATCH_SUITE=im2col_all
#     make sim-batch MODULE_CASE=mp     BATCH_SUITE=mp_all
#     make sim-batch MODULE_CASE=us     BATCH_SUITE=us_all
#
#   [端到端链路（im2col→CDMA→DCIM→DQA/QA）]  MODULE_CASE=conv_pipeline
#     make sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all
#
# ── 单用例调试 ────────────────────────────────────────────────────────────────
#   make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
#   make sim MODULE_CASE=qa          MODULE_VARIANT=qa_int16_c32_signed
#   make sim MODULE_CASE=dqa         MODULE_VARIANT=dqa_accum16_c32
#   make fsdb MODULE_CASE=dqa MODULE_VARIANT=dqa_accum16_c32  # 带波形
#   make verdi                                                  # 打开 Verdi
#
# ── 选项 ──────────────────────────────────────────────────────────────────────
#   STOP_ON_FAIL=1（默认）批量遇 FAIL 立刻停；=0 跑完全部
#   MODULE_VERIFY_WORDS=N  只校验前 N 个 128-bit word（0=全量，默认全量）
#   LOG=1                  sim-batch 同时写 sim_batch.log
#   FAST=1（默认）编译跳过 -debug_access；=0 保留（Verdi 需要）
#   PRELOAD_MODE=backdoor（默认）直接初始化 IBUF/OBUF/WB RTL 存储，做快速数值回归
#   PRELOAD_MODE=axi 通过 host AXI BFM 预加载，仅建议小 smoke 抽查地址映射
# ==============================================================================

MODULE_CASE ?= dcim_matmul
MODULE_VARIANT ?= dcim_tiny_1x1
MODULE_VERIFY_WORDS ?= 0
STOP_ON_FAIL ?= 1
BATCH_SUITE ?=
MODULE_VARIANTS ?=
LOG ?= 0
FAST ?= 1
VCS_JOBS ?= 64
SIMV_JOBS ?= 32
WATCH_INTERVAL ?= 5
# PRELOAD_MODE:
#   backdoor  → 默认，直接写 RTL 内部 IBUF/OBUF/WB 存储，保留 decoder/DCIM/VPU 数值路径
#   axi       → 通过 host AXI BFM 预加载，用于抽查 SmartConnect/地址映射，但大 case 很慢
PRELOAD_MODE ?= backdoor
# QUANT: int8 | int16 | all
#   int8  → 只跑 INT8 版本（默认）
#   int16 → 只跑 INT16 版本
#   all   → sim-batch 自动对每个变体跑 int8 + int16 两遍（_all suite 推荐用此）
QUANT ?= int8
# DIM: 覆盖测试用例的默认维度，格式：C=N  或  H=N,W=N,C=N  或  HW=HxW,C=N
#   例：make sim MODULE_CASE=qa MODULE_VARIANT=qa_c16_signed DIM="C=64,HW=6x6"
#   留空则使用 case 中定义的默认网络维度（覆盖支持的网络尺寸）
DIM ?=

MODULE_TB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT     := $(abspath $(MODULE_TB_DIR)/../../../..)
EXPORT_VCS_DIR := $(REPO_ROOT)/sim/lite_bd_export/vcs/lite/vcs
SIM_DIR       := $(MODULE_TB_DIR)/sim

# 共享编译目录 + 每个运行用例独立 RUN_DIR。VCS simv 只需编译/elaborate 一次。
_QUANT_SLUG := $(if $(filter all,$(QUANT)),allq,q$(QUANT))
_DIM_SLUG   := $(if $(DIM),_$(subst $(comma),_,$(subst =,,$(DIM))),)
comma       := ,
_VARIANT_SLUG := $(subst /,_,$(MODULE_CASE))_$(subst /,_,$(MODULE_VARIANT))_$(_QUANT_SLUG)$(_DIM_SLUG)
COMPILE_DIR   := $(SIM_DIR)/build_shared
RUN_DIR       := $(SIM_DIR)/run_$(_VARIANT_SLUG)
BUILD_DIR     := $(RUN_DIR)
RUN_SCRIPT    := $(SIM_DIR)/run_module_sim.sh
SIM_LOG       := $(RUN_DIR)/sim.log
FSDB_FILE     := $(RUN_DIR)/tb_lite_bd_module.fsdb
GOLDEN_PY     := $(MODULE_TB_DIR)/golden_module_tb.py
SIMV          := $(COMPILE_DIR)/simv
SUITE_DIR     := $(SIM_DIR)/suite_$(MODULE_CASE)

# 预置批量列表（make list-suites 查看全部）
# ── DCIM 矩阵乘（QUANT=int8|int16|all 控制精度）────────────────────────────
BATCH_SUITE_dcim_smoke      := dcim_tiny_1x1 conv3_s2_c32_to64
BATCH_SUITE_dcim_all        := dcim_tiny_1x1 conv6_s2_c3_to16 conv3_s2_c32_to64 conv1_c64_to32 conv3_c128_to128
BATCH_SUITE_dcim_extreme    := extreme_int8_1x1_c512_to512 extreme_int8_3x3_c128_to512 extreme_int8_6x6_c3_to64 extreme_int16_3x3_c128
BATCH_SUITE_dcim_network    := dcim_model_3_conv dcim_model_5_conv dcim_model_7_conv
# ── VPU 量化（QUANT=int8|int16|all 控制 fp32→int8 或 fp32→int16）────────────
BATCH_SUITE_qa_all          := qa_c16_signed qa_c64_clip qa_c128_dense qa_int16_c32_signed
# ── VPU 反量化（QUANT=int8→int32 accum，int16→accum16 输入）─────────────────
BATCH_SUITE_dqa_all         := dqa_c16_small dqa_c32_mid dqa_c64_mid dqa_c128_sppf dqa_c256_head dqa_nrelu_c24_in64 dqa_nrelu_c24_in128 dqa_nrelu_c24_in256 dqa_accum16_c32 dqa_accum16_c64
# ── 其他（QUANT 不影响这些模块，保持 int8 即可）──────────────────────────────
BATCH_SUITE_im2col_all      := im2col_6x6_s2_c3 im2col_3x3_s2_c32 im2col_3x3_s1_c128 im2col_1x1_c512
BATCH_SUITE_mp_all          := mp_sppf_128_10 mp_resnet_stem mp_gap_7x7_c512
BATCH_SUITE_us_all          := us_128_10_to20 us_64_20_to40
BATCH_SUITE_add_all         := add_residual_16 add_residual_32 add_pan_64
BATCH_SUITE_conv_pipe_all   := pipe_conv3_s2_c32_to64 pipe_conv1_c512_to64_tilepass
BATCH_SUITE_concat_all      := concat_2src_c64_c64_hw8x8 concat_2src_c128_c128_hw10x10 concat_4src_sppf_c128_hw10x10
BATCH_SUITE_large_channel_all := dcim_conv1_c512_to64_tilepass pipe_conv1_c512_to64_tilepass dqa_c256_pressure qa_c256_pressure concat_c128_c128_to256
BATCH_SUITE_mini_network_all := mini_2conv_c16 mini_3conv_residual_c32
.PHONY: export compile run sim sim-export fsdb fsdb-export verdi data clean help
.PHONY: list-cases list-suites check-export sim-all sim-results
.PHONY: sim-batch sim-batch-export data-batch _sim_batch_run _data_batch_run
.PHONY: data-suite run-suite sim-suite rebuild-suite
.PHONY: sim-ps sim-watch sim-done

# ── 核心 target ──────────────────────────────────────────────────────────────

export:
	@echo "[export] Vivado export_simulation（不跑仿真）"
	cd $(REPO_ROOT) && vivado -mode batch \
		-source $(REPO_ROOT)/scripts/chip-lite/4_export_sim.tcl

compile: check-export
	ACTION=compile COMPILE_DIR=$(COMPILE_DIR) FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

# sim-all：全量功能验证（顺序跑所有 suite）
# 覆盖：DCIM INT8/INT16 + VPU QA/DQA + im2col/MP/US/ADD/concat + 端到端/多层链路
sim-all: check-export
	@echo "=== [1/10] DCIM matmul INT8+INT16 (QUANT=all) ==="
	$(MAKE) sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [2/10] QA  fp32→int8 + fp32→int16 (QUANT=all) ==="
	$(MAKE) sim-batch MODULE_CASE=qa BATCH_SUITE=qa_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [3/10] DQA int32_accum + accum16→fp32 (QUANT=all) ==="
	$(MAKE) sim-batch MODULE_CASE=dqa BATCH_SUITE=dqa_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [4/10] im2col (INT8 only) ==="
	$(MAKE) sim-batch MODULE_CASE=im2col BATCH_SUITE=im2col_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [5/10] MP + US + ADD（FP32 数据路径）==="
	$(MAKE) sim-batch MODULE_CASE=mp BATCH_SUITE=mp_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	$(MAKE) sim-batch MODULE_CASE=us BATCH_SUITE=us_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	$(MAKE) sim-batch MODULE_CASE=add BATCH_SUITE=add_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [6/10] concat_by_cdma（通道拼接）==="
	$(MAKE) sim-batch MODULE_CASE=concat_by_cdma BATCH_SUITE=concat_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [7/10] conv_pipeline（端到端 INT8 + INT16）==="
	$(MAKE) sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [8/10] mini_network（多层链路 INT8 + INT16）==="
	$(MAKE) sim-batch MODULE_CASE=mini_network BATCH_SUITE=mini_network_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [9/10] large_channel_pressure（大通道压力）==="
	$(MAKE) sim-batch MODULE_CASE=large_channel_pressure BATCH_SUITE=large_channel_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== [10/10] DCIM extreme（64 Tile / 高 acc_depth）==="
	$(MAKE) sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_extreme QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo ""
	@echo "=== sim-all DONE — 运行 make sim-results 查看汇总 ==="

run: check-export
	ACTION=run COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

sim: check-export
	ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) MODULE_QUANT=$(QUANT) MODULE_DIM="$(DIM)" \
	FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

sim-export: export sim

fsdb: check-export
	ACTION=rebuild-sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) FAST=0 VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=1 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

fsdb-export: export fsdb

verdi:
	@if [ -f "$(FSDB_FILE)" ]; then verdi -ssf "$(FSDB_FILE)" -nologo & \
	elif [ -d "$(SIMV).daidir" ]; then verdi -simflow -simBin "$(SIMV)" -nologo & \
	else echo "先 make fsdb"; exit 1; fi

# ── 数据 / 列举 ──────────────────────────────────────────────────────────────

data:
	ACTION=gen RUN_DIR=$(RUN_DIR) MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) MODULE_QUANT=$(QUANT) MODULE_DIM="$(DIM)" bash $(RUN_SCRIPT)

data-suite:
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	[ -n "$$variants" ] || { echo "用法: make data-suite BATCH_SUITE=dcim_int8"; echo "      make list-suites"; exit 1; }; \
	ACTION=gen-suite COMPILE_DIR=$(COMPILE_DIR) SUITE_DIR=$(SUITE_DIR) MODULE_CASE=$(MODULE_CASE) \
		MODULE_VARIANTS="$$variants" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
		MODULE_QUANT=$(QUANT) MODULE_DIM="$(DIM)" bash $(RUN_SCRIPT)

run-suite: check-export
	ACTION=run-suite COMPILE_DIR=$(COMPILE_DIR) SUITE_DIR=$(SUITE_DIR) MODULE_CASE=$(MODULE_CASE) \
		FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

sim-suite: check-export
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	[ -n "$$variants" ] || { echo "用法: make sim-suite BATCH_SUITE=dcim_int8"; echo "      make list-suites"; exit 1; }; \
	ACTION=sim-suite COMPILE_DIR=$(COMPILE_DIR) SUITE_DIR=$(SUITE_DIR) MODULE_CASE=$(MODULE_CASE) \
		MODULE_VARIANTS="$$variants" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
		MODULE_QUANT=$(QUANT) MODULE_DIM="$(DIM)" \
		FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

rebuild-suite: check-export
	# 注意：rebuild-suite 会重新编译共享 simv，不可并行执行多个 rebuild-suite！
	# 并行运行多个 rebuild-suite 会损坏 build_shared/simv.daidir 数据库。
	# 如需同时跑多个 suite，先 make compile 一次，然后并行 make sim-suite。
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	[ -n "$$variants" ] || { echo "用法: make rebuild-suite BATCH_SUITE=dcim_int8"; echo "      make list-suites"; exit 1; }; \
	ACTION=rebuild-suite COMPILE_DIR=$(COMPILE_DIR) SUITE_DIR=$(SUITE_DIR) MODULE_CASE=$(MODULE_CASE) \
		MODULE_VARIANTS="$$variants" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
		MODULE_QUANT=$(QUANT) MODULE_DIM="$(DIM)" \
		FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

list-cases:
	python3 $(GOLDEN_PY) --module $(MODULE_CASE) --case list

list-suites:
	@echo "make sim-batch MODULE_CASE=<模块> BATCH_SUITE=<名称> [QUANT=int8|int16|all]"
	@echo ""
	@echo "  [DCIM 矩阵乘]  MODULE_CASE=dcim_matmul"
	@echo "    dcim_smoke    2 个快速冒烟"
	@echo "    dcim_all      5 个网络层（×QUANT=all 自动跑 int8+int16，共 10 次）"
	@echo "    dcim_extreme  4 个极限规模（含 INT16 大 acc_depth）"
	@echo "    dcim_network  3 个网络真实尺寸（慢）"
	@echo ""
	@echo "  [VPU 量化]     MODULE_CASE=qa"
	@echo "    qa_all        4 个用例（×QUANT=all 跑 fp32→int8 + fp32→int16）"
	@echo ""
	@echo "  [VPU 反量化]   MODULE_CASE=dqa"
	@echo "    dqa_all       10 个用例（ReLU/No-ReLU/accum16，×QUANT=all）"
	@echo ""
	@echo "  [im2col]       MODULE_CASE=im2col   QUANT 不影响，始终 INT8 输入"
	@echo "    im2col_all    4 种 kernel/stride 组合"
	@echo ""
	@echo "  [MP / US / ADD] QUANT 不影响（FP32 数据路径）"
	@echo "    mp_all        MODULE_CASE=mp"
	@echo "    us_all        MODULE_CASE=us"
	@echo "    add_all       MODULE_CASE=add"
	@echo ""
	@echo "  [concat]       MODULE_CASE=concat_by_cdma"
	@echo "    concat_all    2源/4源通道拼接"
	@echo ""
	@echo "  [端到端链路]   MODULE_CASE=conv_pipeline"
	@echo "    conv_pipe_all      im2col→CDMA→DCIM→DQA/ReLU→QA（2 种）"
	@echo ""
	@echo "  [多层完整链路] MODULE_CASE=mini_network"
	@echo "    mini_network_all   2层线性 + 3层 CSP residual（含 Add + QA）"
	@echo ""
	@echo "  [大通道压力]   MODULE_CASE=large_channel_pressure"
	@echo "    large_channel_all  c512/tilepass/c256/concat 压力用例"

# ── export 检查 ──────────────────────────────────────────────────────────────

check-export:
	@test -f "$(EXPORT_VCS_DIR)/lite.sh" || { \
		echo "ERROR: export 不完整，缺少 lite.sh"; \
		echo "  → 请运行: make export"; exit 1; }
	@test -f "$(REPO_ROOT)/build/lite/lite.ip_user_files/bd/lite/ip/lite_dcim_array_0_0/sim/lite_dcim_array_0_0.v" || { \
		echo "ERROR: 缺少 build/lite/lite.ip_user_files/...lite_dcim_array_0_0.v"; \
		echo "  → Vivado 未生成 BD IP 仿真文件，请运行: make export"; exit 1; }

# ── 批量仿真 ─────────────────────────────────────────────────────────────────

sim-batch: check-export _sim_batch_run

sim-batch-export: export
	@$(MAKE) sim-batch BATCH_SUITE=$(BATCH_SUITE) MODULE_CASE=$(MODULE_CASE) \
		MODULE_VARIANTS="$(MODULE_VARIANTS)" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
		FAST=$(FAST) STOP_ON_FAIL=$(STOP_ON_FAIL)

data-batch: _data_batch_run

_sim_batch_run:
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	if [ -z "$$variants" ]; then \
		echo "用法: make sim-batch BATCH_SUITE=dcim_all [QUANT=int8|int16|all]"; \
		echo "      make list-suites"; exit 1; fi; \
	quant_list="$(QUANT)"; \
	[ "$$quant_list" = "all" ] && quant_list="int8 int16"; \
	log="$(BUILD_DIR)/sim_batch.log"; mkdir -p "$(BUILD_DIR)"; \
	passed=0; failed=0; total=0; \
	for q in $$quant_list; do \
	for v in $$variants; do \
		total=$$((total+1)); \
		echo ""; echo ">>> [$$total] $(MODULE_CASE)/$$v  quant=$$q  $(shell date '+%H:%M:%S')"; \
		bd="$(SIM_DIR)/run_$(MODULE_CASE)_$${v}_q$${q}"; \
		if [ "$(LOG)" = "1" ]; then \
			: > "$$log"; \
			echo "    log → $$log"; \
			( ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR="$$bd" \
				MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$$v MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
				MODULE_QUANT=$$q MODULE_DIM="$(DIM)" \
				FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT) 2>&1 | tee -a "$$log" ); rc=$${PIPESTATUS[0]}; \
		else \
			( ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR="$$bd" \
				MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$$v MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
				MODULE_QUANT=$$q MODULE_DIM="$(DIM)" \
				FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT) 2>&1 ); rc=$$?; \
		fi; \
		if [ $$rc -eq 0 ]; then \
			passed=$$((passed+1)); echo "    PASS ✓  ($(MODULE_CASE)/$$v quant=$$q)"; \
		else \
			failed=$$((failed+1)); echo "    FAIL ✗  ($(MODULE_CASE)/$$v quant=$$q)"; \
			[ "$(STOP_ON_FAIL)" = "1" ] && break 2; fi; \
	done; done; \
	echo ""; echo "sim-batch 完成: PASS=$$passed FAIL=$$failed TOTAL=$$total"; \
	[ $$failed -eq 0 ]

_data_batch_run:
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	for v in $$variants; do \
		$(MAKE) data MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$$v \
			MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) || exit 1; done

# ── 仿真监控（另开终端用）────────────────────────────────────────────────────

sim-ps:
	@pid=$$(pgrep -f '$(SIMV)' 2>/dev/null | head -1); \
	if [ -n "$$pid" ]; then \
		set -- $$(ps -p $$pid -o etime= -o pcpu= -o rss= 2>/dev/null); \
		echo "simv 在运行  运行=$$1  CPU=$$2%  RSS=$$3KB"; \
	else echo "simv 未运行"; fi; \
	[ -f "$(SIM_LOG)" ] && { \
		echo "sim.log: $$(ls -sh $(SIM_LOG) | awk '{print $$1}')  末行: $$(tail -1 $(SIM_LOG))"; \
		grep -q 'MODULE CHECK PASSED'  "$(SIM_LOG)" && echo "→ PASS" || true; \
		grep -q 'MODULE CHECK FAILED'  "$(SIM_LOG)" && echo "→ FAIL" || true; } \
	|| echo "sim.log 不存在"

# sim-results：扫描 sim/ 下所有 sim.log，汇总 PASS/FAIL（batch/sim-all 结束后使用）
sim-results:
	@echo "===== Simulation Results ====="
	@passed=0; failed=0; total=0; \
	for f in $(SIM_DIR)/run_*/sim.log; do \
		[ -f "$$f" ] || continue; \
		total=$$((total+1)); \
		dir=$$(dirname "$$f"); name=$$(basename "$$dir"); \
		if grep -q 'MODULE CHECK PASSED' "$$f" 2>/dev/null; then \
			passed=$$((passed+1)); echo "  PASS  $$name"; \
		else \
			failed=$$((failed+1)); echo "  FAIL  $$name"; \
		fi; \
	done; \
	echo ""; \
	echo "  TOTAL=$$total  PASS=$$passed  FAIL=$$failed"; \
	[ $$total -gt 0 ] || { echo "  (no sim.log found under $(SIM_DIR)/run_*/)" && exit 0; }; \
	[ $$failed -eq 0 ] && echo "  ✓ ALL PASS" || echo "  ✗ SOME FAILED"

sim-watch:
	@[ -f "$(SIM_LOG)" ] || { echo "先 make sim"; exit 1; }; \
	prev=0; while true; do $(MAKE) -s sim-ps; \
	s=$$(stat -c%s "$(SIM_LOG)" 2>/dev/null||echo 0); \
	echo "  sim.log +$$((s-prev))B / $(WATCH_INTERVAL)s"; prev=$$s; sleep $(WATCH_INTERVAL); done

sim-done:
	@grep -q 'MODULE CHECK PASSED' "$(SIM_LOG)" 2>/dev/null && echo PASS  && exit 0 || true; \
	grep -q 'MODULE CHECK FAILED\|FATAL' "$(SIM_LOG)" 2>/dev/null && echo FAIL  && exit 1 || true; \
	pgrep -f '$(SIMV)' >/dev/null && echo RUNNING && exit 2; \
	echo UNKNOWN; exit 3

# ── 其它 ────────────────────────────────────────────────────────────────────

clean:
	rm -rf $(RUN_DIR)

clean-suite:
	rm -rf $(SUITE_DIR)

clean-compile:
	rm -rf $(COMPILE_DIR)

help:
	@echo "工作目录: rtl/tb/lite_bd/module_tb"
	@echo ""
	@echo "完整功能验证（一键）："
	@echo "  make sim-all                     覆盖所有模块 INT8+INT16，STOP_ON_FAIL=1"
	@echo "  make sim-all STOP_ON_FAIL=0      同上但跑完全部后再报告"
	@echo ""
	@echo "前提（BD/IP 变更后执行，约 5~10 分钟）："
	@echo "  make export"
	@echo ""
	@echo "日常 RTL 修改后（无需 export）："
	@echo "  make compile                     重编共享 simv"
	@echo "  make rebuild-suite MODULE_CASE=X BATCH_SUITE=Y  重编 + 连跑"
	@echo ""
	@echo "单用例调试："
	@echo "  make sim  MODULE_CASE=<模块> MODULE_VARIANT=<用例>"
	@echo "  make fsdb MODULE_CASE=<模块> MODULE_VARIANT=<用例>  # 带波形"
	@echo "  make verdi"
	@echo ""
	@echo "分类批量（详见 make list-suites）："
	@echo "  make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all QUANT=all"
	@echo "  make sim-batch MODULE_CASE=qa          BATCH_SUITE=qa_all   QUANT=all"
	@echo "  make sim-batch MODULE_CASE=dqa         BATCH_SUITE=dqa_all  QUANT=all"
	@echo "  make sim-batch MODULE_CASE=im2col      BATCH_SUITE=im2col_all"
	@echo "  make sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all"
	@echo ""
	@echo "查看全量结果（sim-all 结束后）："
	@echo "  make sim-results"
	@echo ""
	@echo "监控（另开终端）："
	@echo "  make sim-watch  make sim-done"
	@echo ""
	@echo "清理："
	@echo "  make clean           当前变体产物"
	@echo "  make clean-compile   删除共享 simv（下次从头重编）"
	@echo "  rm -rf sim/          清除所有产物（谨慎）"
	@echo "       BATCH_SUITE=$(BATCH_SUITE)  FAST=$(FAST)  VCS_JOBS=$(VCS_JOBS)  SIMV_JOBS=$(SIMV_JOBS)  STOP_ON_FAIL=$(STOP_ON_FAIL)"
