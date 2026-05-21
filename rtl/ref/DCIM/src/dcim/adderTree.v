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

// DC: set_ungroup [get_designs adderTree] true
