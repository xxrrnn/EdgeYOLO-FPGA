module postProcess#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter CH_OUT = 16,
	parameter ACC = 16,
	localparam WD2 = 2*WD1 + $clog2(CH_IN),
	localparam WD3 = WD2 + $clog2(ACC),
	localparam ACC_UBD_WD = $clog2(ACC+1)
)(
	input clk,
	input rstn,
	input clr,
	input ena,

	input [2: 0] mode,
	input [ACC_UBD_WD-1: 0] acc,
	
	input  up_valid,
	output up_ready,
	output dn_valid,
	input  dn_ready,

	input  [WD2*CH_OUT-1: 0] up_data,
	output [WD3*CH_OUT-1: 0] dn_data

);
	wire merge_valid, merge_ready;
	wire [WD2*CH_OUT-1: 0] merge_data;

	mergeArray#(.WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT)) u_mergeArray(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.mode(mode),
		.up_valid(up_valid),    .up_ready(up_ready),    .up_data(up_data),
		.dn_valid(merge_valid), .dn_ready(merge_ready), .dn_data(merge_data)
	);

	// Pipeline register between mergeArray and accumulateArray (替代 MCP 4.1c/d)
	wire pipe_valid, pipe_ready;
	reg [WD2*CH_OUT-1: 0] pipe_data;

	pipe_stage u_pipe_merge_accum(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.up_valid(merge_valid), .up_ready(merge_ready),
		.dn_valid(pipe_valid),  .dn_ready(pipe_ready)
	);

	always @(posedge clk or negedge rstn) begin
		if (~rstn)
			pipe_data <= {(WD2*CH_OUT){1'b0}};
		else if (clr)
			pipe_data <= {(WD2*CH_OUT){1'b0}};
		else if (merge_valid & merge_ready)
			pipe_data <= merge_data;
	end

	accumulateArray#(.WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT), .ACC(ACC)) u_accumulate(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.mode(mode), .acc(acc),
		.up_valid(pipe_valid), .up_ready(pipe_ready), .up_data(pipe_data),
		.dn_valid(dn_valid),   .dn_ready(dn_ready),   .dn_data(dn_data)
	);

endmodule
