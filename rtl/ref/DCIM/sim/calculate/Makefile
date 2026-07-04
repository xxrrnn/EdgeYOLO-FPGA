.PHONY: all compile run wave check clean help

RtlFileList := filelist.f

TYPE ?= INT8
ACC ?= 0
UNI ?= 0

CH_IN ?= 16
CH_OUT ?= 16
WD1 ?= 4
R ?= 8

WAVE ?= n

export TYPE := $(TYPE)
export ACC := $(ACC)
export UNI := $(UNI)
export CH_IN := $(CH_IN)
export CH_OUT := $(CH_OUT)
export WD1 := $(WD1)
export R := $(R)

VALID_TYPES := INT4 UINT4 INT8 UINT8 INT16 UINT16
ifeq ($(filter $(TYPE),$(VALID_TYPES)),)
    $(error Wrong TYPE: $(TYPE). Choose From: $(VALID_TYPES))
endif

ALL_DEPS := info compile run
ifeq ($(WAVE), y)
	ALL_DEPS += wave
endif
ALL_DEPS += check

all: $(ALL_DEPS)

info:
	@echo "---------------------------------------"
	@echo "Run Instance: "
	@echo "  TYPE : $(TYPE)"
	@echo "  ACC : $(ACC) $(if $(filter 0,$(ACC)),[No Accumulation],[Accumulation Mode])"
	@echo "  UNI : $(UNI) $(if $(filter 1,$(UNI)),[Uniform Flow],[Random Flow])"
	@echo "---------------------------------------"


compile:
	iverilog -g2005-sv -D ACC=$(ACC) -D TEST_$(TYPE) -D UNI=$(UNI) -D SIM -D IVERILOG -I ../../inc/ -o simv \
		-D CH_IN=$(CH_IN) -D CH_OUT=$(CH_OUT) -D R=$(R)	-D WD1=$(WD1)	\
		../../src/multiplier.v		\
		../../src/adderTree.v		\
		../../src/maArray.v			\
		../../src/mergeArray.v		\
		../../src/accumulateArray.v	\
		../../src/calculate.v		\
		../../tb/calculate_tb.v

run:
	./simv

wave:
	gtkwave waveform.vcd signals.gtkw &

clean:
	rm -f *.fsdb *.vdb *.log simv novas.* ucli.key *.vcd *.txt *.mem
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
	@echo "                 Verilog Simulation & Data Check Build"
	@echo "========================================================================"
	@echo "Usage: make [target] [PARAMETER=VALUE]"
	@echo ""
	@echo "Targets:"
	@echo "  all       : Run info, compile, run, (wave), and check"
	@echo "  compile   : Compile RTL using iverilog"
	@echo "  run       : Execute simulation binary"
	@echo "  wave      : Open gtkwave (requires .vcd)"
	@echo "  check     : Run Python post-processing (auto-detects venv)"
	@echo "  clean     : Remove all temporary simulation files"
	@echo ""
	@echo "Parameters:"
	@echo "  TYPE      : Data type $(VALID_TYPES)"
	@echo "  ACC       : Accumulation cycles (0 to disable)"
	@echo "  UNI       : Uniform distribution (1=Yes, 0=No)"
	@echo "  WAVE      : Set to 'y' to show waveform automatically [default: n]"
	@echo "More Parameters:"
	@echo "  WD1	   : Basic data width [default: 4]"
	@echo "  CH_IN     : [default: 16]"
	@echo "  CH_OUT    : [default: 16]"
	@echo "  R         : Max Accumulation times [default: 8]"
	@echo ""
	@echo "Example:"
	@echo "  make all TYPE=UINT4 ACC=3 WAVE=y"
	@echo "========================================================================"

