.PHONY: all compile run wave check clean help

TYPE ?= INT4
ACC	?= 0
UNI ?= 0

CH_IN ?= 16
CH_OUT ?= 16
WD1	?= 4
R = 16

export TYPE := $(TYPE)
export ACC := $(ACC)
export UNI := $(UNI)
export CH_IN := $(CH_IN)
export CH_OUT := $(CH_OUT)
export WD1 := $(WD1)
export R := $(R)

ALL_TASKS := compile run
ifeq ($(WAVE), y)
	ALL_TASKS += wave
endif
ALL_TASKS += check

all:$(ALL_TASKS)

compile:
	iverilog -g2005-sv -D SIM -D IVERILOG -I ../../inc/ -o simv			\
		-D CH_IN=$(CH_IN) -D CH_OUT=$(CH_OUT) -D R=$(R)	-D WD1=$(WD1)	\
		-D ACC=$(ACC)	-D TEST_$(TYPE)										\
		../../src/rtl/multiplier.v		\
		../../src/rtl/adderTree.v		\
		../../src/rtl/maArray.v			\
		../../src/rtl/calculate_core.v	\
		../../src/rtl/mergeArray.v		\
		../../src/rtl/accumulateArray.v	\
		../../src/rtl/postProcess.v		\
		../../src/rtl/sramWrap.v		\
		../../src/rtl/ppCache.v			\
		../../src/rtl/memory.v			\
		../../src/rtl/dcim.v			\
		../../src/macro/rf_sp_hde.v	\
		../../tb/dcim_tb.v

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

