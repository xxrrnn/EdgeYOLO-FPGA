`timescale 1ns / 1ps
`include "dcim_defs.vh"

// PE wraps the DCIM compute macro with one input buffer and one output buffer.
// Port A of each buffer is left for the system side, for example an AXI BRAM
// controller connected to XDMA/CDMA in block design.  Port B is private to the
// DCIM_Macro.  Keeping these buffers inside RTL avoids a noisy block design
// with all DCIM internal handshake and preprocessing signals exposed.
module PE (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         dcim_start,
    input  logic                         dcim_config_valid,
    output logic                         dcim_config_ready,
    output logic                         dcim_busy,
    output logic                         dcim_done,
    output logic                         dcim_error,
    output logic [31:0]                  dcim_error_code,

    input  logic [`DCIM_ADDR_WIDTH-1:0]        dcim_wsrc_base_addr,
    input  logic [`DCIM_ADDR_WIDTH-1:0]        dcim_asrc_base_addr,
    input  logic [`DCIM_ADDR_WIDTH-1:0]        dcim_dst_addr,
    input  logic [31:0]                  dcim_raw_rows,
    input  logic [2:0]                   dcim_mode,
    input  logic [4:0]                   dcim_acc,
    input  logic [1:0]                   dcim_accumulate_type,

    // System-side IBUF port.  Address is a byte address from AXI BRAM
    // controller; PE converts it to an internal 256-bit word address.
    input  logic                         ibuf_ena,
    input  logic [`DCIM_BRAM_BYTES-1:0]        ibuf_wea,
    input  logic [`DCIM_ADDR_WIDTH-1:0]         ibuf_addra,
    input  logic [`DCIM_BRAM_DATA_WIDTH-1:0]   ibuf_dina,
    output logic [`DCIM_BRAM_DATA_WIDTH-1:0]   ibuf_douta,

    // System-side OBUF port.  Address is a byte address from AXI BRAM
    // controller; PE converts it to an internal 256-bit word address.
    input  logic                         obuf_ena,
    input  logic [`DCIM_BRAM_BYTES-1:0]        obuf_wea,
    input  logic [`DCIM_ADDR_WIDTH-1:0]         obuf_addra,
    input  logic [`DCIM_BRAM_DATA_WIDTH-1:0]   obuf_dina,
    output logic [`DCIM_BRAM_DATA_WIDTH-1:0]   obuf_douta
);
    localparam int BRAM_BYTES = `DCIM_BRAM_BYTES;
    localparam int BRAM_ADDR_SHIFT = $clog2(BRAM_BYTES);

    logic                         ibuf_enb;
    logic [`DCIM_IBUF_ADDR_WIDTH-1:0]   ibuf_addrb;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0]   ibuf_doutb;

    logic                         obuf_enb;
    logic [BRAM_BYTES-1:0]        obuf_web;
    logic [`DCIM_OBUF_ADDR_WIDTH-1:0]   obuf_addrb;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0]   obuf_dinb;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0]   obuf_doutb;
    logic [`DCIM_IBUF_ADDR_WIDTH-1:0]   ibuf_word_addra;
    logic [`DCIM_OBUF_ADDR_WIDTH-1:0]   obuf_word_addra;

    assign ibuf_word_addra = ibuf_addra[BRAM_ADDR_SHIFT +: `DCIM_IBUF_ADDR_WIDTH];
    assign obuf_word_addra = obuf_addra[BRAM_ADDR_SHIFT +: `DCIM_OBUF_ADDR_WIDTH];

    DCIM_Macro u_dcim_macro (
        .clk(clk),
        .rst_n(rst_n),
        .dcim_start(dcim_start),
        .dcim_config_valid(dcim_config_valid),
        .dcim_config_ready(dcim_config_ready),
        .dcim_busy(dcim_busy),
        .dcim_done(dcim_done),
        .dcim_error(dcim_error),
        .dcim_error_code(dcim_error_code),
        .wsrc_base_addr(dcim_wsrc_base_addr),
        .asrc_base_addr(dcim_asrc_base_addr),
        .dst_addr(dcim_dst_addr),
        .raw_rows(dcim_raw_rows),
        .mode(dcim_mode),
        .acc(dcim_acc),
        .accumulate_type(dcim_accumulate_type),
        .ibuf_enb(ibuf_enb),
        .ibuf_addrb(ibuf_addrb),
        .ibuf_doutb(ibuf_doutb),
        .obuf_enb(obuf_enb),
        .obuf_web(obuf_web),
        .obuf_addrb(obuf_addrb),
        .obuf_dinb(obuf_dinb),
        .obuf_doutb(obuf_doutb)
    );

    dcim_tdp_byte_ram #(
        .ADDR_WIDTH(`DCIM_IBUF_ADDR_WIDTH),
        .DATA_WIDTH(`DCIM_BRAM_DATA_WIDTH)
    ) u_ibuf (
        .clk(clk),
        .ena(ibuf_ena),
        .wea(ibuf_wea),
        .addra(ibuf_word_addra),
        .dina(ibuf_dina),
        .douta(ibuf_douta),
        .enb(ibuf_enb),
        .web({BRAM_BYTES{1'b0}}),
        .addrb(ibuf_addrb),
        .dinb({`DCIM_BRAM_DATA_WIDTH{1'b0}}),
        .doutb(ibuf_doutb)
    );

    dcim_tdp_byte_ram #(
        .ADDR_WIDTH(`DCIM_OBUF_ADDR_WIDTH),
        .DATA_WIDTH(`DCIM_BRAM_DATA_WIDTH)
    ) u_obuf (
        .clk(clk),
        .ena(obuf_ena),
        .wea(obuf_wea),
        .addra(obuf_word_addra),
        .dina(obuf_dina),
        .douta(obuf_douta),
        .enb(obuf_enb),
        .web(obuf_web),
        .addrb(obuf_addrb),
        .dinb(obuf_dinb),
        .doutb(obuf_doutb)
    );
endmodule

// Inferred true-dual-port RAM with byte write enables and synchronous reads.
// Vivado maps this style to BRAM for the default 256-bit widths.  Use one clock
// so the system and DCIM sides are coherent without CDC inside the PE.
module dcim_tdp_byte_ram #(
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 256
) (
    input  logic                         clk,
    input  logic                         ena,
    input  logic [DATA_WIDTH/8-1:0]      wea,
    input  logic [ADDR_WIDTH-1:0]        addra,
    input  logic [DATA_WIDTH-1:0]        dina,
    output logic [DATA_WIDTH-1:0]        douta,
    input  logic                         enb,
    input  logic [DATA_WIDTH/8-1:0]      web,
    input  logic [ADDR_WIDTH-1:0]        addrb,
    input  logic [DATA_WIDTH-1:0]        dinb,
    output logic [DATA_WIDTH-1:0]        doutb
);
    localparam int BYTE_NUM = DATA_WIDTH / 8;
    localparam int DEPTH    = 1 << ADDR_WIDTH;

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (ena) begin
            for (int b = 0; b < BYTE_NUM; b++) begin
                if (wea[b]) begin
                    mem[addra][8*b +: 8] <= dina[8*b +: 8];
                end
            end
            douta <= mem[addra];
        end
    end

    always_ff @(posedge clk) begin
        if (enb) begin
            for (int b = 0; b < BYTE_NUM; b++) begin
                if (web[b]) begin
                    mem[addrb][8*b +: 8] <= dinb[8*b +: 8];
                end
            end
            doutb <= mem[addrb];
        end
    end
endmodule
