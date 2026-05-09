`timescale 1ns / 1ps
`include "dcim_defs.vh"

// DCIM_Macro is a small matrix tile engine around the original DCIM
// calculate_core/postProcess pipeline in rtl/ref/DCIM.
//
// Buffer layout:
//   * weight tile at wsrc_base_addr: raw int8 B[16 x 8], row-major, 128 bytes.
//   * activation rows at asrc_base_addr: raw int8 A[raw_rows x 16].
//     Each row is 16 bytes.  Two raw rows are packed into one 256-bit ibuf word:
//     row 2*n in bits [127:0], row 2*n+1 in bits [255:128].
//   * result rows at dst_addr: one 256-bit row per postProcess output.
//
// Timing note:
//   Address generation and validation are deliberately sequential.  Do not put
//   variable divide or modulo on the start-to-state path; the previous
//   controller failed timing mainly because of rows/acc and rows%acc logic.
module DCIM_Macro (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         dcim_start,
    input  logic                         dcim_config_valid,
    output logic                         dcim_config_ready,
    output logic                         dcim_busy,
    output logic                         dcim_done,
    output logic                         dcim_error,
    output logic [31:0]                  dcim_error_code,

    // Byte addresses inside PE ibuf/obuf.  They must be 32-byte aligned.
    input  logic [`DCIM_ADDR_WIDTH-1:0]        wsrc_base_addr,
    input  logic [`DCIM_ADDR_WIDTH-1:0]        asrc_base_addr,
    input  logic [`DCIM_ADDR_WIDTH-1:0]        dst_addr,

    // raw_rows is the number of host-visible int8 activation rows in ibuf.
    // The macro internally sends two 4-bit DCIM rows per int8 activation row.
    input  logic [31:0]                  raw_rows,
    input  logic [2:0]                   mode,
    input  logic [4:0]                   acc,
    input  logic [1:0]                   accumulate_type,

    // IBUF port B: read-only port used by this macro.
    output logic                         ibuf_enb,
    output logic [`DCIM_IBUF_ADDR_WIDTH-1:0]   ibuf_addrb,
    input  logic [`DCIM_BRAM_DATA_WIDTH-1:0]   ibuf_doutb,

    // OBUF port B: write-only result port used by this macro.
    output logic                         obuf_enb,
    output logic [`DCIM_BRAM_BYTES-1:0]        obuf_web,
    output logic [`DCIM_OBUF_ADDR_WIDTH-1:0]   obuf_addrb,
    output logic [`DCIM_BRAM_DATA_WIDTH-1:0]   obuf_dinb,
    input  logic [`DCIM_BRAM_DATA_WIDTH-1:0]   obuf_doutb
);
    localparam logic [2:0] MODE_INT8  = `DCIM_MODE_INT8;
    localparam logic [2:0] MODE_INT16 = `DCIM_MODE_INT16;
    localparam int BRAM_BYTES        = `DCIM_BRAM_BYTES;
    localparam int BRAM_ADDR_SHIFT   = $clog2(BRAM_BYTES);
    localparam int WD2               = `DCIM_WD2;
    localparam int WD3               = `DCIM_WD3;
    localparam int DCIM_ACT_WIDTH    = `DCIM_ACT_WIDTH;
    localparam int DCIM_TILE_WIDTH   = `DCIM_TILE_WIDTH;
    localparam int DCIM_RES_WIDTH    = `DCIM_RES_WIDTH;
    localparam logic [32:0] IBUF_DEPTH_WORDS = (33'd1 << `DCIM_IBUF_ADDR_WIDTH);
    localparam logic [32:0] OBUF_DEPTH_WORDS = (33'd1 << `DCIM_OBUF_ADDR_WIDTH);

    initial begin
        if (`DCIM_BRAM_DATA_WIDTH != 256) begin
            $fatal(1, "DCIM_Macro currently expects 256-bit ibuf/obuf words");
        end
        if (`DCIM_CH_IN != 16 || `DCIM_CH_OUT != 16 || `DCIM_WD1 != 4) begin
            $fatal(1, "DCIM_Macro int8 packing expects WD1=4, CH_IN=16, CH_OUT=16");
        end
        if (DCIM_RES_WIDTH > `DCIM_BRAM_DATA_WIDTH) begin
            $fatal(1, "DCIM result row width (%0d) exceeds BRAM word width (%0d)",
                   DCIM_RES_WIDTH, `DCIM_BRAM_DATA_WIDTH);
        end
    end

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_VALIDATE,
        ST_LOAD_W_REQ,
        ST_LOAD_W_WAIT0,
        ST_LOAD_W_WAIT1,
        ST_PREP_W,
        ST_CLEAR,
        ST_ACT_NEXT,
        ST_ACT_REQ,
        ST_ACT_WAIT0,
        ST_ACT_WAIT1,
        ST_ACT_LAUNCH,
        ST_ACT_SEND_HI,
        ST_ACT_SEND_MID1,
        ST_ACT_SEND_MID2,
        ST_ACT_SEND_LO,
        ST_DRAIN,
        ST_DONE,
        ST_ERROR
    } state_t;

    (* fsm_encoding = "auto" *) state_t state;

    logic [`DCIM_ADDR_WIDTH-1:0] wsrc_base_addr_reg;
    logic [`DCIM_ADDR_WIDTH-1:0] asrc_base_addr_reg;
    logic [`DCIM_ADDR_WIDTH-1:0] dst_addr_reg;
    logic [31:0]           raw_rows_reg;
    logic [2:0]            mode_reg;
    logic [4:0]            acc_reg;
    logic [1:0]            accumulate_type_reg;

    logic [31:0] expected_out_rows_reg;
    logic [31:0] rows_sent_reg;
    logic [31:0] rows_out_reg;
    logic [1:0]  w_word_idx;
    logic        act_row_sel;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0] raw_act_word_reg;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0] raw_weight_reg0;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0] raw_weight_reg1;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0] raw_weight_reg2;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0] raw_weight_reg3;
    wire [DCIM_TILE_WIDTH-1:0] raw_weight_reg;
    assign raw_weight_reg = {raw_weight_reg3, raw_weight_reg2, raw_weight_reg1, raw_weight_reg0};
    logic [DCIM_TILE_WIDTH-1:0] dcim_weight_reg;

    logic validate_error;
    logic [31:0] validate_error_code;
    logic [31:0] validate_out_rows;
    logic [32:0] validate_w_word_base;
    logic [32:0] validate_a_word_base;
    logic [32:0] validate_dst_word_base;
    logic [32:0] validate_act_words;
    logic [32:0] validate_weight_end_words;
    logic [32:0] validate_act_end_words;
    logic [32:0] validate_out_end_words;
    logic [`DCIM_OBUF_ADDR_WIDTH-1:0] pending_dst_addr_reg;
    logic [DCIM_RES_WIDTH-1:0] pending_res_data_reg;
    logic pending_accum_wait_reg;
    logic pending_accum_merge_reg;

    // Supported int8 accumulation factors.  acc==0 means postProcess bypasses
    // accumulation.  acc==1 is legal and produces the same output row count as
    // bypass, but still exercises the accumulator.  No variable divide/modulo:
    // only powers of two are accepted, so output rows are computed by shifts and
    // row alignment is checked by masks.
    always_comb begin
        validate_error      = 1'b0;
        validate_error_code = 32'd0;
        validate_out_rows   = 32'd0;
        validate_w_word_base = ({1'b0, wsrc_base_addr_reg} >> BRAM_ADDR_SHIFT);
        validate_a_word_base = ({1'b0, asrc_base_addr_reg} >> BRAM_ADDR_SHIFT);
        validate_dst_word_base = ({1'b0, dst_addr_reg} >> BRAM_ADDR_SHIFT);
        validate_act_words = mode_reg == MODE_INT16 ? {1'b0, raw_rows_reg}
                                                    : (({1'b0, raw_rows_reg} + 33'd1) >> 1);
        validate_weight_end_words = validate_w_word_base + 33'd4;
        validate_act_end_words = validate_a_word_base + validate_act_words;
        validate_out_end_words = validate_dst_word_base;

        if ((mode_reg != MODE_INT8) && (mode_reg != MODE_INT16)) begin
            validate_error      = 1'b1;
            validate_error_code = 32'h0000_0001;
        end else if (raw_rows_reg == 32'd0) begin
            validate_error      = 1'b1;
            validate_error_code = 32'h0000_0002;
        end else if (|wsrc_base_addr_reg[BRAM_ADDR_SHIFT-1:0] ||
                     |asrc_base_addr_reg[BRAM_ADDR_SHIFT-1:0] ||
                     |dst_addr_reg[BRAM_ADDR_SHIFT-1:0]) begin
            validate_error      = 1'b1;
            validate_error_code = 32'h0000_0003;
        end else begin
            unique case (acc_reg)
                5'd0, 5'd1: begin
                    validate_out_rows = raw_rows_reg;
                end
                5'd2: begin
                    validate_out_rows = raw_rows_reg >> 1;
                    if (raw_rows_reg[0]) begin
                        validate_error      = 1'b1;
                        validate_error_code = 32'h0000_0004;
                    end
                end
                5'd4: begin
                    validate_out_rows = raw_rows_reg >> 2;
                    if (|raw_rows_reg[1:0]) begin
                        validate_error      = 1'b1;
                        validate_error_code = 32'h0000_0004;
                    end
                end
                5'd8: begin
                    validate_out_rows = raw_rows_reg >> 3;
                    if (|raw_rows_reg[2:0]) begin
                        validate_error      = 1'b1;
                        validate_error_code = 32'h0000_0004;
                    end
                end
                5'd16: begin
                    validate_out_rows = raw_rows_reg >> 4;
                    if (|raw_rows_reg[3:0]) begin
                        validate_error      = 1'b1;
                        validate_error_code = 32'h0000_0004;
                    end
                end
                default: begin
                    validate_error      = 1'b1;
                    validate_error_code = 32'h0000_0005;
                end
            endcase

            if (!validate_error && (accumulate_type_reg > 2'd1)) begin
                validate_error      = 1'b1;
                validate_error_code = 32'h0000_0007;
            end

            validate_out_end_words = validate_dst_word_base + {1'b0, validate_out_rows};
            if (!validate_error &&
                ((validate_weight_end_words > IBUF_DEPTH_WORDS) ||
                 (validate_act_end_words > IBUF_DEPTH_WORDS) ||
                 (validate_out_end_words > OBUF_DEPTH_WORDS))) begin
                validate_error      = 1'b1;
                validate_error_code = 32'h0000_0006;
            end
        end
    end

    logic [DCIM_TILE_WIDTH-1:0] preprocessed_weight;
    logic [DCIM_ACT_WIDTH-1:0]  preprocessed_act_nib3;
    logic [DCIM_ACT_WIDTH-1:0]  preprocessed_act_nib2;
    logic [DCIM_ACT_WIDTH-1:0]  preprocessed_act_nib1;
    logic [DCIM_ACT_WIDTH-1:0]  preprocessed_act_nib0;

    xdma_dcim_preprocess #(
        .CH_IN(`DCIM_CH_IN),
        .INT8_OUT_COLS(`DCIM_CH_OUT / 2),
        .INT16_OUT_COLS(`DCIM_CH_OUT / 4),
        .RAW_ACT_WORD_WIDTH(`DCIM_BRAM_DATA_WIDTH),
        .RAW_WEIGHT_WIDTH(DCIM_TILE_WIDTH),
        .DCIM_ACT_WIDTH(DCIM_ACT_WIDTH),
        .DCIM_WEIGHT_WIDTH(DCIM_TILE_WIDTH)
    ) u_preprocess (
        .mode_i(mode_reg),
        .raw_weight_i(raw_weight_reg),
        .dcim_weight_o(preprocessed_weight),
        .raw_act_word_i(raw_act_word_reg),
        .raw_act_row_sel_i(act_row_sel),
        .dcim_act_nib3_o(preprocessed_act_nib3),
        .dcim_act_nib2_o(preprocessed_act_nib2),
        .dcim_act_nib1_o(preprocessed_act_nib1),
        .dcim_act_nib0_o(preprocessed_act_nib0)
    );

    logic dcim_clr;
    logic dcim_act_valid;
    logic dcim_act_ready;
    logic [DCIM_ACT_WIDTH-1:0] dcim_act_data;
    logic dcim_mid_valid;
    logic dcim_mid_ready;
    logic [`DCIM_CH_OUT*WD2-1:0] dcim_mid_data;
    logic dcim_res_valid;
    logic dcim_res_ready;
    logic [DCIM_RES_WIDTH-1:0] dcim_res_data;

    calculate_core #(
        .WD1(`DCIM_WD1),
        .CH_IN(`DCIM_CH_IN),
        .CH_OUT(`DCIM_CH_OUT)
    ) u_calculate_core (
        .clk(clk),
        .rstn(rst_n),
        .clr(dcim_clr),
        .ena(1'b1),
        .mode(mode_reg),
        .up_valid(dcim_act_valid),
        .up_ready(dcim_act_ready),
        .dn_valid(dcim_mid_valid),
        .dn_ready(dcim_mid_ready),
        .up_data1(dcim_act_data),
        .up_data2(dcim_weight_reg),
        .dn_data(dcim_mid_data)
    );

    postProcess #(
        .WD1(`DCIM_WD1),
        .CH_IN(`DCIM_CH_IN),
        .CH_OUT(`DCIM_CH_OUT),
        .ACC(`DCIM_ACC_MAX)
    ) u_post_process (
        .clk(clk),
        .rstn(rst_n),
        .clr(dcim_clr),
        .ena(1'b1),
        .mode(mode_reg),
        .acc(acc_reg),
        .up_valid(dcim_mid_valid),
        .up_ready(dcim_mid_ready),
        .dn_valid(dcim_res_valid),
        .dn_ready(dcim_res_ready),
        .up_data(dcim_mid_data),
        .dn_data(dcim_res_data)
    );

    assign dcim_busy = (state != ST_IDLE) && (state != ST_DONE) && (state != ST_ERROR);
    assign dcim_config_ready = (state == ST_IDLE) || (state == ST_DONE) || (state == ST_ERROR);
    assign dcim_error = (state == ST_ERROR);
    assign dcim_res_ready = ((state == ST_ACT_NEXT) ||
                             (state == ST_ACT_SEND_HI) ||
                             (state == ST_ACT_SEND_MID1) ||
                             (state == ST_ACT_SEND_MID2) ||
                             (state == ST_ACT_SEND_LO) ||
                             (state == ST_ACT_LAUNCH) ||
                             (state == ST_DRAIN)) &&
                            !pending_accum_wait_reg &&
                            !pending_accum_merge_reg &&
                            (rows_out_reg < expected_out_rows_reg);

    wire dcim_act_fire = dcim_act_valid && dcim_act_ready;
    wire dcim_res_fire = dcim_res_valid && dcim_res_ready;
    logic signed [DCIM_RES_WIDTH-1:0] accum_old_data;
    logic signed [DCIM_RES_WIDTH-1:0] accum_new_data;
    logic signed [DCIM_RES_WIDTH-1:0] accum_merged_data;

    wire [`DCIM_IBUF_ADDR_WIDTH-1:0] wsrc_word_addr =
        wsrc_base_addr_reg[BRAM_ADDR_SHIFT +: `DCIM_IBUF_ADDR_WIDTH];
    wire [`DCIM_IBUF_ADDR_WIDTH-1:0] asrc_word_addr =
        asrc_base_addr_reg[BRAM_ADDR_SHIFT +: `DCIM_IBUF_ADDR_WIDTH];
    wire [`DCIM_IBUF_ADDR_WIDTH-1:0] asrc_word_index =
        (mode_reg == MODE_INT16) ? rows_sent_reg[`DCIM_IBUF_ADDR_WIDTH-1:0]
                                 : rows_sent_reg[`DCIM_IBUF_ADDR_WIDTH:1];
    wire [`DCIM_OBUF_ADDR_WIDTH-1:0] dst_word_addr =
        dst_addr_reg[BRAM_ADDR_SHIFT +: `DCIM_OBUF_ADDR_WIDTH];
    assign accum_old_data = obuf_doutb[DCIM_RES_WIDTH-1:0];
    assign accum_new_data = pending_res_data_reg;

    always_comb begin
        accum_merged_data = accum_new_data;
        for (int ch = 0; ch < `DCIM_CH_OUT; ch++) begin
            logic signed [WD3-1:0] lane_old;
            logic signed [WD3-1:0] lane_new;
            logic signed [WD3:0]   lane_res_ext;
            lane_old = accum_old_data[ch*WD3 +: WD3];
            lane_new = accum_new_data[ch*WD3 +: WD3];
            unique case (accumulate_type_reg)
                2'd1: lane_res_ext = lane_old + lane_new;
                default: lane_res_ext = lane_new;
            endcase
            // Keep lane-local two's-complement wrap, no cross-lane carry.
            accum_merged_data[ch*WD3 +: WD3] = lane_res_ext[WD3-1:0];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            dcim_done <= 1'b0;
            dcim_error_code <= 32'd0;
            wsrc_base_addr_reg <= '0;
            asrc_base_addr_reg <= '0;
            dst_addr_reg <= '0;
            raw_rows_reg <= 32'd0;
            mode_reg <= MODE_INT8;
            acc_reg <= 5'd0;
            accumulate_type_reg <= 2'd0;
            expected_out_rows_reg <= 32'd0;
            rows_sent_reg <= 32'd0;
            rows_out_reg <= 32'd0;
            w_word_idx <= 2'd0;
            act_row_sel <= 1'b0;
            raw_act_word_reg <= '0;
            raw_weight_reg0 <= '0;
            raw_weight_reg1 <= '0;
            raw_weight_reg2 <= '0;
            raw_weight_reg3 <= '0;
            dcim_weight_reg <= '0;
            dcim_clr <= 1'b0;
            dcim_act_valid <= 1'b0;
            dcim_act_data <= '0;
            pending_dst_addr_reg <= '0;
            pending_res_data_reg <= '0;
            pending_accum_wait_reg <= 1'b0;
            pending_accum_merge_reg <= 1'b0;
            ibuf_enb <= 1'b0;
            ibuf_addrb <= '0;
            obuf_enb <= 1'b0;
            obuf_web <= '0;
            obuf_addrb <= '0;
            obuf_dinb <= '0;
        end else begin
            ibuf_enb <= 1'b0;
            obuf_enb <= 1'b0;
            obuf_web <= '0;
            obuf_dinb <= '0;
            dcim_clr <= 1'b0;

            if (pending_accum_wait_reg) begin
                pending_accum_wait_reg <= 1'b0;
                pending_accum_merge_reg <= 1'b1;
            end else if (pending_accum_merge_reg) begin
                obuf_enb <= 1'b1;
                obuf_web <= {BRAM_BYTES{1'b1}};
                obuf_addrb <= pending_dst_addr_reg;
                obuf_dinb <= {{(`DCIM_BRAM_DATA_WIDTH-DCIM_RES_WIDTH){1'b0}}, accum_merged_data};
                pending_accum_merge_reg <= 1'b0;
            end

            if (dcim_res_fire) begin
                if (accumulate_type_reg == 2'd0) begin
                    obuf_enb <= 1'b1;
                    obuf_web <= {BRAM_BYTES{1'b1}};
                    obuf_addrb <= dst_word_addr + rows_out_reg[`DCIM_OBUF_ADDR_WIDTH-1:0];
                    obuf_dinb <= {{(`DCIM_BRAM_DATA_WIDTH-DCIM_RES_WIDTH){1'b0}}, dcim_res_data};
                end else begin
                    pending_dst_addr_reg <= dst_word_addr + rows_out_reg[`DCIM_OBUF_ADDR_WIDTH-1:0];
                    pending_res_data_reg <= dcim_res_data;
                    pending_accum_wait_reg <= 1'b1;
                    obuf_enb <= 1'b1;
                    obuf_web <= '0;
                    obuf_addrb <= dst_word_addr + rows_out_reg[`DCIM_OBUF_ADDR_WIDTH-1:0];
                end
                rows_out_reg <= rows_out_reg + 1'b1;
            end

            case (state)
                ST_IDLE: begin
                    dcim_done <= 1'b0;
                    dcim_act_valid <= 1'b0;
                    if (dcim_config_valid && dcim_config_ready) begin
                        wsrc_base_addr_reg <= wsrc_base_addr;
                        asrc_base_addr_reg <= asrc_base_addr;
                        dst_addr_reg <= dst_addr;
                        raw_rows_reg <= raw_rows;
                        mode_reg <= mode;
                        acc_reg <= acc;
                        accumulate_type_reg <= accumulate_type;
                    end
                    if (dcim_start) begin
                        dcim_error_code <= 32'd0;
                        rows_sent_reg <= 32'd0;
                        rows_out_reg <= 32'd0;
                        w_word_idx <= 2'd0;
                        pending_accum_wait_reg <= 1'b0;
                        pending_accum_merge_reg <= 1'b0;
                        dcim_clr <= 1'b1;
                        state <= ST_VALIDATE;
                    end
                end

                ST_VALIDATE: begin
                    if (validate_error) begin
                        dcim_error_code <= validate_error_code;
                        state <= ST_ERROR;
                    end else begin
                        expected_out_rows_reg <= validate_out_rows;
                        state <= ST_LOAD_W_REQ;
                    end
                end

                ST_LOAD_W_REQ: begin
                    ibuf_enb <= 1'b1;
                    ibuf_addrb <= wsrc_word_addr + {{(`DCIM_IBUF_ADDR_WIDTH-2){1'b0}}, w_word_idx};
                    state <= ST_LOAD_W_WAIT0;
                end

                ST_LOAD_W_WAIT0: begin
                    // Keep enable high for BRAM read
                    ibuf_enb <= 1'b1;
                    ibuf_addrb <= wsrc_word_addr + {{(`DCIM_IBUF_ADDR_WIDTH-2){1'b0}}, w_word_idx};
                    state <= ST_LOAD_W_WAIT1;
                end

                ST_LOAD_W_WAIT1: begin
                    // Data is now valid on ibuf_doutb
                    if (w_word_idx == 2'd0)
                        raw_weight_reg0 <= ibuf_doutb;
                    else if (w_word_idx == 2'd1)
                        raw_weight_reg1 <= ibuf_doutb;
                    else if (w_word_idx == 2'd2)
                        raw_weight_reg2 <= ibuf_doutb;
                    else
                        raw_weight_reg3 <= ibuf_doutb;
                    
                    if (w_word_idx == 2'd3) begin
                        state <= ST_PREP_W;
                    end else begin
                        w_word_idx <= w_word_idx + 1'b1;
                        state <= ST_LOAD_W_REQ;
                    end
                end

                ST_PREP_W: begin
                    dcim_weight_reg <= preprocessed_weight;
                    state <= ST_CLEAR;
                end

                ST_CLEAR: begin
                    dcim_clr <= 1'b1;
                    rows_sent_reg <= 32'd0;
                    rows_out_reg <= 32'd0;
                    state <= ST_ACT_NEXT;
                end

                ST_ACT_NEXT: begin
                    if (rows_sent_reg < raw_rows_reg) begin
                        act_row_sel <= (mode_reg == MODE_INT16) ? 1'b0 : rows_sent_reg[0];
                        state <= ST_ACT_REQ;
                    end else begin
                        state <= ST_DRAIN;
                    end
                end

                ST_ACT_REQ: begin
                    ibuf_enb <= 1'b1;
                    ibuf_addrb <= asrc_word_addr + asrc_word_index;
                    state <= ST_ACT_WAIT0;
                end

                ST_ACT_WAIT0: begin
                    ibuf_enb <= 1'b1;
                    ibuf_addrb <= asrc_word_addr + asrc_word_index;
                    state <= ST_ACT_WAIT1;
                end

                ST_ACT_WAIT1: begin
                    raw_act_word_reg <= ibuf_doutb;
                    state <= ST_ACT_LAUNCH;
                end

                ST_ACT_LAUNCH: begin
                    dcim_act_data <= preprocessed_act_nib3;
                    dcim_act_valid <= 1'b1;
                    state <= ST_ACT_SEND_HI;
                end

                ST_ACT_SEND_HI: begin
                    if (dcim_act_fire) begin
                        if (mode_reg == MODE_INT16) begin
                            dcim_act_data <= preprocessed_act_nib2;
                            state <= ST_ACT_SEND_MID1;
                        end else begin
                            dcim_act_data <= preprocessed_act_nib0;
                            state <= ST_ACT_SEND_LO;
                        end
                    end
                end

                ST_ACT_SEND_MID1: begin
                    if (dcim_act_fire) begin
                        dcim_act_data <= preprocessed_act_nib1;
                        state <= ST_ACT_SEND_MID2;
                    end
                end

                ST_ACT_SEND_MID2: begin
                    if (dcim_act_fire) begin
                        dcim_act_data <= preprocessed_act_nib0;
                        state <= ST_ACT_SEND_LO;
                    end
                end

                ST_ACT_SEND_LO: begin
                    if (dcim_act_fire) begin
                        dcim_act_valid <= 1'b0;
                        rows_sent_reg <= rows_sent_reg + 1'b1;
                        state <= ST_ACT_NEXT;
                    end
                end

                ST_DRAIN: begin
                    dcim_act_valid <= 1'b0;
                    if (rows_out_reg >= expected_out_rows_reg) begin
                        dcim_done <= 1'b1;
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    dcim_act_valid <= 1'b0;
                    if (dcim_start) begin
                        dcim_done <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                ST_ERROR: begin
                    dcim_act_valid <= 1'b0;
                    dcim_done <= 1'b1;
                    if (dcim_start) begin
                        dcim_done <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
