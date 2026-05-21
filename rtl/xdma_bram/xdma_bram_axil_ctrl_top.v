`timescale 1ns / 1ps

// xdma_bram_axil_ctrl_top
//
// Purpose:
//   This module is an AXI-Lite controlled BRAM processing engine. The CPU does
//   not send payload data through AXI-Lite. Instead, the CPU writes payload data
//   into BRAM through XDMA h2c/c2h memory-mapped DMA, then uses AXI-Lite
//   registers to tell this module which BRAM region to read, which BRAM region
//   to write, how many bytes to process, and which simple operation to apply.
//
// Expected system connection:
//   CPU/PCIe XDMA M_AXI      <-> SmartConnect <-> AXI BRAM controller <-> BRAM port A
//   CPU/PCIe XDMA M_AXI      <-> SmartConnect <-> this module s_axil
//   this module BRAM port    <-> BRAM port B
//
// The module keeps an AXI-Lite register interface, but the XDMA IP should not
// enable its separate AXI-Lite master BAR in this project. Keeping XDMA on its
// standard DMA BAR layout avoids Windows driver start failures caused by moving
// the XDMA control BAR. SmartConnect performs the AXI4-to-AXI-Lite conversion
// for accesses to this register window.
//
// Register map:
//   0x00 CTRL        W  bit0=1 starts one processing run.
//   0x04 STATUS      R  bit0=busy, bit1=done, bit2=error.
//   0x08 SRC_ADDR    RW Input BRAM byte offset.
//   0x0C DST_ADDR    RW Output BRAM byte offset.
//   0x10 LEN_BYTES   RW Number of bytes to process.
//   0x14 OP          RW Operation selector.
//   0x18 OP_ARG      RW 32-bit argument used by xor32/add32.
//   0x1C WORDS_DONE  R  Number of BRAM words processed.
//   0x20 VERSION     R  Fixed value 0x58424101.
//
// Data operation:
//   The BRAM word is BRAM_DATA_WIDTH bits. With the default 256-bit BRAM word,
//   each access contains eight 32-bit lanes. The operation is applied to every
//   32-bit lane independently:
//     OP=0: output_lane = input_lane
//     OP=1: output_lane = input_lane ^ OP_ARG
//     OP=2: output_lane = input_lane + OP_ARG
//     OP=3: output_lane = ~input_lane
//
// CPU-side test flow:
//   1. Write input bytes into BRAM at SRC_ADDR through XDMA h2c DMA.
//   2. Program SRC_ADDR, DST_ADDR, LEN_BYTES, OP, and OP_ARG through AXI-Lite.
//   3. Write CTRL[0]=1 through AXI-Lite.
//   4. Poll STATUS.done through AXI-Lite.
//   5. Read output bytes from DST_ADDR through XDMA c2h DMA.
//   6. Compare the output with a CPU-side golden model.
//
// Alignment and range:
//   SRC_ADDR, DST_ADDR, and LEN_BYTES are byte offsets and must be aligned to
//   one BRAM word. With the default 256-bit BRAM word, that is 32-byte
//   alignment. The register interface and blk_mem_gen native BRAM port in this
//   block design both use byte-style offsets, matching the AXI BRAM controller
//   BRAM_ADDR signal. BRAM_ADDR_WIDTH matches the 32-bit native address pin
//   inferred by Vivado for blk_mem_gen in block design. BRAM_SIZE_ADDR_WIDTH
//   keeps the usable range at 8KB.

module xdma_bram_axil_ctrl_top #(
    parameter integer AXIL_ADDR_WIDTH = 12,
    parameter integer AXIL_DATA_WIDTH = 32,
    parameter integer BRAM_ADDR_WIDTH = 32,
    parameter integer BRAM_SIZE_ADDR_WIDTH = 13,
    parameter integer BRAM_DATA_WIDTH = 256
) (
    input  wire                         aclk,
    input  wire                         aresetn,

    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_awaddr,
    input  wire                         s_axil_awvalid,
    output reg                          s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    input  wire [(AXIL_DATA_WIDTH/8)-1:0] s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output reg                          s_axil_wready,
    output reg  [1:0]                   s_axil_bresp,
    output reg                          s_axil_bvalid,
    input  wire                         s_axil_bready,

    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  wire                         s_axil_arvalid,
    output reg                          s_axil_arready,
    output reg  [AXIL_DATA_WIDTH-1:0]   s_axil_rdata,
    output reg  [1:0]                   s_axil_rresp,
    output reg                          s_axil_rvalid,
    input  wire                         s_axil_rready,

    output reg                          bram_en,
    output reg  [(BRAM_DATA_WIDTH/8)-1:0] bram_we,
    output reg  [BRAM_ADDR_WIDTH-1:0]   bram_addr,
    output reg  [BRAM_DATA_WIDTH-1:0]   bram_din,
    input  wire [BRAM_DATA_WIDTH-1:0]   bram_dout
);

    localparam integer BRAM_STRB_WIDTH = BRAM_DATA_WIDTH / 8;
    localparam integer WORD_BYTES = BRAM_DATA_WIDTH / 8;
    localparam integer WORD_ADDR_SHIFT = $clog2(WORD_BYTES);
    localparam integer LANES32 = BRAM_DATA_WIDTH / 32;
    localparam [31:0] BRAM_SIZE_BYTES = (32'd1 << BRAM_SIZE_ADDR_WIDTH);

    localparam [AXIL_ADDR_WIDTH-1:0] REG_CTRL       = 12'h000;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_STATUS     = 12'h004;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_SRC_ADDR   = 12'h008;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_DST_ADDR   = 12'h00C;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_LEN_BYTES  = 12'h010;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_OP         = 12'h014;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_OP_ARG     = 12'h018;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_WORDS_DONE = 12'h01C;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_VERSION    = 12'h020;

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_READ_ISSUE = 3'd1;
    localparam [2:0] ST_READ_WAIT0 = 3'd2;
    localparam [2:0] ST_READ_WAIT1 = 3'd3;
    localparam [2:0] ST_WRITE      = 3'd4;

    reg [2:0] state;
    reg [31:0] src_addr_reg;
    reg [31:0] dst_addr_reg;
    reg [31:0] len_bytes_reg;
    reg [31:0] op_reg;
    reg [31:0] op_arg_reg;
    reg [31:0] words_done_reg;
    reg [31:0] total_words_reg;
    reg [31:0] src_addr_cur;
    reg [31:0] dst_addr_cur;
    reg done_reg;
    reg error_reg;
    reg start_pulse;
    reg [AXIL_ADDR_WIDTH-1:0] awaddr_reg;
    reg awaddr_valid_reg;
    reg [AXIL_DATA_WIDTH-1:0] wdata_reg;
    reg [(AXIL_DATA_WIDTH/8)-1:0] wstrb_reg;
    reg wdata_valid_reg;

    wire busy = (state != ST_IDLE);
    wire config_writable = (state == ST_IDLE);

    function [BRAM_DATA_WIDTH-1:0] process_word;
        input [BRAM_DATA_WIDTH-1:0] din;
        input [31:0] op;
        input [31:0] arg;
        integer k;
        reg [31:0] in_lane;
        reg [BRAM_DATA_WIDTH-1:0] tmp;
        begin
            tmp = {BRAM_DATA_WIDTH{1'b0}};
            for (k = 0; k < LANES32; k = k + 1) begin
                in_lane = din[k*32 +: 32];
                case (op[1:0])
                    2'd0: tmp[k*32 +: 32] = in_lane;
                    2'd1: tmp[k*32 +: 32] = in_lane ^ arg;
                    2'd2: tmp[k*32 +: 32] = in_lane + arg;
                    2'd3: tmp[k*32 +: 32] = ~in_lane;
                    default: tmp[k*32 +: 32] = in_lane;
                endcase
            end
            process_word = tmp;
        end
    endfunction

    function [31:0] apply_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  wstrb;
        integer b;
        begin
            apply_wstrb = old_value;
            for (b = 0; b < 4; b = b + 1) begin
                if (wstrb[b]) begin
                    apply_wstrb[b*8 +: 8] = new_value[b*8 +: 8];
                end
            end
        end
    endfunction

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axil_awready <= 1'b0;
            s_axil_wready <= 1'b0;
            s_axil_bresp <= 2'b00;
            s_axil_bvalid <= 1'b0;
            s_axil_arready <= 1'b0;
            s_axil_rdata <= 32'd0;
            s_axil_rresp <= 2'b00;
            s_axil_rvalid <= 1'b0;
            src_addr_reg <= 32'd0;
            dst_addr_reg <= 32'd0;
            len_bytes_reg <= 32'd0;
            op_reg <= 32'd0;
            op_arg_reg <= 32'd1;
            start_pulse <= 1'b0;
            awaddr_reg <= {AXIL_ADDR_WIDTH{1'b0}};
            awaddr_valid_reg <= 1'b0;
            wdata_reg <= {AXIL_DATA_WIDTH{1'b0}};
            wstrb_reg <= {(AXIL_DATA_WIDTH/8){1'b0}};
            wdata_valid_reg <= 1'b0;
        end else begin
            s_axil_awready <= 1'b0;
            s_axil_wready <= 1'b0;
            s_axil_arready <= 1'b0;
            start_pulse <= 1'b0;

            if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end

            if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end

            if (!awaddr_valid_reg && !s_axil_bvalid && s_axil_awvalid) begin
                s_axil_awready <= 1'b1;
                awaddr_reg <= s_axil_awaddr;
                awaddr_valid_reg <= 1'b1;
            end

            if (!wdata_valid_reg && !s_axil_bvalid && s_axil_wvalid) begin
                s_axil_wready <= 1'b1;
                wdata_reg <= s_axil_wdata;
                wstrb_reg <= s_axil_wstrb;
                wdata_valid_reg <= 1'b1;
            end

            if (awaddr_valid_reg && wdata_valid_reg && !s_axil_bvalid) begin
                s_axil_bvalid <= 1'b1;
                s_axil_bresp <= 2'b00;
                awaddr_valid_reg <= 1'b0;
                wdata_valid_reg <= 1'b0;

                case (awaddr_reg)
                    REG_CTRL: begin
                        if (wdata_reg[0]) begin
                            start_pulse <= 1'b1;
                        end
                    end
                    REG_SRC_ADDR: begin
                        if (config_writable) begin
                            src_addr_reg <= apply_wstrb(src_addr_reg, wdata_reg, wstrb_reg);
                        end
                    end
                    REG_DST_ADDR: begin
                        if (config_writable) begin
                            dst_addr_reg <= apply_wstrb(dst_addr_reg, wdata_reg, wstrb_reg);
                        end
                    end
                    REG_LEN_BYTES: begin
                        if (config_writable) begin
                            len_bytes_reg <= apply_wstrb(len_bytes_reg, wdata_reg, wstrb_reg);
                        end
                    end
                    REG_OP: begin
                        if (config_writable) begin
                            op_reg <= apply_wstrb(op_reg, wdata_reg, wstrb_reg);
                        end
                    end
                    REG_OP_ARG: begin
                        if (config_writable) begin
                            op_arg_reg <= apply_wstrb(op_arg_reg, wdata_reg, wstrb_reg);
                        end
                    end
                    default: begin
                    end
                endcase
            end

            if (!s_axil_rvalid && s_axil_arvalid) begin
                s_axil_arready <= 1'b1;
                s_axil_rvalid <= 1'b1;
                s_axil_rresp <= 2'b00;
                case (s_axil_araddr)
                    REG_CTRL:       s_axil_rdata <= 32'd0;
                    REG_STATUS:     s_axil_rdata <= {29'd0, error_reg, done_reg, busy};
                    REG_SRC_ADDR:   s_axil_rdata <= src_addr_reg;
                    REG_DST_ADDR:   s_axil_rdata <= dst_addr_reg;
                    REG_LEN_BYTES:  s_axil_rdata <= len_bytes_reg;
                    REG_OP:         s_axil_rdata <= op_reg;
                    REG_OP_ARG:     s_axil_rdata <= op_arg_reg;
                    REG_WORDS_DONE: s_axil_rdata <= words_done_reg;
                    REG_VERSION:    s_axil_rdata <= 32'h58424101;
                    default:        s_axil_rdata <= 32'd0;
                endcase
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            state <= ST_IDLE;
            bram_en <= 1'b0;
            bram_we <= {BRAM_STRB_WIDTH{1'b0}};
            bram_addr <= {BRAM_ADDR_WIDTH{1'b0}};
            bram_din <= {BRAM_DATA_WIDTH{1'b0}};
            words_done_reg <= 32'd0;
            total_words_reg <= 32'd0;
            src_addr_cur <= 32'd0;
            dst_addr_cur <= 32'd0;
            done_reg <= 1'b0;
            error_reg <= 1'b0;
        end else begin
            bram_en <= 1'b0;
            bram_we <= {BRAM_STRB_WIDTH{1'b0}};

            case (state)
                ST_IDLE: begin
                    if (start_pulse) begin
                        done_reg <= 1'b0;
                        error_reg <= 1'b0;
                        words_done_reg <= 32'd0;
                        total_words_reg <= len_bytes_reg >> WORD_ADDR_SHIFT;
                        src_addr_cur <= src_addr_reg;
                        dst_addr_cur <= dst_addr_reg;

                        if ((len_bytes_reg == 32'd0) ||
                            (len_bytes_reg[WORD_ADDR_SHIFT-1:0] != {WORD_ADDR_SHIFT{1'b0}}) ||
                            (src_addr_reg[WORD_ADDR_SHIFT-1:0] != {WORD_ADDR_SHIFT{1'b0}}) ||
                            (dst_addr_reg[WORD_ADDR_SHIFT-1:0] != {WORD_ADDR_SHIFT{1'b0}}) ||
                            ((src_addr_reg + len_bytes_reg) > BRAM_SIZE_BYTES) ||
                            ((dst_addr_reg + len_bytes_reg) > BRAM_SIZE_BYTES)) begin
                            error_reg <= 1'b1;
                            done_reg <= 1'b1;
                            state <= ST_IDLE;
                        end else begin
                            state <= ST_READ_ISSUE;
                        end
                    end
                end

                ST_READ_ISSUE: begin
                    bram_en <= 1'b1;
                    bram_addr <= src_addr_cur[BRAM_ADDR_WIDTH-1:0];
                    state <= ST_READ_WAIT0;
                end

                ST_READ_WAIT0: begin
                    bram_en <= 1'b1;
                    bram_addr <= src_addr_cur[BRAM_ADDR_WIDTH-1:0];
                    state <= ST_READ_WAIT1;
                end

                ST_READ_WAIT1: begin
                    bram_en <= 1'b1;
                    bram_addr <= src_addr_cur[BRAM_ADDR_WIDTH-1:0];
                    state <= ST_WRITE;
                end

                ST_WRITE: begin
                    bram_en <= 1'b1;
                    bram_we <= {BRAM_STRB_WIDTH{1'b1}};
                    bram_addr <= dst_addr_cur[BRAM_ADDR_WIDTH-1:0];
                    bram_din <= process_word(bram_dout, op_reg, op_arg_reg);
                    words_done_reg <= words_done_reg + 1'b1;
                    src_addr_cur <= src_addr_cur + WORD_BYTES;
                    dst_addr_cur <= dst_addr_cur + WORD_BYTES;

                    if ((words_done_reg + 1'b1) >= total_words_reg) begin
                        done_reg <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        state <= ST_READ_ISSUE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
