# DCIM top simulation: Synopsys VCS only; default waveform is FSDB (Verdi).
# Run from this directory: cd rtl/ref/DCIM/sim/dcim

include sim_vars.mk

# FSDB=1 (default): compile with Verdi PLI + DUMP_FSDB; requires VERDI_HOME.
# FSDB=0: VCD via $dumpvars, no Verdi PLI (no VERDI_HOME needed).
FSDB ?= 1

ifeq ($(FSDB),1)
ifeq ($(strip $(VERDI_HOME)),)
$(error FSDB=1 requires VERDI_HOME (export VERDI_HOME=/path/to/verdi). Or use: make compile FSDB=0)
endif
VERDI_PLI := -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a
FSDB_DEF := +define+DUMP_FSDB
else
VERDI_PLI :=
FSDB_DEF :=
endif

.PHONY: all compile compile_vcs run run_vcs wave verdi clean check help \
	test_int8xint8 test_int16xint16 simv all_vcs

export TYPE := $(TYPE)
export ACC := $(ACC)
export CH_IN := $(CH_IN)
export CH_OUT := $(CH_OUT)
export WD1 := $(WD1)
export R := $(R)

WAVE ?= n

VCS ?= vcs

ALL_TASKS := compile run
ifeq ($(WAVE), y)
	ALL_TASKS += wave
endif
ALL_TASKS += check

all: $(ALL_TASKS)

# Executable: ./simv (Synopsys convention)
compile compile_vcs simv:
	@if [ ! -x ./simv ] && [ -f simv.daidir/.vcs.timestamp ]; then \
		rm -f simv.daidir/.vcs.timestamp; \
	fi
	$(VCS) -full64 -sverilog +v2k $(INC_VCS) $(VCS_DEFS) $(FSDB_DEF) $(VERDI_PLI) \
		-debug_access+all -kdb \
		-ignore initializer_driver_checks \
		-f filelist.f \
		-o simv \
		-l compile.log
	@test -x ./simv || (echo "compile failed: ./simv missing (see compile.log)" >&2; exit 1)

run run_vcs:
	@test -x ./simv || (echo "run: ./simv not found — run: make compile" >&2; exit 1)
	./simv

all_vcs: all

# --- INT8×INT8 / INT16×INT16 ---
test_int8xint8:
	$(MAKE) compile TYPE=INT8
	TYPE=INT8 $(MAKE) run check

test_int16xint16:
	$(MAKE) compile TYPE=INT16
	TYPE=INT16 $(MAKE) run check

wave verdi:
	@if [ -f waveform.fsdb ]; then \
		$(VERDI_BIN) -ssf waveform.fsdb & \
	elif [ -f waveform.vcd ]; then \
		$(VERDI_BIN) -ssf waveform.vcd & \
	else \
		echo "No waveform.fsdb or waveform.vcd — run simulation first." >&2; exit 1; \
	fi

VERDI_BIN ?= $(if $(VERDI_HOME),$(VERDI_HOME)/bin/verdi,verdi)

clean:
	rm -f *.fsdb *.vdb *.log simv novas.* ucli.key *.vcd *.txt *.mem compile.log compile_vcs.log
	rm -rf simv.daidir *.daidir csrc verdiLog

PYTHON ?= python3

check:
	$(PYTHON) transfer.py

help:
	@echo "========================================================================"
	@echo "  DCIM 仿真：仅 VCS；默认 FSDB（需 VERDI_HOME）；可执行文件 ./simv"
	@echo "========================================================================"
	@echo ""
	@echo "  make compile          # 生成 ./simv（默认 FSDB PLI + DUMP_FSDB）"
	@echo "  make run              # ./simv"
	@echo "  make all              # compile + run [+ wave] + check"
	@echo "  make wave / verdi     # Verdi 打开 waveform.fsdb（若有）否则 waveform.vcd"
	@echo "  make clean"
	@echo ""
	@echo "  FSDB=0 make compile   # 仅 VCD，不需 VERDI_HOME"
	@echo "  export VERDI_HOME=... # FSDB=1 时必须（默认 FSDB=1）"
	@echo ""
	@echo "  make test_int8xint8 / test_int16xint16"
	@echo ""
	@echo "参数示例: TYPE=INT8 ACC=0 CH_IN=16 CH_OUT=16 WD1=4 R=16 WAVE=y"
	@echo "========================================================================"
