`timescale 1ns/1ps

// int32_2_fp16_array.sv  （带 clip 到 fp16 范围的版本）
module int32_2_fp16_array #(
    parameter integer FP_TRAN_NUM = 0
)(
    input  wire                     clk,
    // shared valid for all int32 inputs
    input  wire                     s_axis_tvalid,
    // packed int32 data: [ (N-1)*32 + 31 : 0 ]
    input  wire [FP_TRAN_NUM*32-1:0]                s_axis_tdata,

    // single shared valid output
    output wire                     m_axis_result_tvalid,
    // packed fp16 outputs (wire): [ (N-1)*16 + 15 : 0 ]
    output wire [FP_TRAN_NUM*16-1:0]               m_axis_result_tdata
);

    // fp16 finite max/min (IEEE-754 half precision)
    // +65504 / -65504
    localparam signed [31:0] FP16_MAX_INT = 32'sd65504;
    localparam signed [31:0] FP16_MIN_INT = -32'sd65504;

    // Internal per-core wires
    wire [FP_TRAN_NUM-1:0]                    fp32_valid;
    wire [FP_TRAN_NUM*32-1:0]                 fp32_data;
    wire [FP_TRAN_NUM-1:0]                    fp16_valid;
    wire [FP_TRAN_NUM*16-1:0]                 fp16_data;

    genvar i;
    generate
        for (i = 0; i < FP_TRAN_NUM; i = i + 1) begin : GEN_FP_CORES
            // Slices for this instance
            wire s_valid_i = s_axis_tvalid;
            wire [31:0] s_data_i = s_axis_tdata[i*32 +: 32];

            // Signed view and clipped value
            wire signed [31:0] s_data_i_s = $signed(s_data_i);
            wire signed [31:0] s_data_clipped_i_s;
            // combinational clip
            assign s_data_clipped_i_s = (s_data_i_s > FP16_MAX_INT) ? FP16_MAX_INT :
                                        (s_data_i_s < FP16_MIN_INT) ? FP16_MIN_INT :
                                        s_data_i_s;
            // convert back to unsigned-wire 32-bit for compatibility with downstream ports
            wire [31:0] s_data_clipped_i = s_data_clipped_i_s;

            // Wires for intermediate fp32
            wire fp32_valid_i;
            wire [31:0] fp32_data_i;

            // Wires for final fp16
            wire fp16_valid_i;
            wire [15:0] fp16_data_i;

            // Instantiate int32 -> fp32 (feed clipped data)
            int32_2_fp32 int32_to_fp32_inst (
                .aclk(clk),
                .s_axis_a_tvalid(s_valid_i),
                .s_axis_a_tdata(s_data_clipped_i),
                .m_axis_result_tvalid(fp32_valid_i),
                .m_axis_result_tdata(fp32_data_i)
            );

            // Instantiate fp32 -> fp16
            fp32_2_fp16 fp32_to_fp16_inst (
                .aclk(clk),
                .s_axis_a_tvalid(fp32_valid_i),
                .s_axis_a_tdata(fp32_data_i),
                .m_axis_result_tvalid(fp16_valid_i),
                .m_axis_result_tdata(fp16_data_i)
            );

            // Collect intermediate wires into vectors so we can access them outside
            assign fp32_valid[i] = fp32_valid_i;
            assign fp32_data[ i*32 +: 32 ] = fp32_data_i;
            assign fp16_valid[i] = fp16_valid_i;
            assign fp16_data[ i*16 +: 16 ] = fp16_data_i;
        end
    endgenerate

    // Pack fp16 outputs into the module-level output wire
    assign m_axis_result_tdata = fp16_data;

    // Single shared output valid: asserted when all per-core fp16 valids are high
    assign m_axis_result_tvalid = &fp16_valid;

endmodule
