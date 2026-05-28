# module_tb — 在 rtl/tb/lite_bd/module_tb 下执行：make help
#
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  命令速查表（全部在 rtl/tb/lite_bd/module_tb/ 下执行）                         ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║  一、核心仿真                                                                 ║
# ║    make export                          # Vivado export（BD/IP 变更后执行）    ║
# ║    make sim                             # 跑默认用例 dcim_tiny_1x1（最快）      ║
# ║    make sim-export                      # export + 跑默认用例（一步到位）       ║
# ║    make compile                         # 只重编共享 simv，日常 RTL 修改后用     ║
# ║    make clean-compile                   # 删除共享 simv，下次会重新编译          ║
# ║    make rebuild-suite ...               # 重新生成数据 + 重编 simv + suite 连跑  ║
# ║                                         # 注意：rebuild 不做 Vivado export       ║
# ║    make fsdb                            # 带波形编译，生成 .fsdb（比 sim 慢）    ║
# ║    make fsdb-export                     # export + 带波形仿真                  ║
# ║    make verdi                           # 打开 Verdi 查波形（先 make fsdb）     ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║  二、指定模块 / 变体                                                           ║
# ║    make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1             ║
# ║    make sim MODULE_CASE=qa          MODULE_VARIANT=qa_c16_signed             ║
# ║    make sim MODULE_CASE=qa          MODULE_VARIANT=qa_c64_clip               ║
# ║    make sim MODULE_CASE=qa          MODULE_VARIANT=qa_c128_dense             ║
# ║    make sim MODULE_CASE=dqa         MODULE_VARIANT=dqa_c16_small             ║
# ║    make sim MODULE_CASE=dqa         MODULE_VARIANT=dqa_c64_mid               ║
# ║    make sim MODULE_CASE=dqa         MODULE_VARIANT=dqa_c128_sppf             ║
# ║    make sim MODULE_CASE=im2col      MODULE_VARIANT=im2col_6x6_s2_c3          ║
# ║    make sim MODULE_CASE=im2col      MODULE_VARIANT=im2col_3x3_s2_c32         ║
# ║    make sim MODULE_CASE=mp          MODULE_VARIANT=mp_sppf_128_10            ║
# ║    make sim MODULE_CASE=conv_pipeline MODULE_VARIANT=pipe_conv3_s2_c32_to64  ║
# ║    make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=conv6_s2_c3_to16          ║
# ║    make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=conv3_s2_c32_to64         ║
# ║    make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=conv1_c64_to32            ║
# ║    make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=conv3_c128_to128          ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║  三、批量仿真（BATCH_SUITE）                                                   ║
# ║    make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int8              ║
# ║    make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int16             ║
# ║    make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_extreme_small     ║
# ║    make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all               ║
# ║    make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_network           ║
# ║    make sim-batch MODULE_CASE=qa          BATCH_SUITE=qa_all                 ║
# ║    make sim-batch MODULE_CASE=dqa         BATCH_SUITE=dqa_all                ║
# ║    make sim-batch MODULE_CASE=im2col      BATCH_SUITE=im2col_all             ║
# ║    make sim-batch MODULE_CASE=mp          BATCH_SUITE=mp_all                 ║
# ║    make sim-batch MODULE_CASE=us          BATCH_SUITE=us_all                 ║
# ║    make sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all        ║
# ║    make sim-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int8              ║
# ║    make sim-suite MODULE_CASE=mp          BATCH_SUITE=mp_all                 ║
# ║    make sim-suite MODULE_CASE=dqa         BATCH_SUITE=dqa_all                ║
# ║    make data-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int8             ║
# ║    make data-suite MODULE_CASE=mp          BATCH_SUITE=mp_all                ║
# ║    make run-suite  MODULE_CASE=dcim_matmul                                    ║
# ║    make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int8          ║
# ║    make rebuild-suite MODULE_CASE=mp          BATCH_SUITE=mp_all             ║
# ║    make sim-batch ... LOG=1               # 同时写 sim_batch.log             ║          ║
# ║    # 失败不停：                                                                ║
# ║    make sim-batch BATCH_SUITE=dcim_smoke STOP_ON_FAIL=0                      ║
# ║    # export + 批量（BD 变更后一步到位）：                                        ║
# ║    make sim-batch-export BATCH_SUITE=dcim_smoke                              ║
# ║    # 自定义变体列表：                                                           ║
# ║    make sim-batch MODULE_CASE=dcim_matmul MODULE_VARIANTS="conv1_c64_to32 conv3_c128_to128" ║
# ║    # sim-batch vs sim-suite vs rebuild-suite：                                ║
# ║    # sim-batch: 每个 case 单独调用脚本，按 case 分目录，便于逐个重跑与定位      ║
# ║    # sim-suite:  先生成 suite.txt，再用单个 simv 进程连续跑，减少启动开销       ║
# ║    # rebuild-suite: 先重新生成 suite 数据并重编共享 simv，再单进程连续跑；      ║
# ║    #                适合 RTL 刚改过，避免复用旧 simv；但不重新 Vivado export    ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║  四、运行监控（另开终端执行）                                                    ║
# ║    make sim-ps                          # 进程/CPU/RSS + sim.log 末行（一次性）  ║
# ║    make sim-watch                       # 每 5s 自动刷新（Ctrl+C 退出）         ║
# ║    make sim-watch WATCH_INTERVAL=10     # 自定义刷新间隔（秒）                   ║
# ║    make sim-done                        # 退出码: 0=PASS 1=FAIL 2=RUNNING      ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║  五、数据生成与查看                                                             ║
# ║    make data                            # 生成默认用例的 golden 数据            ║
# ║    make data MODULE_CASE=qa MODULE_VARIANT=qa_c16_signed                     ║
# ║    make data-batch BATCH_SUITE=qa_all   # 批量生成 golden 数据                 ║
# ║    make list-cases MODULE_CASE=dcim_matmul  # 列出该模块所有可用变体            ║
# ║    make list-cases MODULE_CASE=qa           # 列出 qa 所有可用变体              ║
# ║    make list-cases MODULE_CASE=dqa          # 列出 dqa 所有可用变体             ║
# ║    make list-cases MODULE_CASE=im2col       # 列出 im2col 所有可用变体          ║
# ║    make list-cases MODULE_CASE=mp           # 列出 maxpooling 所有可用变体      ║
# ║    make list-suites                     # 列出所有预置 BATCH_SUITE 名称         ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║  六、选项开关                                                                  ║
# ║    FAST=1（默认）  跳过 -debug_access（快），FAST=0 保留（Verdi 调试用）         ║
# ║    VCS_JOBS=64（默认） VCS/vlogan 编译并行核数；可设 96/128 或 1 关闭并行     ║
# ║    SIMV_JOBS=32（默认） simv 运行并行核数；若 license 不支持可设 0/1 关闭      ║
# ║    STOP_ON_FAIL=1（默认）  批量遇 FAIL 立刻停，STOP_ON_FAIL=0 跑完全部         ║
# ║    MODULE_VERIFY_WORDS=N   只校验前 N 个 128-bit 输出 word（0=全量，默认全量）   ║
# ╠══════════════════════════════════════════════════════════════════════════════╣
# ║  七、清理                                                                     ║
# ║    make clean                           # 删除当前 MODULE_CASE+VARIANT 的编译产物 ║
# ║    make clean MODULE_CASE=qa MODULE_VARIANT=qa_c16_signed                    ║
# ║    rm -rf sim/                          # 清除所有 build 目录（谨慎）            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

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
# LOG=1 同时写 sim_batch.log（默认只打屏）
# FAST=1 快速（跳过 -debug_access），FAST=0 保留（Verdi 需要）
# VCS_JOBS/SIMV_JOBS 默认启用多核；若 VCS license 不支持运行期 -j，可用 SIMV_JOBS=0 关闭
WATCH_INTERVAL ?= 5

