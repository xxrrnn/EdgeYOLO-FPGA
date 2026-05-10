`ifndef SIMTOOLS
`define SIMTOOLS
`timescale 1ns / 1ps
module randomCounter#(
	parameter UBD_MAX = 4,
	parameter CNT_WD = $clog2(UBD_MAX),
	parameter UBD_WD = $clog2(UBD_MAX+1)
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	output cnt_done
);
	reg [CNT_WD-1: 0] r_cnt;
	wire [UBD_WD-1: 0] w_cnt_plus1;
	assign w_cnt_plus1 = r_cnt + 1'b1;

	wire cnt_done_flag;
	reg [UBD_WD-1: 0] r_ubd;
	assign cnt_done_flag = (w_cnt_plus1 == r_ubd);

	initial begin
		r_ubd = $urandom_range(1, UBD_MAX);
	end

	always@(posedge clk or negedge rstn) begin
		if(~rstn)
			r_cnt <= 0;
		else if(clr)
			r_cnt <= 0;
		else if(ena) begin
			if(cnt_done_flag) begin
				r_cnt <= 0;
				r_ubd <= $urandom_range(1, UBD_MAX);
			end
			else begin
				r_cnt <= w_cnt_plus1[CNT_WD-1:0];
			end
		end
	end

	assign cnt_done = ena & cnt_done_flag;

endmodule

module simToolUp#(
	parameter INTERNAL_MAX = 4,
	parameter FILE = "simToolUp.mem",
	parameter WD = 8,
	parameter MEM_DEPTH = 1024,
	parameter SPLIT_WD = 0,
	parameter MODE = 1 // 0: read from FILE, 1: write random to FILE
)(
	input clk,
	input rstn,
	input clr,
	input ena,

	input r,
	output [WD-1: 0] dn_data,

	input dn_ready,
	output dn_valid
);

	wire w_handshake;
	assign w_handshake = dn_valid & dn_ready;
	wire w_cnt_done;

	reg r_state;

	randomCounter#(
		.UBD_MAX(INTERNAL_MAX)
	) u_randomCounter(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(ena),
		.cnt_done(w_cnt_done)
	);

	always@(posedge clk or negedge rstn) begin
		if(~rstn)
			r_state <= 0;
		else if(clr)
			r_state <= 0;
		else if(ena) begin
			case(r_state)
				0: r_state <= w_cnt_done? 1: 0;
				1: r_state <= w_handshake? (w_cnt_done? 1: 0): 1;
				default: r_state <= 0;
			endcase
		end
	end

	assign dn_valid = ena & ((r_state == 1'b1) || ~r);

	generate
		if(MODE) begin : g_simtool_up_writer
			integer file;
			initial begin
				file = $fopen(FILE, "w");
				if (file == 0) $fatal(0, "simToolUp: cannot open %s for write", FILE);
			end
			reg [WD-1: 0] randomData;

			assign dn_data = randomData;
			always @(posedge clk) begin
				if(~rstn) begin
				randomData <= $urandom();
				end else if(clr) begin
					randomData <= $urandom();
				end else if(ena && w_handshake) begin
					for(integer bit_idx=0; bit_idx<WD; bit_idx=bit_idx+1) begin
						randomData[bit_idx +: 1] <= $urandom;
					end
					if(SPLIT_WD==0) begin
						$fwrite(file, "%b\n", randomData);
					end else begin
						for(integer bit_idx=WD-1; bit_idx>=0; bit_idx=bit_idx-SPLIT_WD) begin
							$fwrite(file, "%b ", randomData[bit_idx -: SPLIT_WD]);
						end
						$fwrite(file, "\n");
					end
				end else begin
					randomData <= randomData;
				end
			end
		end else begin : g_simtool_up_reader
			integer file;
			reg [WD-1:0] mem [0:MEM_DEPTH-1];
			integer idx;
			integer row;
			reg [WD-1:0] temp;
			initial begin
				row = 0;
				idx = 0;
				file = $fopen(FILE, "r");
				if (file == 0) $fatal(0, "simToolUp: cannot open %s for read", FILE);
				while(!$feof(file)) begin
					if(SPLIT_WD==0) begin
						$fscanf(file, "%b\n", temp);
						mem[idx] = temp;
					end else begin
						for(integer bit_idx=WD-1; bit_idx>=0; bit_idx=bit_idx-SPLIT_WD) begin
							$fscanf(file, "%b", temp);
							mem[idx][bit_idx-: SPLIT_WD] = temp[SPLIT_WD-1: 0];
						end
					end
					idx = idx + 1;
				end
				$fclose(file);
			end

			always @(posedge clk or negedge rstn) begin
				if(~rstn) begin
					row <= 0;
				end else if(clr) begin
					row <= 0;
				end else if(ena) begin
					if(w_handshake) begin
						if(row < MEM_DEPTH) begin
							row <= row + 1;
						end else begin
							$fatal(0, "simToolUp: read beyond memory depth");
						end
					end
				end else begin
					row <= row;
				end
			end

			assign dn_data = mem[row];
		end
	endgenerate

endmodule

// Downstream simulator: consumes valid-ready traffic and optionally gates up_ready.
module simToolDown#(
	parameter INTERNAL_MAX = 4,
	parameter FILE = "simToolDown.mem",
	parameter WD = 8,
	parameter MEM_DEPTH = 1024,
	parameter SPLIT_WD = 0
	)(
	input clk,
	input rstn,
	input clr,
	input ena,

	input r,
	input [WD-1: 0] up_data,
	input up_valid,
	output up_ready
);
	wire w_handshake;
	assign w_handshake = up_ready & up_valid;
	wire w_cnt_done;

	reg r_state;

	randomCounter#(
		.UBD_MAX(INTERNAL_MAX)
	) u_randomCounter(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(ena),
		.cnt_done(w_cnt_done)
	);

	always@(posedge clk or negedge rstn) begin
		if(~rstn)
			r_state <= 0;
		else if(clr)
			r_state <= 0;
		else if(ena) begin
			case(r_state)
				0: r_state <= w_cnt_done? 1: 0;
				1: r_state <= w_handshake? (w_cnt_done? 1: 0): 1;
				default: r_state <= 0;
			endcase
		end
	end

	integer file;

	always@(posedge clk) begin
		if(w_handshake) begin
			if(SPLIT_WD==0) begin
				$fwrite(file, "%b\n", up_data);
			end else begin
				for(integer bit_idx=WD-1; bit_idx>=0; bit_idx=bit_idx-SPLIT_WD) begin
					$fwrite(file, "%b ", up_data[bit_idx -: SPLIT_WD]);
				end
				$fwrite(file, "\n");
			end
		end
	end

	initial begin
		file = $fopen(FILE, "w");
		if (file == 0) begin
			$fatal(0, "simToolDown: cannot open %s for write", FILE);
		end
	end

	assign up_ready = ena & ((r_state == 1'b1) || ~r);

endmodule

`endif
