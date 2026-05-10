# DCIM top simulation: two flows — default iverilog; optional Synopsys VCS (+ Verdi).
# Run all commands from this directory: cd rtl/ref/DCIM/sim/dcim

include sim_vars.mk

.PHONY: all all_vcs compile compile_iverilog compile_vcs run run_vcs wave verdi clean check help

export TYPE := $(TYPE)
export ACC := $(ACC)
export CH_IN := $(CH_IN)
export CH_OUT := $(CH_OUT)
export WD1 := $(WD1)
export R := $(R)

WAVE ?= n

IVERILOG ?= iverilog
VCS ?= vcs

ALL_TASKS := compile run
ifeq ($(WAVE), y)
	ALL_TASKS += wave
endif
ALL_TASKS += check

all: $(ALL_TASKS)

# --- iverilog (default): executable simv ------------------------------------
compile: compile_iverilog

compile_iverilog:
	$(IVERILOG) -g2005-sv $(INC_IVERILOG) $(IVERILOG_DEFS) -o simv -c filelist.f

run: run_iverilog

run_iverilog:
	./simv

# --- Synopsys VCS: executable simv_vcs -----------------------------------
# If simv_vcs was deleted but simv_vcs.daidir remains, VCS skips relinking and
# leaves no binary — remove the incremental timestamp so the executable is rebuilt.
compile_vcs:
	@if [ ! -x ./simv_vcs ] && [ -f simv_vcs.daidir/.vcs.timestamp ]; then \
		rm -f simv_vcs.daidir/.vcs.timestamp; \
	fi
	$(VCS) -full64 -sverilog +v2k $(INC_VCS) $(VCS_DEFS) \
		-debug_access+all -kdb \
		-ignore initializer_driver_checks \
		-f filelist.f \
		-o simv_vcs \
		-l compile_vcs.log
	@test -x ./simv_vcs || (echo "compile_vcs failed: ./simv_vcs missing (see compile_vcs.log)" >&2; exit 1)

run_vcs:
	@test -x ./simv_vcs || (echo "run_vcs: ./simv_vcs not found — run: make compile_vcs" >&2; exit 1)
	./simv_vcs

# Compile + run + check with VCS (same stimulus/output files as iverilog)
all_vcs: compile_vcs run_vcs check

wave:
	gtkwave waveform.vcd signals.gtkw &

# Verdi: opens VCD from either flow (waveform.vcd). Set VERDI_HOME if verdi is not in PATH.
VERDI_BIN ?= $(if $(VERDI_HOME),$(VERDI_HOME)/bin/verdi,verdi)
verdi:
	@$(VERDI_BIN) -ssf waveform.vcd &

clean:
	rm -f *.fsdb *.vdb *.log simv simv_vcs novas.* ucli.key *.vcd *.txt *.mem compile_vcs.log
	rm -rf *.daidir csrc verdiLog

ifeq ($(VIRTUAL_ENV),)
    VENV_PYTHON := $(shell \
        curr=$$(pwd); \
        while [ "$$curr" != "/" ]; do \
            if [ -f "$$curr/venv/bin/python" ]; then \
                echo "$$curr/venv/bin/python"; break; \
            elif [ -f "$$curr/.venv/bin/python" ]; then \
                echo "$$curr/.venv/bin/python"; break; \
            fi; \
            curr=$$(dirname "$$curr"); \
        done)
endif

PYTHON := $(if $(VENV_PYTHON),$(VENV_PYTHON),python3)

check:
	$(PYTHON) transfer.py

help:
	@echo "========================================================================"
	@echo "  DCIM 仿真：iverilog（默认）与 VCS / Verdi 分开使用"
	@echo "========================================================================"
	@echo ""
	@echo "【iverilog — 默认】产物: ./simv ，波形: waveform.vcd（GTKWave）"
	@echo "  make compile          # 同 compile_iverilog"
	@echo "  make compile_iverilog"
	@echo "  make run              # 同 run_iverilog"
	@echo "  make run_iverilog"
	@echo "  make all              # compile + run [+ wave] + check"
	@echo "  make wave             # gtkwave waveform.vcd signals.gtkw"
	@echo ""
	@echo "【Synopsys VCS】产物: ./simv_vcs ，同样写 waveform.vcd；可用 Verdi 查看"
	@echo "  make compile_vcs"
	@echo "  make run_vcs"
	@echo "  make all_vcs          # compile_vcs + run_vcs + check"
	@echo "  make verdi            # Verdi 打开 waveform.vcd（需 PATH 或 VERDI_HOME）"
	@echo "  # 或用 KDB: verdi -dbdir simv_vcs.daidir（先 make run_vcs）"
	@echo ""
	@echo "宏说明: iverilog 使用 -D IVERILOG；VCS 使用 +define+VCS（两套独立可执行文件）"
	@echo "VCS 对 model_rf.sv 使用 -ignore initializer_driver_checks（与 iverilog 行为一致）"
	@echo ""
	@echo "参数示例: TYPE=INT8 ACC=0 CH_IN=16 CH_OUT=16 WD1=4 R=16 WAVE=y"
	@echo "========================================================================"