MODULE_TB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT     := $(abspath $(MODULE_TB_DIR)/../../../..)
EXPORT_VCS_DIR := $(REPO_ROOT)/sim/lite_bd_export/vcs/lite/vcs
SIM_DIR       := $(MODULE_TB_DIR)/sim

# 共享编译目录 + 每个运行用例独立 RUN_DIR。VCS simv 只需编译/elaborate 一次。
_VARIANT_SLUG := $(subst /,_,$(MODULE_CASE))_$(subst /,_,$(MODULE_VARIANT))
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
# ── DCIM 矩阵乘 ──────────────────────────────────────────────────────────────
BATCH_SUITE_dcim_int8       := dcim_tiny_1x1 conv6_s2_c3_to16 conv3_s2_c32_to64 conv1_c64_to32 conv3_c128_to128
BATCH_SUITE_dcim_int16      := int16_tiny_1x1 int16_conv3_c32_c64 int16_conv1_c128
BATCH_SUITE_dcim_extreme_small := extreme_int8_1x1_c512_to512 extreme_int8_3x3_c128_to512 extreme_int8_6x6_c3_to64 extreme_int16_3x3_c128
BATCH_SUITE_dcim_all        := dcim_tiny_1x1 conv6_s2_c3_to16 conv3_s2_c32_to64 conv1_c64_to32 conv3_c128_to128 int16_tiny_1x1 int16_conv3_c32_c64 int16_conv1_c128
BATCH_SUITE_dcim_network    := dcim_model_3_conv dcim_model_5_conv dcim_model_7_conv
# ── VPU 单元 ────────────────────────────────────────────────────────────────
BATCH_SUITE_qa_all          := qa_c16_signed qa_c64_clip qa_c128_dense
BATCH_SUITE_dqa_all         := dqa_c16_small dqa_c64_mid dqa_c128_sppf
BATCH_SUITE_im2col_all      := im2col_6x6_s2_c3 im2col_3x3_s2_c32 im2col_3x3_s1_c128 im2col_1x1_c512
BATCH_SUITE_mp_all          := mp_sppf_128_10
BATCH_SUITE_us_all          := us_128_10_to20 us_64_20_to40
BATCH_SUITE_conv_pipe_all   := pipe_conv3_s2_c32_to64 pipe_conv1_c512_to64_tilepass

