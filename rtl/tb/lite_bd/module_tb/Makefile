# ==============================================================================
# module_tb — lite BD 模块级 VCS 仿真
# 工作目录：rtl/tb/lite_bd/module_tb/  （所有 make 命令请在此目录执行）
# ==============================================================================
#
# 【验证分类】
#   unit     — 单个硬件 unit：DCIM / QA / DQA / im2col / MP / US / ADD / concat
#   pipeline — 算子级多步链路：conv_pipeline（单层 conv）、mini_network（多层+残差）
#
# 【一键回归】
#   make sim-smoke       RTL 改完后推荐：小规模 unit+pipeline 冒烟（约十余个用例，远快于 sim-all）
#   make sim-unit-smoke  仅 unit 冒烟子集
#   make sim-pipeline-smoke  仅 pipeline 冒烟子集
#   make sim-unit-tb     PR 合并前门控：全量 unit INT8+INT16 + conv_pipeline（约 1~2 h）
#   make sim-unit        跑完全部 unit（含 DCIM extreme 压力，约 3 h）
#   make sim-pipeline    跑完全部 pipeline
#   make sim-all         sim-unit + sim-pipeline
#   make sim-results     扫描 sim/run_*/sim.log 汇总 PASS/FAIL
#
# 【何时 export / compile】
#   make export   — BD/IP/地址映射/chip_defines 中 DCIM 参数变更后（约 5~10 min）
#   make compile  — 仅改 RTL / golden / TB 后，重编共享 simv（export 不必重跑）
#   make sim      — 单用例：生成 golden + 编译（如需）+ 仿真 + 比对
#
# 【单用例 / 子集】
#   make sim MODULE_CASE=dqa MODULE_VARIANT=dqa_c32_mid
#   make sim-batch MODULE_CASE=qa BATCH_SUITE=qa_all QUANT=all
#   make list-suites / make list-cases MODULE_CASE=qa
#
# 【Vivado 综合实现】（与仿真无关，在仓库根目录执行）
#   cd <REPO_ROOT>
#   vivado -mode batch -source scripts/chip-lite/run.tcl
#   RESUME_FROM=place vivado -mode batch -source scripts/chip-lite/run.tcl
#
# 【常用变量】
#   STOP_ON_FAIL=1|0     批量遇 FAIL 是否立即停止（默认 1）
#   QUANT=int8|int16|all QA/DQA/pipeline 批量时量化展开（dcim 由 case 名决定）
#   PRELOAD_MODE=backdoor|axi  默认 backdoor 直写 OBUF/IBUF（快）
#   MODULE_VERIFY_WORDS=N  只比对前 N 个 128-bit word（0=全量）
#   FAST=1|0             1=跳过 -debug_access（快）；fsdb 会自动用 0
#   LOG=1                sim-batch 时把日志 tee 到 run 目录
# ==============================================================================

# ── 单用例默认参数 ────────────────────────────────────────────────────────────
MODULE_CASE ?= dcim_matmul          # 模块名，见 golden_module_tb.py MODULE_CASES
MODULE_VARIANT ?= dcim_tiny_1x1     # 用例名，make list-cases 可列出
MODULE_VERIFY_WORDS ?= 0            # 0 = 校验全部 expected word
STOP_ON_FAIL ?= 1                   # sim-batch / sim-unit / sim-pipeline 遇 FAIL 即停
BATCH_SUITE ?=
MODULE_VARIANTS ?=
LOG ?= 0
FAST ?= 1
VCS_JOBS ?= 64
SIMV_JOBS ?= 32
WATCH_INTERVAL ?= 5
PRELOAD_MODE ?= backdoor            # backdoor：直写存储；axi：走 Host BFM（慢，查地址用）
QUANT ?= int8                       # sim-batch 时：int8 | int16 | all（dcim_matmul 忽略）
DIM ?=

