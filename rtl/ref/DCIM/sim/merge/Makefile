RtlFileList := filelist.f

.PHONY: all compile run clean

all: compile run wave

compile:
	iverilog -g2005-sv -D IVERILOG -I ../../src/ -o simv \
	../../tb/merge_controller_tb.v \
	../../src/merge.v \
	../../src/counter.v

run:
	./simv

wave:
	gtkwave -f waveform.vcd &

clean:
	rm -f *.fsdb *.vdb *.log simv novas.* ucli.key *.vcd
	rm -rf *.daidir csrc verdiLog 
