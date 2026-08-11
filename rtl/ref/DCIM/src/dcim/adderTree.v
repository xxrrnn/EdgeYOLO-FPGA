`timescale 1ns / 1ps

module adderTree#(
	parameter WD_IN = 4,
	parameter CH_IN = 16,
	parameter WD_OUT = WD_IN + $clog2(CH_IN)
)(
	input [WD_IN*CH_IN-1: 0] 	d,
	input 						s,
	output [WD_OUT-1: 0] 		sum
);
	generate
		if(CH_IN == 2) begin: A
			assign sum = s? {d[2*WD_IN-1], d[2*WD_IN-1: WD_IN]} + {d[WD_IN-1], d[WD_IN-1: 0]}: {1'b0, d[2*WD_IN-1: WD_IN]} + {1'b0, d[WD_IN-1: 0]};
		end else begin: B
			wire [WD_IN+$clog2(CH_IN)-2: 0] psum0, psum1;
			adderTree#(.WD_IN(WD_IN), .CH_IN(CH_IN/2)) u_adderTree0(
				.d(d[WD_IN*CH_IN/2-1: 0]),
				.s(s),
				.sum(psum0)
			);
			adderTree#(.WD_IN(WD_IN), .CH_IN(CH_IN/2)) u_adderTree1(
				.d(d[WD_IN*CH_IN-1: WD_IN*CH_IN/2]),
				.s(s),
				.sum(psum1)
			);
			assign sum = s? {psum0[WD_IN+$clog2(CH_IN/2)-1], psum0} + {psum1[WD_IN+$clog2(CH_IN/2)-1], psum1}: {1'b0, psum0} + {1'b0, psum1};
		end
	endgenerate
endmodule

module adderTreePipe#(
    parameter WD_IN = 8,
    parameter CH_IN = 64,
    parameter WD_OUT = WD_IN + $clog2(CH_IN)
)(
    input clk,
    input rstn,
    input clr,
    input ena,
    input [WD_IN*CH_IN-1:0] d,
    input s,
    output [WD_OUT-1:0] sum
);
    generate
        if (CH_IN == 1) begin: gen_one
            reg [WD_OUT-1:0] r_sum;
            // Data state is qualified by maArray's valid pipeline.  Do not
            // distribute reset/clear through every node of the wide tree.
            always @(posedge clk) begin
                if (ena) begin
                    r_sum <= s ? {{(WD_OUT-WD_IN){d[WD_IN-1]}}, d[WD_IN-1:0]} : {{(WD_OUT-WD_IN){1'b0}}, d[WD_IN-1:0]};
                end
            end
            assign sum = r_sum;
        end else begin: gen_tree
            localparam HALF = CH_IN / 2;
            localparam PSUM_W = WD_IN + $clog2(HALF);
            localparam CHILD_LATENCY = $clog2(HALF) + 1;
            wire [PSUM_W-1:0] psum0;
            wire [PSUM_W-1:0] psum1;
            wire s_aligned;
            reg  [WD_OUT-1:0] r_sum;

            dff #(.WD(1), .DP(CHILD_LATENCY)) u_s_delay (
                .clk(clk),
                .rstn(rstn),
                .clr(clr),
                .ena(ena),
                .up_data(s),
                .dn_data(s_aligned)
            );

            adderTreePipe #(
                .WD_IN(WD_IN),
                .CH_IN(HALF),
                .WD_OUT(PSUM_W)
            ) u_adderTreePipe0 (
                .clk(clk),
                .rstn(rstn),
                .clr(clr),
                .ena(ena),
                .d(d[WD_IN*HALF-1:0]),
                .s(s),
                .sum(psum0)
            );

            adderTreePipe #(
                .WD_IN(WD_IN),
                .CH_IN(HALF),
                .WD_OUT(PSUM_W)
            ) u_adderTreePipe1 (
                .clk(clk),
                .rstn(rstn),
                .clr(clr),
                .ena(ena),
                .d(d[WD_IN*CH_IN-1:WD_IN*HALF]),
                .s(s),
                .sum(psum1)
            );

            always @(posedge clk) begin
                if (ena) begin
                    if (s_aligned)
                        r_sum <= {{(WD_OUT-PSUM_W){psum0[PSUM_W-1]}}, psum0} + {{(WD_OUT-PSUM_W){psum1[PSUM_W-1]}}, psum1};
                    else
                        r_sum <= {{(WD_OUT-PSUM_W){1'b0}}, psum0} + {{(WD_OUT-PSUM_W){1'b0}}, psum1};
                end
            end

            assign sum = r_sum;
        end
    endgenerate
endmodule

// DC: set_ungroup [get_designs adderTree] true
