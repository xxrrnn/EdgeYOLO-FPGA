`timescale 1ns / 1ps

// Include 语句已注释，因为这些文件在 filelist.f 中已明确包含
// `include "para.v"
// `include "counter.v"
// `include "dff.v"
// `include "pipe_stage.v"

module dcim #(
    parameter WD1 = 4,
    parameter CH_IN = 16,
    parameter CH_OUT = 16,
    parameter SRAM_DP = 128,
    parameter CYCLE = 8,
    parameter ACC = 16,
    
    localparam SRAM_WD = CH_IN * CH_OUT * WD1 / CYCLE, // 128-bit
    localparam ADDR_WD = $clog2(SRAM_DP),
    localparam TILE_WD = CH_IN * CH_OUT * WD1,         // 1024-bit
    localparam ACC_UBD_WD = $clog2(ACC+1),
    localparam WD2 = 2*WD1 + $clog2(CH_IN),
    localparam WD3 = WD2 + $clog2(ACC)
)(
    input 						clk,
    input 						rstn,
    input 						clr,
    input 						ena,
    
	input  [2: 0] 				mode_cal,
	input  [ACC_UBD_WD-1: 0] 	acc,

    input  						wr_wei,	// Write Only.
	input  						load_wei,
	input  				  		swap_wei,
    output 						up_ready_wei,
    input  [ADDR_WD-1: 0] 		up_address_wei,
    input  [SRAM_WD-1: 0] 		up_data_wei,
    input  [SRAM_WD-1: 0] 		up_be_wei,

	input  						up_valid_cal,
	output 						up_ready_cal,
    input  [CH_IN*WD1-1: 0] 	up_data_cal, 
    
	output 						dn_valid,
	input  						dn_ready,
    output [CH_OUT*WD3-1: 0] 	dn_data
);
	wire mid_valid_wei, mid_ready_wei;
	wire [CH_IN*CH_OUT*WD1-1: 0] mid_data_wei;
	wire mid_valid_cal, mid_ready_cal;
	wire [CH_OUT*WD2-1: 0] mid_data_cal;
	wire w_ready_cal;

	memory#(
		.WD(SRAM_WD), .DP(SRAM_DP), .CH_IN(CH_IN), 
		.CH_OUT(CH_OUT), .WD1(WD1), .CYCLE(CYCLE)
	) u_memory(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.req(wr_wei),	.we(wr_wei),
		.load(load_wei),
		.be(up_be_wei),
		.addr(up_address_wei), .swap(swap_wei),
		.up_ready(up_ready_wei),  .up_data(up_data_wei),
		.dn_valid(mid_valid_wei), .dn_data(mid_data_wei)
	);

    calculate_core #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT)
    ) u_calculate_core (
        .clk(clk), .rstn(rstn), .clr(clr), .ena(ena), .mode(mode_cal),
        .up_valid(up_valid_cal), .up_ready(w_ready_cal),
        .up_data1(up_data_cal),  .up_data2(mid_data_wei),
        .dn_valid(mid_valid_cal), .dn_ready(mid_ready_cal),
		.dn_data(mid_data_cal)
    );

	postProcess #(
		.WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT), .ACC(ACC)
	) u_postProcess (
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena), .mode(mode_cal), .acc(acc),
		.up_valid(mid_valid_cal), .up_ready(mid_ready_cal),
		.up_data(mid_data_cal),
		.dn_valid(dn_valid), .dn_ready(dn_ready), .dn_data(dn_data)
	);
	
	assign up_ready_cal = w_ready_cal & mid_valid_wei;

endmodule
