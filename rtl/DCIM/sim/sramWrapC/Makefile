.PHONY: all compile run wave check clean help

all:compile run wave

compile:
	iverilog -g2005-sv -D SIM -D IVERILOG -I ../../inc/ -o simv \
		../../src/sramWrap.v		\
		../../src/dff.v				\
		../../../macro/rf_sp_hde.v	\
		../../src/counter.v			\
		../../tb/sramWrap_tb.v

run:
	./simv

wave:
	gtkwave waveform.vcd signals.gtkw &

clean:
	rm -f *.fsdb *.vdb *.log simv novas.* ucli.key *.vcd *.txt *.mem
	rm -rf *.daidir csrc verdiLog 
