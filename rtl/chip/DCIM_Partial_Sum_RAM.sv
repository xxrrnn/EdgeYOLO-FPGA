`timescale 1ns / 1ns

// 64-context, 512-bit partial-sum store for one Tile.
//
// Port A is a pipelined synchronous read and Port B is an independent write.
// The width is deliberately implemented in block RAM, not FF/LUTRAM: on the
// target VU37P this costs about eight RAMB36 per Tile and avoids adding pressure
// to the already dense CLB/DSP regions.
module DCIM_Partial_Sum_RAM #(
    parameter DATA_WIDTH = 512,
    parameter DEPTH      = 64,
    localparam ADDR_W    = $clog2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  rd_en,
    input  wire [ADDR_W-1:0]     rd_addr,
    output reg                   rd_valid,
    output reg [DATA_WIDTH-1:0]  rd_data,
    input  wire                  wr_en,
    input  wire [ADDR_W-1:0]     wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] rd_data_q;
    reg rd_valid_q;

    // Read port with an explicit output pipeline register.  Total read latency
    // is two clocks, which keeps the subsequent 32/64-bit adders local.
    always_ff @(posedge clk) begin
        rd_valid_q <= rd_en;
        rd_valid <= rd_valid_q;
        if (rd_en)
            rd_data_q <= mem[rd_addr];
        if (rd_valid_q)
            rd_data <= rd_data_q;
    end

    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

endmodule
