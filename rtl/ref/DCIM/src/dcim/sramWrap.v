`timescale 1ns / 1ps

// ============================================================================
// sramWrap - SRAM 包装器
// ============================================================================
// 支持两种模式：
//   1. SIM/FPGA: 使用 model_rf_bram（Vivado 自动推断 BRAM）
//   2. ASIC: 使用 ASIC SRAM IP (rf_sp_hde128x128)
// ============================================================================

module sramWrap#(
	parameter WD = 128,
	parameter DP = 128,
	localparam ADDR_WD = $clog2(DP)
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	
	input  req,
	input  we,

	input  [ADDR_WD-1: 0] addr,
	input  [WD-1: 0] wdata,
	input  [WD-1: 0] be,
	output [WD-1: 0] rdata
);

`ifdef SIM
`define SRAMWRAP_BRAM_MODEL
`endif
`ifdef FPGA
`define SRAMWRAP_BRAM_MODEL
`endif

`ifdef SRAMWRAP_BRAM_MODEL
	// SIM / FPGA：BRAM 推断友好模型（仿真默认与 Vivado 推断行为一致）
	model_rf_bram#(
		.WIDTH(WD),
		.DEPTH(DP)
	) u_rf(
		.clk(clk),
		.cen(~(ena & req)),
		.gwen(~we),
		.wen(~be),
		.a(addr),
		.d(wdata),
		.q(rdata)
	);

`else
	// ========================================================================
	// ASIC 模式：使用 ASIC SRAM IP
	// ========================================================================
	rf_sp_hde128x128 u_rf(
		.clk(clk),
		.cen(~(ena & req)),
		.gwen(~we),
		.wen(~be),
		.a(addr),
		.d(wdata),
		.q(rdata),
		.ema(3'b111), .emaw(2'b11), .emas(1'b1),
		.wabl(1'b1), .wablm(2'b00),
		.rawl(1'b0), .rawlm(2'b00),
		.ret1n(1'b1)
	);
`endif

endmodule