.PHONY: export compile run sim sim-export fsdb fsdb-export verdi data clean help
.PHONY: list-cases list-suites check-export
.PHONY: sim-batch sim-batch-export data-batch _sim_batch_run _data_batch_run
.PHONY: data-suite run-suite sim-suite rebuild-suite
.PHONY: sim-ps sim-watch sim-done

# ── 核心 target ──────────────────────────────────────────────────────────────

export:
	@echo "[export] Vivado export_simulation（不跑仿真）"
	cd $(REPO_ROOT) && vivado -mode batch \
		-source $(REPO_ROOT)/scripts/chip-lite/4_export_sim.tcl

compile: check-export
	ACTION=compile COMPILE_DIR=$(COMPILE_DIR) FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 RUN_EXPORT=0 bash $(RUN_SCRIPT)

run: check-export
	ACTION=run COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 RUN_EXPORT=0 bash $(RUN_SCRIPT)

sim: check-export
	ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 RUN_EXPORT=0 bash $(RUN_SCRIPT)

sim-export: export sim

fsdb: check-export
	ACTION=rebuild-sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR=$(RUN_DIR) \
	MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
	MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) FAST=0 VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=1 RUN_EXPORT=0 bash $(RUN_SCRIPT)

fsdb-export: export fsdb

verdi:
	@if [ -f "$(FSDB_FILE)" ]; then verdi -ssf "$(FSDB_FILE)" -nologo & \
	elif [ -d "$(SIMV).daidir" ]; then verdi -simflow -simBin "$(SIMV)" -nologo & \
	else echo "先 make fsdb"; exit 1; fi

