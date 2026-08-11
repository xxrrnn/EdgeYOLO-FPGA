`timescale 1ns / 1ns
`include "chip_defines.vh"

// Unified INT8/native-INT16 partial accumulation and final OBUF writer.
//
// The arithmetic core produces one 512-bit logical result per pixel after
// packing (16xINT32 for INT8, 8xINT64 for INT16).  A 64-context BRAM carries
// partial sums between acc rows.  On the final row, two physical OBUF ports
// write the established four consecutive 128-bit words in two clocks.
module DCIM_Result_Stream #(
    parameter WD1             = `DCIM_WD1,
    parameter CH_IN           = `DCIM_CH_IN,
    parameter CH_OUT          = `DCIM_CH_OUT,
    parameter ACC             = `DCIM_ACC_MAX,
    parameter OBUF_ADDR_WIDTH = `DCIM_TILE_OBUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH,
    parameter MICRO_BATCH     = 64,
    parameter READ_DELAY      = 11,

    localparam WD3          = 2*WD1 + $clog2(CH_IN) + $clog2(ACC),
    localparam CORE_WIDTH   = CH_OUT * WD3,
    localparam PACKED_WIDTH = 4 * BUF_DATA_WIDTH,
    localparam STRB_WIDTH   = BUF_DATA_WIDTH / 8,
    localparam JOB_W        = (MICRO_BATCH <= 1) ? 1 : $clog2(MICRO_BATCH),
    localparam JOB_COUNT_W  = $clog2(MICRO_BATCH + 1)
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         clear,
    input  wire                         row_start,
    input  wire [2:0]                   mode,
    input  wire                         first_acc_row,
    input  wire                         last_acc_row,
    input  wire [JOB_COUNT_W-1:0]       pixel_count,
    input  wire                         benchmark_repeat,
    input  wire [31:0]                  repeat_count,
    input  wire [OBUF_ADDR_WIDTH-1:0]   out_base_addr,
    input  wire [OBUF_ADDR_WIDTH-1:0]   out_stride_words,

    input  wire                         job_last_phase_fire,
    input  wire [JOB_W-1:0]             issue_job,

    input  wire                         core_out_valid,
    output wire                         core_out_ready,
    input  wire [CORE_WIDTH-1:0]        core_out_data,

    output wire                         obuf0_wr_valid,
    output wire [OBUF_ADDR_WIDTH-1:0]   obuf0_wr_addr,
    output wire [BUF_DATA_WIDTH-1:0]    obuf0_wr_data,
    output wire [STRB_WIDTH-1:0]        obuf0_wr_strb,
    output wire                         obuf1_wr_valid,
    output wire [OBUF_ADDR_WIDTH-1:0]   obuf1_wr_addr,
    output wire [BUF_DATA_WIDTH-1:0]    obuf1_wr_data,
    output wire [STRB_WIDTH-1:0]        obuf1_wr_strb,

    output reg                          row_done,
    output wire                         peak_result_valid,
    output wire [31:0]                  peak_result_data
);

    function automatic [PACKED_WIDTH-1:0] pack_core_result(
        input [CORE_WIDTH-1:0] data,
        input pack_int16
    );
        reg [PACKED_WIDTH-1:0] packed_value;
        reg signed [WD3-1:0] physical_value;
        reg signed [4*WD3-1:0] raw_int16;
        integer logical_lane;
        integer physical_lane;
        begin
            packed_value = '0;
            if (pack_int16) begin
                for (logical_lane = 0; logical_lane < CH_OUT/4; logical_lane = logical_lane + 1) begin
                    physical_lane = logical_lane * 4;
                    raw_int16 = {
                        data[(physical_lane+3)*WD3 +: WD3],
                        data[(physical_lane+2)*WD3 +: WD3],
                        data[(physical_lane+1)*WD3 +: WD3],
                        data[(physical_lane+0)*WD3 +: WD3]
                    };
                    packed_value[logical_lane*64 +: 64] = raw_int16[63:0];
                end
            end else begin
                for (logical_lane = 0; logical_lane < CH_OUT/2; logical_lane = logical_lane + 1) begin
                    physical_lane = logical_lane * 2;
                    physical_value = data[physical_lane*WD3 +: WD3];
                    packed_value[logical_lane*32 +: 32] =
                        {{(32-WD3){physical_value[WD3-1]}}, physical_value};
                end
            end
            pack_core_result = packed_value;
        end
    endfunction

    function automatic [PACKED_WIDTH-1:0] add_partial_sum(
        input [PACKED_WIDTH-1:0] current_value,
        input [PACKED_WIDTH-1:0] partial_value,
        input add_int16
    );
        reg [PACKED_WIDTH-1:0] sum_value;
        reg signed [31:0] a32, b32;
        reg signed [63:0] a64, b64;
        integer lane;
        begin
            sum_value = '0;
            if (add_int16) begin
                for (lane = 0; lane < PACKED_WIDTH/64; lane = lane + 1) begin
                    a64 = current_value[lane*64 +: 64];
                    b64 = partial_value[lane*64 +: 64];
                    sum_value[lane*64 +: 64] = a64 + b64;
                end
            end else begin
                for (lane = 0; lane < PACKED_WIDTH/32; lane = lane + 1) begin
                    a32 = current_value[lane*32 +: 32];
                    b32 = partial_value[lane*32 +: 32];
                    sum_value[lane*32 +: 32] = a32 + b32;
                end
            end
            add_partial_sum = sum_value;
        end
    endfunction

    // Packing and accumulation each expand one INT16 select into a wide lane
    // mux.  Independent directly-registered copies allow synthesis/placement to
    // replicate them locally; a shared mode comparator previously had 1184 loads.
    (* keep = "true", max_fanout = 32 *) reg pack_int16_reg;
    (* keep = "true", max_fanout = 32 *) reg add_int16_reg;
    reg first_row_reg;
    reg last_row_reg;
    reg [JOB_COUNT_W-1:0] pixel_count_reg;
    reg benchmark_repeat_reg;
    reg [31:0] repeat_limit_reg;
    reg [31:0] result_repeat;
    reg [OBUF_ADDR_WIDTH-1:0] row_out_base;
    reg [OBUF_ADDR_WIDTH-1:0] next_out_base;
    reg [OBUF_ADDR_WIDTH-1:0] out_stride_reg;

    // Delay only the small job tag; the 512-bit BRAM data is read shortly
    // before the fixed-latency arithmetic result reaches this module.
    reg [READ_DELAY-1:0] read_valid_pipe;
    reg [JOB_W-1:0] read_job_pipe [0:READ_DELAY-1];
    integer delay_i;

    wire scratch_rd_en = read_valid_pipe[READ_DELAY-1];
    wire [JOB_W-1:0] scratch_rd_addr = read_job_pipe[READ_DELAY-1];
    wire scratch_rd_valid;
    wire [PACKED_WIDTH-1:0] scratch_rd_data;
    wire scratch_wr_en;
    wire [JOB_W-1:0] scratch_wr_addr;
    wire [PACKED_WIDTH-1:0] scratch_wr_data;

    DCIM_Partial_Sum_RAM #(
        .DATA_WIDTH(PACKED_WIDTH),
        .DEPTH(MICRO_BATCH)
    ) u_partial_sum_ram (
        .clk(clk),
        .rd_en(scratch_rd_en),
        .rd_addr(scratch_rd_addr),
        .rd_valid(scratch_rd_valid),
        .rd_data(scratch_rd_data),
        .wr_en(scratch_wr_en),
        .wr_addr(scratch_wr_addr),
        .wr_data(scratch_wr_data)
    );

    reg partial_valid;
    reg [PACKED_WIDTH-1:0] partial_data;
    reg [JOB_W-1:0] partial_job;
    reg [JOB_W-1:0] partial_rsp_count;
    reg [JOB_W-1:0] core_result_count;

    reg sum_valid;
    reg [PACKED_WIDTH-1:0] sum_data;
    reg [JOB_W-1:0] sum_job;

    reg second_half_valid;
    reg [BUF_DATA_WIDTH-1:0] second_word0;
    reg [BUF_DATA_WIDTH-1:0] second_word1;
    reg [OBUF_ADDR_WIDTH-1:0] second_base;
    reg second_is_last;

    wire writer_ready = !second_half_valid;
    wire sum_down_ready = last_row_reg ? writer_ready : 1'b1;
    wire sum_in_ready = !sum_valid || sum_down_ready;
    wire partial_available = first_row_reg || partial_valid;
    assign core_out_ready = sum_in_ready && partial_available;
    wire core_out_fire = core_out_valid && core_out_ready;

    wire [PACKED_WIDTH-1:0] packed_core =
        pack_core_result(core_out_data, pack_int16_reg);
    wire [PACKED_WIDTH-1:0] accumulated_core =
        first_row_reg ? packed_core :
        add_partial_sum(packed_core, partial_data, add_int16_reg);

    wire writer_accept = sum_valid && last_row_reg && writer_ready;
    wire intermediate_accept = sum_valid && !last_row_reg;
    wire writer_job_last = ({1'b0, sum_job} + 1'b1 >= pixel_count_reg);
    wire writer_repeat_last = !benchmark_repeat_reg ||
                              (result_repeat + 1'b1 >= repeat_limit_reg);

    assign scratch_wr_en = intermediate_accept;
    assign scratch_wr_addr = sum_job;
    assign scratch_wr_data = sum_data;

    assign obuf0_wr_valid = second_half_valid || writer_accept;
    assign obuf1_wr_valid = second_half_valid || writer_accept;
    assign obuf0_wr_addr = writer_accept ? next_out_base : second_base;
    assign obuf1_wr_addr = writer_accept ? (next_out_base + 1'b1) : (second_base + 1'b1);
    assign obuf0_wr_data = writer_accept ? sum_data[0*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] : second_word0;
    assign obuf1_wr_data = writer_accept ? sum_data[1*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] : second_word1;
    assign obuf0_wr_strb = {STRB_WIDTH{1'b1}};
    assign obuf1_wr_strb = {STRB_WIDTH{1'b1}};

    assign peak_result_valid = writer_accept;
    assign peak_result_data = sum_data[31:0];

    wire partial_consume = core_out_fire && !first_row_reg;

    // Keep these registers entirely outside the asynchronous-reset process.
    // Their values are observed only after row_start initializes them and the
    // corresponding valid token arrives.  An unreset register left inside an
    // async-reset always_ff is otherwise inferred as FDCP replicas whose setup
    // timing cannot be analyzed reliably.
    always_ff @(posedge clk) begin
        if (row_start) begin
            pack_int16_reg <= (mode == `MODE_INT16);
            add_int16_reg <= (mode == `MODE_INT16);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            first_row_reg <= 1'b1;
            last_row_reg <= 1'b1;
            pixel_count_reg <= '0;
            benchmark_repeat_reg <= 1'b0;
            repeat_limit_reg <= 32'd1;
            result_repeat <= '0;
            row_out_base <= '0;
            next_out_base <= '0;
            out_stride_reg <= '0;
            read_valid_pipe <= '0;
            for (delay_i = 0; delay_i < READ_DELAY; delay_i = delay_i + 1)
                read_job_pipe[delay_i] <= '0;
            partial_valid <= 1'b0;
            partial_data <= '0;
            partial_job <= '0;
            partial_rsp_count <= '0;
            core_result_count <= '0;
            sum_valid <= 1'b0;
            sum_data <= '0;
            sum_job <= '0;
            second_half_valid <= 1'b0;
            second_word0 <= '0;
            second_word1 <= '0;
            second_base <= '0;
            second_is_last <= 1'b0;
            row_done <= 1'b0;
        end else if (clear) begin
            read_valid_pipe <= '0;
            partial_valid <= 1'b0;
            partial_rsp_count <= '0;
            core_result_count <= '0;
            sum_valid <= 1'b0;
            second_half_valid <= 1'b0;
            row_done <= 1'b0;
        end else begin
            row_done <= 1'b0;

            if (row_start) begin
                first_row_reg <= first_acc_row;
                last_row_reg <= last_acc_row;
                pixel_count_reg <= pixel_count;
                benchmark_repeat_reg <= benchmark_repeat;
                repeat_limit_reg <= (repeat_count == 0) ? 32'd1 : repeat_count;
                result_repeat <= '0;
                row_out_base <= out_base_addr;
                next_out_base <= out_base_addr;
                out_stride_reg <= out_stride_words;
                read_valid_pipe <= '0;
                for (delay_i = 0; delay_i < READ_DELAY; delay_i = delay_i + 1)
                    read_job_pipe[delay_i] <= '0;
                partial_valid <= 1'b0;
                partial_rsp_count <= '0;
                core_result_count <= '0;
                sum_valid <= 1'b0;
                second_half_valid <= 1'b0;
            end else begin
                read_valid_pipe[0] <= job_last_phase_fire && !first_row_reg;
                if (job_last_phase_fire && !first_row_reg)
                    read_job_pipe[0] <= issue_job;
                for (delay_i = 1; delay_i < READ_DELAY; delay_i = delay_i + 1) begin
                    read_valid_pipe[delay_i] <= read_valid_pipe[delay_i-1];
                    read_job_pipe[delay_i] <= read_job_pipe[delay_i-1];
                end

                if (scratch_rd_valid) begin
                    partial_valid <= 1'b1;
                    partial_data <= scratch_rd_data;
                    partial_job <= partial_rsp_count;
                    partial_rsp_count <= partial_rsp_count + 1'b1;
                end else if (partial_consume) begin
                    partial_valid <= 1'b0;
                end

                if (sum_in_ready) begin
                    sum_valid <= core_out_fire;
                    if (core_out_fire) begin
                        sum_data <= accumulated_core;
                        sum_job <= core_result_count;
                        core_result_count <= core_result_count + 1'b1;
                    end
                end

                if (intermediate_accept &&
                    ({1'b0, sum_job} + 1'b1 >= pixel_count_reg)) begin
                    row_done <= 1'b1;
                end

                if (second_half_valid) begin
                    second_half_valid <= 1'b0;
                    if (second_is_last)
                        row_done <= 1'b1;
                end

                if (writer_accept) begin
                    second_half_valid <= 1'b1;
                    second_word0 <= sum_data[2*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
                    second_word1 <= sum_data[3*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
                    second_base <= next_out_base + 2;
                    second_is_last <= writer_job_last && writer_repeat_last;
                    if (writer_job_last && benchmark_repeat_reg &&
                        !writer_repeat_last) begin
                        result_repeat <= result_repeat + 1'b1;
                        next_out_base <= row_out_base;
                    end else begin
                        next_out_base <= next_out_base + out_stride_reg;
                    end
                end
            end
        end
    end

`ifdef SIMULATION
    always_ff @(posedge clk) begin
        if (rst_n && !clear && scratch_rd_valid && partial_valid && !partial_consume)
            $fatal(1, "DCIM partial-sum response overflow");
        if (rst_n && !clear && core_out_fire && !first_row_reg &&
            (partial_job != core_result_count))
            $fatal(1, "DCIM partial/core job mismatch partial=%0d core=%0d",
                   partial_job, core_result_count);
        if (rst_n && row_start && benchmark_repeat &&
            (!first_acc_row || !last_acc_row || (pixel_count != MICRO_BATCH)))
            $fatal(1, "DCIM benchmark repeat requires acc_depth=1 and %0d jobs",
                   MICRO_BATCH);
    end
`endif

endmodule
