SIM_CPP?=sim.cpp
TOP?=dcim_wrapper

all:compile run

compile:
	verilator -cc --build --trace -DSIM \
		-Wno-SPECIFYIGN -Wno-MULTITOP -Wno-TIMESCALEMOD -Wno-MISINDENT \
		-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-STMTDLY -Wno-LATCH -Wno-UNOPTFLAT \
		--timing					\
		-f filelist.f \
		-exe sim.cpp \
		-y ../../src/inc	\
		--top ${TOP}

run:
	./obj_dir/V${TOP}

wave:
	gtkwave waveform.vcd

clean:
	rm -rf obj_dir*
	rm -f *.vcd *.fsdb