# ── 数据 / 列举 ──────────────────────────────────────────────────────────────

data:
	ACTION=gen RUN_DIR=$(RUN_DIR) MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$(MODULE_VARIANT) \
		MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) bash $(RUN_SCRIPT)

data-suite:
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	[ -n "$$variants" ] || { echo "用法: make data-suite BATCH_SUITE=dcim_int8"; echo "      make list-suites"; exit 1; }; \
	ACTION=gen-suite COMPILE_DIR=$(COMPILE_DIR) SUITE_DIR=$(SUITE_DIR) MODULE_CASE=$(MODULE_CASE) \
		MODULE_VARIANTS="$$variants" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) bash $(RUN_SCRIPT)

run-suite: check-export
	ACTION=run-suite COMPILE_DIR=$(COMPILE_DIR) SUITE_DIR=$(SUITE_DIR) MODULE_CASE=$(MODULE_CASE) \
		FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 RUN_EXPORT=0 bash $(RUN_SCRIPT)

sim-suite: check-export
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	[ -n "$$variants" ] || { echo "用法: make sim-suite BATCH_SUITE=dcim_int8"; echo "      make list-suites"; exit 1; }; \
	ACTION=sim-suite COMPILE_DIR=$(COMPILE_DIR) SUITE_DIR=$(SUITE_DIR) MODULE_CASE=$(MODULE_CASE) \
		MODULE_VARIANTS="$$variants" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
		FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 RUN_EXPORT=0 bash $(RUN_SCRIPT)

rebuild-suite: check-export
	@variants="$(MODULE_VARIANTS)"; \
	[ -n "$$variants" ] || variants="$(BATCH_SUITE_$(BATCH_SUITE))"; \
	[ -n "$$variants" ] || { echo "用法: make rebuild-suite BATCH_SUITE=dcim_int8"; echo "      make list-suites"; exit 1; }; \
	ACTION=rebuild-suite COMPILE_DIR=$(COMPILE_DIR) SUITE_DIR=$(SUITE_DIR) MODULE_CASE=$(MODULE_CASE) \
		MODULE_VARIANTS="$$variants" MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
		FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) FSDB=0 RUN_EXPORT=0 bash $(RUN_SCRIPT)

list-cases:
	python3 $(GOLDEN_PY) --module $(MODULE_CASE) --case list