# ── 路径 ──────────────────────────────────────────────────────────────────────
MODULE_TB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT     := $(abspath $(MODULE_TB_DIR)/../../../..)
EXPORT_VCS_DIR := $(REPO_ROOT)/sim/lite_bd_export/vcs/lite/vcs
# DCIM module_ref 仿真 wrapper：优先 bd/lite/ip（静态源），否则找最新 build tag 下的产物
DCIM_MODREF_SIM     := $(REPO_ROOT)/bd/lite/ip/lite_dcim_array_0_0/sim/lite_dcim_array_0_0.v
# 若 bd/lite 下无，自动找 build/lite/<latest_tag>/lite.ip_user_files/bd/lite/ip/.../sim/...
#   shell 展开：取 build/lite/ 下最新含 lite.xpr 的目录，组合成 ALT 路径
_LATEST_BUILD := $(shell ls -dt $(REPO_ROOT)/build/lite/*/lite.xpr 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
DCIM_MODREF_SIM_ALT := $(if $(_LATEST_BUILD),$(_LATEST_BUILD)/lite.ip_user_files/bd/lite/ip/lite_dcim_array_0_0/sim/lite_dcim_array_0_0.v,)
SIM_DIR       := $(MODULE_TB_DIR)/sim
RUN_SCRIPT    := $(SIM_DIR)/run_module_sim.sh
GOLDEN_PY     := $(MODULE_TB_DIR)/golden_module_tb.py

# 运行目录 slug：run_<MODULE_CASE>_<VARIANT>_<quant|dcim_int8|dcim_int16>
_QUANT_SLUG := $(if $(filter dcim_matmul,$(MODULE_CASE)),$(if $(findstring int16,$(MODULE_VARIANT)),dcim_int16,dcim_int8),$(if $(filter all,$(QUANT)),allq,q$(QUANT)))
comma       := ,
_DIM_SLUG   := $(if $(DIM),_$(subst $(comma),_,$(subst =,,$(DIM))),)
_VARIANT_SLUG := $(subst /,_,$(MODULE_CASE))_$(subst /,_,$(MODULE_VARIANT))_$(_QUANT_SLUG)$(_DIM_SLUG)
COMPILE_DIR   := $(SIM_DIR)/build_shared    # 共享 simv，所有 case 复用
RUN_DIR       := $(SIM_DIR)/run_$(_VARIANT_SLUG)
BUILD_DIR     := $(RUN_DIR)
SIM_LOG       := $(RUN_DIR)/sim.log
FSDB_FILE     := $(RUN_DIR)/tb_lite_bd_module.fsdb
SIMV          := $(COMPILE_DIR)/simv

# ==============================================================================
# BATCH_SUITE 预置列表（sim-batch 的 BATCH_SUITE=<名称> 展开为 MODULE_VARIANT 列表）
# ==============================================================================

# --- unit：DCIM 矩阵乘（INT8+INT16 常规 + extreme 高 acc_depth）---
BATCH_SUITE_dcim_all        := dcim_tiny_1x1 conv6_s2_c3_to16 conv3_s2_c32_to64 conv1_c64_to32 conv3_c128_to128 int16_tiny_1x1 int16_conv3_c32_c64 int16_conv1_c128
BATCH_SUITE_dcim_extreme    := extreme_int8_1x1_c512_to512 extreme_int8_3x3_c128_to512 extreme_int8_6x6_c3_to64 extreme_int16_3x3_c128

# --- unit：VPU 量化 / 反量化（批量建议 QUANT=all）---
BATCH_SUITE_qa_all          := qa_c16_signed qa_c64_clip qa_c128_dense qa_int16_c32_signed
BATCH_SUITE_dqa_all         := dqa_c16_small dqa_c32_mid dqa_c64_mid dqa_c128_sppf dqa_c256_head dqa_nrelu_c24_in64 dqa_nrelu_c24_in128 dqa_nrelu_c24_in256 dqa_acc64_c32 dqa_acc64_c64

# --- unit：im2col / MP / US / ADD / concat（QUANT 不影响，保持 int8 即可）---
BATCH_SUITE_im2col_all      := im2col_6x6_s2_c3 im2col_3x3_s2_c32 im2col_3x3_s1_c128 im2col_1x1_c512
BATCH_SUITE_mp_all          := mp_sppf_128_10 mp_resnet_stem mp_gap_7x7_c512
BATCH_SUITE_us_all          := us_128_10_to20 us_64_20_to40
BATCH_SUITE_add_all         := add_residual_16 add_residual_32 add_pan_64
BATCH_SUITE_concat_all      := concat_2src_c64_c64_hw8x8 concat_2src_c128_c128_hw10x10 concat_4src_sppf_c128_hw10x10
BATCH_SUITE_cdma_memtest_all   := cdma_obuf_ibuf_obuf_c128 cdma_obuf_ibuf_obuf_1k cdma_ibuf_read_4k cdma_obuf_ibuf_obuf_large
BATCH_SUITE_cdma_memtest_smoke := cdma_obuf_ibuf_obuf_c128 cdma_ibuf_read_4k

# --- pipeline：单层 conv 算子 / 多层 mini 网络（批量建议 QUANT=all）---
BATCH_SUITE_conv_pipe_all   := pipe_conv3_s2_c32_to64 pipe_conv1_c512_to64_tilepass
BATCH_SUITE_mini_network_all := mini_2conv_c16 mini_3conv_residual_c32

# --- smoke：改 RTL 后快速验证（约 18 用例，全量逐 word 比对 expected.hex，非抽样）---
#   dcim: INT8(1x1+3x3 stride-2) + INT16(1x1)  ← 3x3/stride-2 是最高频改动路径
#   qa/dqa: int8+int16 各 1 个
#   im2col: 6x6 stride-2 + 3x3 stride-1（覆盖典型 padding/步长组合）
#   pipeline: 1x1 + stride-2 conv3（全链路 im2col→CDMA→DCIM→DQA→QA）
#   mini: 2层 + 3层 residual（多层 OBUF + ADD 路径）
#   concat: 仅 8x8 c64（避免百次级 CDMA 仿真时间）
#   cdma_memtest: OBUF→IBUF→OBUF roundtrip（验 ibuf/obuf controller 延迟配置，无 VPU/DCIM 参与）
BATCH_SUITE_dcim_smoke      := dcim_tiny_1x1 conv3_s2_c32_to64 int16_tiny_1x1
BATCH_SUITE_qa_smoke        := qa_c16_signed
BATCH_SUITE_dqa_smoke       := dqa_c32_mid dqa_acc64_c32
BATCH_SUITE_im2col_smoke    := im2col_6x6_s2_c3 im2col_3x3_s1_c128
BATCH_SUITE_mp_smoke        := mp_resnet_stem
BATCH_SUITE_us_smoke        := us_128_10_to20
BATCH_SUITE_add_smoke       := add_residual_16
BATCH_SUITE_concat_smoke    := concat_2src_c64_c64_hw8x8
BATCH_SUITE_conv_pipe_smoke := pipe_conv1_c16_to16 pipe_conv3_s2_c32_to64
BATCH_SUITE_mini_network_smoke := mini_2conv_c16 mini_3conv_residual_c32

# PR 门控（sim-unit-tb）：全量 unit INT8+INT16 + conv_pipeline，跳过 dcim_extreme / mini_network
# 目标：≤2 h，覆盖所有正式路径的数值准确性；extreme / mini 延至 sim-unit / sim-all
BATCH_SUITE_dcim_tb      := $(BATCH_SUITE_dcim_all)       # INT8+INT16，共 8 case
BATCH_SUITE_qa_tb        := $(BATCH_SUITE_qa_all)         # qa_c16_signed / qa_c64_clip / qa_c128_dense + INT16
BATCH_SUITE_dqa_tb       := $(BATCH_SUITE_dqa_all)        # relu/nrelu 全系 + native INT64 accumulator
BATCH_SUITE_im2col_tb    := $(BATCH_SUITE_im2col_all)     # 1×1/3×3/6×6 全覆盖
BATCH_SUITE_mp_tb        := $(BATCH_SUITE_mp_all)         # SPPF / ResNet stem / GAP
BATCH_SUITE_us_tb        := $(BATCH_SUITE_us_all)         # 2 case
BATCH_SUITE_add_tb       := $(BATCH_SUITE_add_all)        # residual 3 case
BATCH_SUITE_concat_tb    := $(BATCH_SUITE_concat_all)     # 2src / 4src
BATCH_SUITE_cdma_tb      := $(BATCH_SUITE_cdma_memtest_all)  # roundtrip + large
BATCH_SUITE_conv_pipe_tb := $(BATCH_SUITE_conv_pipe_all)  # 含 tilepass（INT8+INT16）

.PHONY: export compile sim sim-export run fsdb verdi data clean clean-compile help
.PHONY: check-export sim-batch _sim_batch_run data-batch _data_batch_run
.PHONY: sim-unit sim-unit-tb sim-pipeline sim-all sim-results sim-ps sim-watch sim-done
.PHONY: sim-unit-smoke sim-pipeline-smoke sim-smoke
.PHONY: list-cases list-suites

# ==============================================================================
# Vivado export / VCS 编译
# ==============================================================================

# export：仅 export_simulation → sim/lite_bd_export/（与 make export 在 lite_bd/ 等价）
# BUILD_TAG 可选：指定要 export 哪个 build（同 run.tcl 的 BUILD_TAG）
#   不指定时 export_sim.tcl 自动选取最新已有 build。
export:
	@echo "[export] Vivado export_simulation（不跑 VCS）$(if $(BUILD_TAG), BUILD_TAG=$(BUILD_TAG))"
	cd $(REPO_ROOT) && $(if $(BUILD_TAG),BUILD_TAG=$(BUILD_TAG),) vivado -mode batch \
		-source $(REPO_ROOT)/scripts/chip-lite/export_sim.tcl

# compile：只编 simv，不跑用例；export 比 simv 新时会自动 clean-compile
compile: check-export
	@stamp="$(REPO_ROOT)/sim/lite_bd_export/.export_stamp"; \
	if [ -f "$$stamp" ] && [ -f "$(SIMV)" ] && [ "$$stamp" -nt "$(SIMV)" ]; then \
	  echo "[compile] export 晚于 simv → 自动 clean-compile"; \
	  $(MAKE) clean-compile; \
	fi
	ACTION=compile COMPILE_DIR=$(COMPILE_DIR) FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

# 检查 export 产物与 DCIM module_ref wrapper 是否存在
check-export:
	@test -f "$(EXPORT_VCS_DIR)/lite.sh" || { \
		echo "ERROR: 缺少 export（无 $(EXPORT_VCS_DIR)/lite.sh）"; \
		echo "  → cd $(REPO_ROOT) && vivado -mode batch -source scripts/chip-lite/export_sim.tcl"; \
		exit 1; }
	@test -f "$(DCIM_MODREF_SIM)" || test -f "$(DCIM_MODREF_SIM_ALT)" || { \
		echo "ERROR: 缺少 lite_dcim_array_0_0 仿真 wrapper"; \
		echo "  → 期望: $(DCIM_MODREF_SIM)"; \
		echo "  → 或:   $(DCIM_MODREF_SIM_ALT)"; \
		echo "  → make export（与改 chip_defines/BD 后必须做）"; \
		exit 1; }

# ==============================================================================
# 回归：unit / pipeline / all
# ==============================================================================

# sim-unit-tb：PR 合并前门控（全量 unit INT8+INT16 + conv_pipeline，跳过 dcim_extreme/mini_network）
# 覆盖：DCIM INT8/INT16 全 8 case、QA/DQA QUANT=all、im2col 全 4 case、
#        MP(SPPF/stem/GAP)/US/ADD/concat 全量、cdma_memtest 全量、
#        conv_pipeline INT8+INT16（im2col→CDMA→DCIM→DQA→QA 完整链路）
# 排除：dcim_extreme（压力测试，归 sim-unit）、mini_network（多层链路，归 sim-pipeline）
# 时长预估：约 1~2 h（backdoor 模式，单机 VCS）
sim-unit-tb: check-export
	@echo "========== [unit-tb] DCIM INT8+INT16（全 8 case）=========="
	$(MAKE) sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_tb STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit-tb] QA  fp32→int8/int16 =========="
	$(MAKE) sim-batch MODULE_CASE=qa BATCH_SUITE=qa_tb QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit-tb] DQA accum→fp32（relu/nrelu/native INT64，INT8+INT16）=========="
	$(MAKE) sim-batch MODULE_CASE=dqa BATCH_SUITE=dqa_tb QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit-tb] im2col（1×1/3×3/6×6，全 4 case）=========="
	$(MAKE) sim-batch MODULE_CASE=im2col BATCH_SUITE=im2col_tb QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit-tb] MP / US / ADD 全量 =========="
	$(MAKE) sim-batch MODULE_CASE=mp  BATCH_SUITE=mp_tb  QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	$(MAKE) sim-batch MODULE_CASE=us  BATCH_SUITE=us_tb  QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	$(MAKE) sim-batch MODULE_CASE=add BATCH_SUITE=add_tb QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit-tb] concat_by_cdma（2src/4src 全量）=========="
	$(MAKE) sim-batch MODULE_CASE=concat_by_cdma BATCH_SUITE=concat_tb QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit-tb] cdma_memtest（OBUF↔IBUF 全量，含 large）=========="
	$(MAKE) sim-batch MODULE_CASE=cdma_memtest BATCH_SUITE=cdma_tb QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit-tb] conv_pipeline（im2col→CDMA→DCIM→DQA→QA，INT8+INT16）=========="
	$(MAKE) sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_tb QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== sim-unit-tb DONE — make sim-results 查看汇总 ==="
	@echo "=== 如需 extreme 压力 → make sim-unit；如需多层链路 → make sim-pipeline ==="

# sim-unit：各硬件 unit 独立数值验证（含 dcim_extreme 压力）
sim-unit: check-export
	@echo "========== [unit] DCIM INT8+INT16 =========="
	$(MAKE) sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit] QA  fp32→int8/int16 =========="
	$(MAKE) sim-batch MODULE_CASE=qa BATCH_SUITE=qa_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit] DQA accum→fp32 =========="
	$(MAKE) sim-batch MODULE_CASE=dqa BATCH_SUITE=dqa_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit] im2col =========="
	$(MAKE) sim-batch MODULE_CASE=im2col BATCH_SUITE=im2col_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit] MP / US / ADD =========="
	$(MAKE) sim-batch MODULE_CASE=mp  BATCH_SUITE=mp_all  QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	$(MAKE) sim-batch MODULE_CASE=us  BATCH_SUITE=us_all  QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	$(MAKE) sim-batch MODULE_CASE=add BATCH_SUITE=add_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit] DCIM extreme（高 acc_depth / 大通道）=========="
	$(MAKE) sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_extreme STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit] cdma_memtest（OBUF↔IBUF controller 延迟）=========="
	$(MAKE) sim-batch MODULE_CASE=cdma_memtest BATCH_SUITE=cdma_memtest_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [unit] concat_by_cdma（逐像素 CDMA 拼接，最慢放最后）=========="
	$(MAKE) sim-batch MODULE_CASE=concat_by_cdma BATCH_SUITE=concat_all QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== sim-unit DONE — make sim-results 查看汇总 ==="

# sim-pipeline：算子级链路（im2col→CDMA→DCIM→DQA→QA 等组合）
sim-pipeline: check-export
	@echo "========== [pipeline] conv_pipeline =========="
	$(MAKE) sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [pipeline] mini_network =========="
	$(MAKE) sim-batch MODULE_CASE=mini_network BATCH_SUITE=mini_network_all QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== sim-pipeline DONE — make sim-results 查看汇总 ==="

# sim-all：完整 RTL 数值回归（unit + pipeline）
sim-all: sim-unit sim-pipeline
	@echo "=== sim-all DONE — make sim-results 查看汇总 ==="

# ==============================================================================
# 冒烟：改 RTL / OBUF 流水后快速验证（规模小，覆盖 unit + pipeline 基本组合）
# ==============================================================================

sim-unit-smoke: check-export
	@echo "========== [smoke/unit] DCIM INT8+INT16 tiny =========="
	$(MAKE) sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_smoke STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [smoke/unit] QA  int8+int16 =========="
	$(MAKE) sim-batch MODULE_CASE=qa BATCH_SUITE=qa_smoke QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [smoke/unit] DQA int8+int16 =========="
	$(MAKE) sim-batch MODULE_CASE=dqa BATCH_SUITE=dqa_smoke QUANT=all STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [smoke/unit] im2col =========="
	$(MAKE) sim-batch MODULE_CASE=im2col BATCH_SUITE=im2col_smoke QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [smoke/unit] MP / US / ADD =========="
	$(MAKE) sim-batch MODULE_CASE=mp  BATCH_SUITE=mp_smoke  QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	$(MAKE) sim-batch MODULE_CASE=us  BATCH_SUITE=us_smoke  QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	$(MAKE) sim-batch MODULE_CASE=add BATCH_SUITE=add_smoke QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [smoke/unit] concat（仅 8x8 c64，避免大 CDMA）=========="
	$(MAKE) sim-batch MODULE_CASE=concat_by_cdma BATCH_SUITE=concat_smoke QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [smoke/unit] cdma_memtest（OBUF→IBUF→OBUF roundtrip）=========="
	$(MAKE) sim-batch MODULE_CASE=cdma_memtest BATCH_SUITE=cdma_memtest_smoke QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== sim-unit-smoke DONE（约 13 个 variant 运行）==="

sim-pipeline-smoke: check-export
	@echo "========== [smoke/pipeline] conv 1x1 小图（im2col+CDMA+DCIM+DQA+QA）=========="
	$(MAKE) sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_smoke QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "========== [smoke/pipeline] mini 2-layer =========="
	$(MAKE) sim-batch MODULE_CASE=mini_network BATCH_SUITE=mini_network_smoke QUANT=int8 STOP_ON_FAIL=$(STOP_ON_FAIL)
	@echo "=== sim-pipeline-smoke DONE（2 个用例）==="

# sim-smoke：RTL 修改后默认入口（unit 冒烟 + pipeline 冒烟，约 14 次 sim，全量 golden）
sim-smoke: sim-unit-smoke sim-pipeline-smoke
	@echo "=== sim-smoke DONE — make sim-results 查看汇总 ==="

# ==============================================================================
# 单用例 / 批量
# ==============================================================================

# sim：生成 golden +（如需）编译 + 运行 + 逐 word 比对（最常用调试入口）
sim: check-export
	ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) MODULE_QUANT=$(QUANT) MODULE_DIM="$(DIM)" \
	FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

# sim-export：BD 变更后先 export 再 sim
sim-export: export sim

# run：假定 golden 已生成，只跑仿真（改 TB 调试时用）
run: check-export
	ACTION=run COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) MODULE_QUANT=$(QUANT) MODULE_DIM="$(DIM)" \
	FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

# fsdb：重编（FAST=0）并 dump 波形 → $(FSDB_FILE)
fsdb: check-export
	ACTION=rebuild-sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) FAST=0 VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=1 PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT)

verdi:
	@if [ -f "$(FSDB_FILE)" ]; then verdi -ssf "$(FSDB_FILE)" -nologo & \
	elif [ -d "$(SIMV).daidir" ]; then verdi -simflow -simBin "$(SIMV)" -nologo & \
	else echo "先 make fsdb"; exit 1; fi

# data：只生成 hex/golden/checks，不仿真
data:
	ACTION=gen RUN_DIR=$(RUN_DIR) MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) MODULE_QUANT=$(QUANT) MODULE_DIM="$(DIM)" bash $(RUN_SCRIPT)

# sim-batch：按 BATCH_SUITE 或 MODULE_VARIANTS 顺序跑多个 variant（复用 build_shared/simv）
sim-batch: check-export _sim_batch_run

_sim_batch_run:
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	if [ -z "$$variants" ]; then \
		echo "用法: make sim-batch MODULE_CASE=<模块> BATCH_SUITE=<suite>"; \
		echo "      make list-suites"; exit 1; fi; \
	if [ "$(MODULE_CASE)" = "dcim_matmul" ]; then quant_list="case"; else quant_list="$(QUANT)"; [ "$$quant_list" = "all" ] && quant_list="int8 int16"; fi; \
	log="$(BUILD_DIR)/sim_batch.log"; mkdir -p "$(BUILD_DIR)"; \
	passed=0; failed=0; skipped=0; total=0; \
	for q in $$quant_list; do \
	for v in $$variants; do \
		total=$$((total+1)); \
		if [ "$(MODULE_CASE)" = "dcim_matmul" ]; then \
			case "$$v" in *int16*) mode_slug=dcim_int16; module_quant=int16 ;; \
				*) mode_slug=dcim_int8; module_quant=int8 ;; esac; \
			echo ""; echo ">>> [$$total] $(MODULE_CASE)/$$v  mode=$$mode_slug  $(shell date '+%H:%M:%S')"; \
			bd="$(SIM_DIR)/run_$(MODULE_CASE)_$${v}_$${mode_slug}"; \
		else \
			mode_slug=q$$q; \
			echo ""; echo ">>> [$$total] $(MODULE_CASE)/$$v  quant=$$q  $(shell date '+%H:%M:%S')"; \
			bd="$(SIM_DIR)/run_$(MODULE_CASE)_$${v}_$${mode_slug}"; module_quant=$$q; \
		fi; \
		if [ "$(LOG)" = "1" ]; then \
			: > "$$log"; \
			( ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR="$$bd" \
				MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$$v MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
				MODULE_QUANT=$$module_quant MODULE_DIM="$(DIM)" \
				FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT) 2>&1 | tee -a "$$log" ); rc=$${PIPESTATUS[0]}; \
		else \
			( ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR="$$bd" \
				MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$$v MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
				MODULE_QUANT=$$module_quant MODULE_DIM="$(DIM)" \
				FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) PRELOAD_MODE=$(PRELOAD_MODE) bash $(RUN_SCRIPT) 2>&1 ); rc=$$?; \
		fi; \
		if [ -f "$$bd/skipped.txt" ]; then \
			skipped=$$((skipped+1)); echo "    SKIP ⊘  ($(MODULE_CASE)/$$v $$mode_slug)"; \
		elif [ $$rc -eq 0 ]; then \
			passed=$$((passed+1)); echo "    PASS ✓  ($(MODULE_CASE)/$$v $$mode_slug)"; \
		else \
			failed=$$((failed+1)); echo "    FAIL ✗  ($(MODULE_CASE)/$$v $$mode_slug)"; \
			[ "$(STOP_ON_FAIL)" = "1" ] && break 2; fi; \
	done; done; \
	echo ""; echo "sim-batch: PASS=$$passed SKIP=$$skipped FAIL=$$failed TOTAL=$$total"; \
	[ $$failed -eq 0 ]

# data-batch：批量只生成 golden，不仿真
data-batch: _data_batch_run

_data_batch_run:
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	for v in $$variants; do \
		$(MAKE) data MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$$v \
			MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) || exit 1; done

# ==============================================================================
# 列举 / 监控 / 清理
# ==============================================================================

list-cases:
	python3 $(GOLDEN_PY) --module $(MODULE_CASE) --case list

list-suites:
	@echo "冒烟（改 RTL 后）：make sim-smoke | sim-unit-smoke | sim-pipeline-smoke"
	@echo "PR 门控：        make sim-unit-tb  （全量 unit + conv_pipeline，约 1~2 h）"
	@echo "全量：           make sim-unit | sim-pipeline | sim-all"
	@echo ""
	@echo "[smoke] dcim_smoke qa_smoke dqa_smoke im2col_smoke mp_smoke us_smoke add_smoke concat_smoke"
	@echo "        conv_pipe_smoke mini_network_smoke"
	@echo ""
	@echo "[tb]    sim-unit-tb 已含 dcim_all + qa_all(QUANT=all) + dqa_all(QUANT=all) +"
	@echo "                    im2col_all + mp_all + us_all + add_all + concat_all +"
	@echo "                    cdma_memtest_all + conv_pipe_all(QUANT=all)"
	@echo ""
	@echo "[unit]  MODULE_CASE=dcim_matmul  BATCH_SUITE=dcim_all | dcim_extreme"
	@echo "        MODULE_CASE=qa           BATCH_SUITE=qa_all    [QUANT=all]"
	@echo "        MODULE_CASE=dqa          BATCH_SUITE=dqa_all   [QUANT=all]"
	@echo "        MODULE_CASE=im2col       BATCH_SUITE=im2col_all"
	@echo "        MODULE_CASE=mp|us|add    BATCH_SUITE=mp_all|us_all|add_all"
	@echo "        MODULE_CASE=concat_by_cdma BATCH_SUITE=concat_all"
	@echo ""
	@echo "[pipeline] MODULE_CASE=conv_pipeline  BATCH_SUITE=conv_pipe_all  [QUANT=all]"
	@echo "           MODULE_CASE=mini_network    BATCH_SUITE=mini_network_all [QUANT=all]"

# sim-results：扫描本次 batch/all 产生的 sim/run_*/sim.log
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
	echo ""; echo "  TOTAL=$$total  PASS=$$passed  FAIL=$$failed"; \
	[ $$total -gt 0 ] || { echo "  (no sim.log)"; exit 0; }; \
	[ $$failed -eq 0 ] && echo "  ✓ ALL PASS" || echo "  ✗ SOME FAILED"

# sim-ps / sim-watch / sim-done：另开终端监控当前 MODULE_CASE/VARIANT 的 sim.log
sim-ps:
	@pid=$$(pgrep -f '$(SIMV)' 2>/dev/null | head -1); \
	if [ -n "$$pid" ]; then \
		set -- $$(ps -p $$pid -o etime= -o pcpu= -o rss= 2>/dev/null); \
		echo "simv  运行=$$1  CPU=$$2%  RSS=$$3KB"; \
	else echo "simv 未运行"; fi; \
	[ -f "$(SIM_LOG)" ] && tail -1 "$(SIM_LOG)" || echo "sim.log 不存在"

sim-watch:
	@[ -f "$(SIM_LOG)" ] || { echo "先 make sim"; exit 1; }; \
	prev=0; while true; do $(MAKE) -s sim-ps; \
	s=$$(stat -c%s "$(SIM_LOG)" 2>/dev/null||echo 0); \
	echo "  +$$((s-prev))B / $(WATCH_INTERVAL)s"; prev=$$s; sleep $(WATCH_INTERVAL); done

sim-done:
	@grep -q 'MODULE CHECK PASSED' "$(SIM_LOG)" 2>/dev/null && echo PASS  && exit 0 || true; \
	grep -q 'MODULE CHECK FAILED\|FATAL' "$(SIM_LOG)" 2>/dev/null && echo FAIL  && exit 1 || true; \
	pgrep -f '$(SIMV)' >/dev/null && echo RUNNING && exit 2; \
	echo UNKNOWN; exit 3

# clean：删除当前 MODULE_CASE/VARIANT 的 run 目录
clean:
	rm -rf $(RUN_DIR)

# clean-compile：删除共享 simv，下次 sim 会全量重编
clean-compile:
	rm -rf $(COMPILE_DIR)

help:
	@echo "工作目录: rtl/tb/lite_bd/module_tb"
	@echo ""
	@echo "冒烟（改 RTL 后）：make sim-smoke | sim-unit-smoke | sim-pipeline-smoke"
	@echo "PR 门控（合并前）：make sim-unit-tb  ← 全量 unit + conv_pipeline，约 1~2 h"
	@echo "全量：             make sim-unit | sim-pipeline | sim-all | sim-results"
	@echo ""
	@echo "前提：make export（BD 变更）  make compile（RTL 变更）"
	@echo "单用例：make sim MODULE_CASE=... MODULE_VARIANT=..."
	@echo "子集：  make sim-batch MODULE_CASE=qa BATCH_SUITE=qa_all QUANT=all"
	@echo "调试：make fsdb  make verdi  make sim-watch"
	@echo ""
	@echo "Vivado 综合实现（仓库根目录）："
	@echo "  vivado -mode batch -source scripts/chip-lite/run.tcl"
