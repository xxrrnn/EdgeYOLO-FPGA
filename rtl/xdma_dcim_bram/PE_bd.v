`timescale 1ns / 1ps
`include "dcim_defs.vh"

// Verilog wrapper used only for Vivado IP Integrator module reference.
// IP Integrator rejects a SystemVerilog file as the referenced top module in
// this flow, so the BD instantiates PE_bd while synthesis still uses PE.sv.
module PE_bd (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         dcim_start,
    input  wire                         dcim_config_valid,
    output wire                         dcim_config_ready,
    output wire                         dcim_busy,
    output wire                         dcim_done,
    output wire                         dcim_error,
    output wire [31:0]                  dcim_error_code,

    input  wire [`DCIM_ADDR_WIDTH-1:0]       dcim_wsrc_base_addr,
    input  wire [`DCIM_ADDR_WIDTH-1:0]       dcim_asrc_base_addr,
    input  wire [`DCIM_ADDR_WIDTH-1:0]       dcim_dst_addr,
    input  wire [31:0]                       dcim_raw_rows,
    input  wire [2:0]                        dcim_mode,
    input  wire [4:0]                        dcim_acc,

    input  wire                              ibuf_ena,
    input  wire [`DCIM_BRAM_BYTES-1:0]          ibuf_wea,
    input  wire [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] ibuf_addra,
    input  wire [`DCIM_BRAM_DATA_WIDTH-1:0]     ibuf_dina,
    output wire [`DCIM_BRAM_DATA_WIDTH-1:0]     ibuf_douta,

    input  wire                                 obuf_ena,
    input  wire [`DCIM_BRAM_BYTES-1:0]          obuf_wea,
    input  wire [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] obuf_addra,
    input  wire [`DCIM_BRAM_DATA_WIDTH-1:0]     obuf_dina,
    output wire [`DCIM_BRAM_DATA_WIDTH-1:0]     obuf_douta
);
    wire [`DCIM_ADDR_WIDTH-1:0] ibuf_addra_ext =
        {{(`DCIM_ADDR_WIDTH-`DCIM_AXI_BRAM_ADDR_WIDTH){1'b0}}, ibuf_addra};
    wire [`DCIM_ADDR_WIDTH-1:0] obuf_addra_ext =
        {{(`DCIM_ADDR_WIDTH-`DCIM_AXI_BRAM_ADDR_WIDTH){1'b0}}, obuf_addra};

    PE u_pe (
        .clk(clk),
        .rst_n(rst_n),
        .dcim_start(dcim_start),
        .dcim_config_valid(dcim_config_valid),
        .dcim_config_ready(dcim_config_ready),
        .dcim_busy(dcim_busy),
        .dcim_done(dcim_done),
        .dcim_error(dcim_error),
        .dcim_error_code(dcim_error_code),
        .dcim_wsrc_base_addr(dcim_wsrc_base_addr),
        .dcim_asrc_base_addr(dcim_asrc_base_addr),
        .dcim_dst_addr(dcim_dst_addr),
        .dcim_raw_rows(dcim_raw_rows),
        .dcim_mode(dcim_mode),
        .dcim_acc(dcim_acc),
        .ibuf_ena(ibuf_ena),
        .ibuf_wea(ibuf_wea),
        .ibuf_addra(ibuf_addra_ext),
        .ibuf_dina(ibuf_dina),
        .ibuf_douta(ibuf_douta),
        .obuf_ena(obuf_ena),
        .obuf_wea(obuf_wea),
        .obuf_addra(obuf_addra_ext),
        .obuf_dina(obuf_dina),
        .obuf_douta(obuf_douta)
    );
endmodule