list-suites:
	@echo "BATCH_SUITE 名称：make sim-batch MODULE_CASE=<模块> BATCH_SUITE=<名称>"
	@echo "  dcim_int8        5 个 INT8 用例                         MODULE_CASE=dcim_matmul"
	@echo "  dcim_int16       3 个 INT16 用例                        MODULE_CASE=dcim_matmul"
	@echo "  dcim_extreme_small 4 个小规模极限/64 Tile 用例           MODULE_CASE=dcim_matmul"
	@echo "  dcim_all         INT8 + INT16 全部 8 个                 MODULE_CASE=dcim_matmul"
	@echo "  dcim_network     3 个网络真实尺寸                       MODULE_CASE=dcim_matmul"
	@echo "  qa_all           3 个 QA 用例                           MODULE_CASE=qa"
	@echo "  dqa_all          3 个 DQA 用例                          MODULE_CASE=dqa"
	@echo "  im2col_all       4 个 im2col 用例                       MODULE_CASE=im2col"
	@echo "  mp_all           1 个 maxpooling 用例                   MODULE_CASE=mp"
	@echo "  us_all           2 个 US 上采样用例                     MODULE_CASE=us"
	@echo "  conv_pipe_all    完整 conv 链路 2 个用例                 MODULE_CASE=conv_pipeline"

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
		echo "用法: make sim-batch BATCH_SUITE=dcim_tiny"; \
		echo "      make list-suites"; exit 1; fi; \
	log="$(BUILD_DIR)/sim_batch.log"; mkdir -p "$(BUILD_DIR)"; \
	passed=0; failed=0; total=0; \
	for v in $$variants; do \
		total=$$((total+1)); \
		echo ""; echo ">>> [$$total] $(MODULE_CASE)/$$v  $(shell date '+%H:%M:%S')"; \
		bd="$(SIM_DIR)/run_$(MODULE_CASE)_$$v"; \
		if [ "$(LOG)" = "1" ]; then \
			: > "$$log"; \
			echo "    log → $$log"; \
			( ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR="$$bd" \
				MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$$v MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
				FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) RUN_EXPORT=0 bash $(RUN_SCRIPT) 2>&1 | tee -a "$$log" ); rc=$${PIPESTATUS[0]}; \
		else \
			( ACTION=sim COMPILE_DIR=$(COMPILE_DIR) RUN_DIR="$$bd" \
				MODULE_CASE=$(MODULE_CASE) MODULE_VARIANT=$$v MODULE_VERIFY_WORDS=$(MODULE_VERIFY_WORDS) \
				FAST=$(FAST) VCS_JOBS=$(VCS_JOBS) SIMV_JOBS=$(SIMV_JOBS) RUN_EXPORT=0 bash $(RUN_SCRIPT) 2>&1 ); rc=$$?; \
		fi; \
		if [ $$rc -eq 0 ]; then \
			passed=$$((passed+1)); echo "    PASS ✓"; \
		else \
			failed=$$((failed+1)); echo "    FAIL ✗"; \
			[ "$(STOP_ON_FAIL)" = "1" ] && break; fi; \
	done; \
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
	@echo "第一次 / BD 改过后："
	@echo "  make export                      # 只 Vivado export（约 5~10 分钟）"
	@echo "  make sim-batch BATCH_SUITE=dcim_tiny   # 再跑最小用例"
	@echo ""
	@echo "日常改 RTL 后（不需要 export）："
	@echo "  make compile                     # 只编译共享 simv；RTL 改动后必须重编，仿真才会用新代码"
	@echo "  make clean-compile               # 删除共享 simv/build_shared，下次 compile/sim 会从头重编"
	@echo "  make rebuild-suite BATCH_SUITE=dcim_int8  # 重新生成 suite 数据 + 重编 simv + 单进程连续跑"
	@echo "                                      # rebuild 不做 Vivado export；BD/IP 变更仍需先 make export"
	@echo "  make sim                         # 跑默认用例 dcim_tiny_1x1 (M=4)"
	@echo "  make sim-suite BATCH_SUITE=dcim_int8  # 单 simv 进程连续跑多个 case"
	@echo "  make sim-batch BATCH_SUITE=dcim_tiny"
	@echo "  make sim-batch BATCH_SUITE=dcim_smoke"
	@echo ""
	@echo "仿真运行中另开终端查进度："
	@echo "  make sim-ps    # 进程/CPU/sim.log 末行"
	@echo "  make sim-watch # 每 $(WATCH_INTERVAL)s 自动刷新"
	@echo "  make sim-done  # PASS / FAIL / RUNNING"
	@echo ""
	@echo "  make list-suites   make list-cases MODULE_CASE=dcim_matmul"
	@echo "  make fsdb          # 带波形（慢）  make verdi"
	@echo "  make clean"
	@echo ""
	@echo "变量:  MODULE_CASE=$(MODULE_CASE)  MODULE_VARIANT=$(MODULE_VARIANT)"
	@echo "       BATCH_SUITE=$(BATCH_SUITE)  FAST=$(FAST)  VCS_JOBS=$(VCS_JOBS)  SIMV_JOBS=$(SIMV_JOBS)  STOP_ON_FAIL=$(STOP_ON_FAIL)"
