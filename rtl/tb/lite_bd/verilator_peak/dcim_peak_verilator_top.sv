`timescale 1ns / 1ns
`include "chip_defines.vh"

// Local simulation wrapper for the synthesizable DCIM array.  It deliberately
// stays outside rtl/chip: the production RTL and its Vivado configuration are
// not changed by this test.
module dcim_peak_verilator_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,

    input  wire         load_en,
    input  wire [2:0]   load_tile,
    input  wire [14:0]  load_addr,
    input  wire [127:0] load_data,

    input  wire         read_en,
    input  wire [2:0]   read_tile,
    input  wire [13:0]  read_addr,
    output wire [127:0] read_data,
    output wire         read_valid,

    output wire         done,
    output wire         ready,
    output wire [7:0]   compute_fire
);
    localparam integer NUM_TILES = 8;
    localparam integer STRB_WIDTH = 16;
    localparam [14:0] WEIGHT_BASE_WORD = 15'h4000;

    wire [NUM_TILES*STRB_WIDTH-1:0] ibuf_wea;
    wire [NUM_TILES-1:0] ibuf_ena;
    wire [NUM_TILES*15-1:0] ibuf_addra = {NUM_TILES{load_addr}};
    wire [NUM_TILES*128-1:0] ibuf_dina = {NUM_TILES{load_data}};
    wire [NUM_TILES*128-1:0] ibuf_douta;

    wire [NUM_TILES*STRB_WIDTH-1:0] obuf_wea = '0;
    wire [NUM_TILES-1:0] obuf_ena;
    wire [NUM_TILES*14-1:0] obuf_addra = {NUM_TILES{read_addr}};
    wire [NUM_TILES*128-1:0] obuf_dina = '0;
    wire [NUM_TILES*128-1:0] obuf_douta;
    wire [NUM_TILES-1:0] obuf_douta_valid;

    wire [NUM_TILES*15-1:0] wei_base_addrs = {NUM_TILES{WEIGHT_BASE_WORD}};
    wire [NUM_TILES*14-1:0] out_base_addrs = '0;

    genvar tile_i;
    generate
        for (tile_i = 0; tile_i < NUM_TILES; tile_i = tile_i + 1) begin : gen_host_mux
            assign ibuf_ena[tile_i] = load_en && (load_tile == tile_i[2:0]);
            assign ibuf_wea[tile_i*STRB_WIDTH +: STRB_WIDTH] =
                ibuf_ena[tile_i] ? {STRB_WIDTH{1'b1}} : {STRB_WIDTH{1'b0}};
            assign obuf_ena[tile_i] = read_en && (read_tile == tile_i[2:0]);
        end
    endgenerate

    assign read_data = obuf_douta[read_tile*128 +: 128];
    assign read_valid = obuf_douta_valid[read_tile];

    DCIM_Array dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .ready(ready),
        .mode(`MODE_INT8),
        .acc_depth(7'd8),
        .act_base_addr(15'd0),
        .wei_base_addrs(wei_base_addrs),
        .out_base_addrs(out_base_addrs),
        .tile_mask(8'hff),
        .tile_ibuf_ext_wea(ibuf_wea),
        .tile_ibuf_ext_ena(ibuf_ena),
        .tile_ibuf_ext_addra(ibuf_addra),
        .tile_ibuf_ext_dina(ibuf_dina),
        .tile_ibuf_ext_douta(ibuf_douta),
        .tile_obuf_ext_wea(obuf_wea),
        .tile_obuf_ext_ena(obuf_ena),
        .tile_obuf_ext_addra(obuf_addra),
        .tile_obuf_ext_dina(obuf_dina),
        .tile_obuf_ext_douta(obuf_douta),
        .tile_obuf_ext_douta_valid(obuf_douta_valid)
    );

    generate
        for (tile_i = 0; tile_i < NUM_TILES; tile_i = tile_i + 1) begin : gen_compute_probe
            assign compute_fire[tile_i] = dut.gen_tiles[tile_i].u_tile.compute_phase_fire;
        end
    endgenerate
endmodule
