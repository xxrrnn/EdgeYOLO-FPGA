`timescale 1ns / 1ps
`include "para.v"
`include "simTools.v"
module dcim_tb#(
	parameter WD1 = `WD1,
	parameter CH_IN = `CH_IN,
	parameter CH_OUT = `CH_IN,
	parameter SRAM_DP = 128,
	parameter CYCLE = 8,
	parameter ACC = `R,

	localparam SRAM_WD = CH_IN * CH_OUT * WD1 / CYCLE,
	localparam ACC_UBD_WD = $clog2(ACC+1),
	localparam ADDR_WD = $clog2(SRAM_DP),
	localparam WD2 = 2*WD1 + $clog2(CH_IN),
	localparam WD3 = WD2 + $clog2(ACC)
);
	localparam T = 10;

	reg clk, rstn, clr, ena;
	reg ena_stu_m, ena_stu_c, ena_std;
	wire wr_wei;
	reg swap_wei, load_wei;
	reg [2: 0] mode_cal;
	reg [ACC_UBD_WD-1: 0] acc;
	reg [ADDR_WD-1: 0]  up_address_wei;
	reg [SRAM_WD-1: 0] dcim_be_wei;

	wire [SRAM_WD-1: 0]    up_data_wei;
	wire [CH_IN*WD1-1: 0]  up_data_cal;
	wire [CH_OUT*WD3-1: 0] dn_data;

	dcim#(
		.WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
		.SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC)
	) u_dcim(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		
		.mode_cal(mode_cal), .acc(acc),
		.up_address_wei(up_address_wei),

		.wr_wei(wr_wei),
		.load_wei(load_wei),
		.swap_wei(swap_wei),
		.up_ready_wei(up_ready_wei),
		.up_data_wei(up_data_wei),
		.up_be_wei(dcim_be_wei),

		.up_valid_cal(up_valid_cal),
		.up_ready_cal(up_ready_cal),
		.up_data_cal(up_data_cal),
		
		.dn_valid(dn_valid),
		.dn_ready(dn_ready),
		.dn_data(dn_data)
	);

	simToolUp#(
		.FILE("memory.mem"), .WD(SRAM_WD), .SPLIT_WD(WD1), .MODE(1)
	) u_simToolUp_wei(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena_stu_m), .r(1'b0),
		.dn_valid(wr_wei), .dn_ready(up_ready_wei), .dn_data(up_data_wei)
	);

	simToolUp#(
		.FILE("calculate.mem"), .WD(CH_IN*WD1), .SPLIT_WD(WD1), .MODE(1)
	) u_simToolUp_cal(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena_stu_c), .r(1'b0),
		.dn_valid(up_valid_cal), .dn_ready(up_ready_cal), .dn_data(up_data_cal)
	);

	simToolDown#(
		.FILE("result.mem"), .WD(CH_OUT*WD3), .SPLIT_WD(WD3)
	) u_simToolDown(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena_std), .r(1'b0),
		.up_valid(dn_valid), .up_ready(dn_ready), .up_data(dn_data)
	);

	always#(T/2) clk <= ~clk;

	initial begin
		clk=0; rstn=0; clr=0; ena=1;
		ena_stu_m=1; ena_stu_c=0; ena_std=1;
		load_wei=0; swap_wei=0;
		dcim_be_wei = {SRAM_WD{1'b1}};
		mode_cal=`MODE_INT4;
		`ifdef TEST_INT4
			mode_cal=`MODE_INT4;
		`endif
		`ifdef TEST_UINT4
			mode_cal=`MODE_UINT4;
		`endif
		`ifdef TEST_INT8
			mode_cal=`MODE_INT8;
		`endif
		`ifdef TEST_UINT8
			mode_cal=`MODE_UINT8;
		`endif
		`ifdef TEST_INT16
			mode_cal=`MODE_INT16;
		`endif
		`ifdef TEST_UINT16
			mode_cal=`MODE_UINT16;
		`endif
		acc = `ACC;

		up_address_wei = 0;
		#(T);
		rstn=1;

		// Load SRAM Data
		repeat(SRAM_DP) #(T) begin
			up_address_wei <= up_address_wei + 1'b1;
		end
		ena_stu_m=0;


		// Load Cache Data
		up_address_wei = 0;
		load_wei = 1;
		#(T) load_wei = 0;
		#((CYCLE+2)*T);
		load_wei = 1;
		#(T) load_wei = 0;

		swap_wei = 1'b1;
		#(T) swap_wei = 1'b0;

		printMemory("cache.mem");

		#(T);

		ena_stu_c=1;
		#(1000*T);

		ena_stu_c=0;
		#(10*T);
		$finish;
	end

	initial begin
`ifdef DUMP_FSDB
		$fsdbDumpfile("waveform.fsdb");
		$fsdbDumpvars(0, dcim_tb);
`else
		$dumpfile("waveform.vcd");
		$dumpvars(0, dcim_tb);
`endif
	end

	task printMemory;
		input[1023: 0] file_name;
		integer file;
		file = $fopen(file_name, "w");

		for(integer ch_in=CH_IN-1; ch_in>=0; ch_in=ch_in-1) begin:ChannelIn
			for(integer ch_out=CH_OUT-1; ch_out>=0; ch_out=ch_out-1) begin:ChannelOut
				$fwrite(file, "%b ", u_dcim.mid_data_wei[(ch_out*CH_IN+ch_in)*WD1+: WD1]);
			end
			$fwrite(file, "\n");
		end
		
	endtask
endmodule
