`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// INST_Decoder_wrapper - Verilog wrapper for SystemVerilog INST_Decoder
//
// 用于在 Vivado Block Design 中实例化 SystemVerilog 模块
//////////////////////////////////////////////////////////////////////////////////

module INST_Decoder_wrapper #(
    parameter INST_BRAM_DEPTH = 262144,
    parameter INST_ADDR_WIDTH = 18
) (
    input  wire        clk,
    input  wire        rst_n,
    
    // 控制接口
    input  wire        decoder_start,
    input  wire [31:0] inst_count,
    output wire        decoder_busy,
    output wire        decoder_done,
    output wire [31:0] decoder_status,
    
    // inst_bram 接口
    output wire [INST_ADDR_WIDTH-1:0] inst_rd_addr,
    input  wire [31:0]                inst_rd_data,
    
    // CDMA_Controller 接口
    output wire        cdma_start,
    output wire        cdma_config_valid,
    input  wire        cdma_config_ready,
    output wire [31:0] cdma_src_addr_msb,
    output wire [31:0] cdma_src_addr_lsb,
    output wire [31:0] cdma_dst_addr_msb,
    output wire [31:0] cdma_dst_addr_lsb,
    output wire [31:0] cdma_length,
    
    // VPU 接口
    output wire        vpu_start,
    input  wire        vpu_ready,
    output wire [31:0] vpu_unit_choose,
    output wire [31:0] vpu_src_addr,
    output wire [31:0] vpu_src2_addr,
    output wire [31:0] vpu_src_c,
    output wire [31:0] vpu_src_h,
    output wire [31:0] vpu_src_w,
    output wire [31:0] vpu_bias_addr,
    output wire [31:0] vpu_scale_addr,
    output wire [31:0] vpu_dst_addr,
    output wire [31:0] vpu_addr_break,
    output wire [31:0] vpu_addr_s,
    output wire [31:0] vpu_addr_t
);

    // 实例化 SystemVerilog 模块
    INST_Decoder #(
        .INST_BRAM_DEPTH(INST_BRAM_DEPTH),
        .INST_ADDR_WIDTH(INST_ADDR_WIDTH)
    ) inst_decoder_sv (
        .clk(clk),
        .rst_n(rst_n),
        
        .decoder_start(decoder_start),
        .inst_count(inst_count),
        .decoder_busy(decoder_busy),
        .decoder_done(decoder_done),
        .decoder_status(decoder_status),
        
        .inst_rd_addr(inst_rd_addr),
        .inst_rd_data(inst_rd_data),
        
        .cdma_start(cdma_start),
        .cdma_config_valid(cdma_config_valid),
        .cdma_config_ready(cdma_config_ready),
        .cdma_src_addr_msb(cdma_src_addr_msb),
        .cdma_src_addr_lsb(cdma_src_addr_lsb),
        .cdma_dst_addr_msb(cdma_dst_addr_msb),
        .cdma_dst_addr_lsb(cdma_dst_addr_lsb),
        .cdma_length(cdma_length),
        
        .vpu_start(vpu_start),
        .vpu_ready(vpu_ready),
        .vpu_unit_choose(vpu_unit_choose),
        .vpu_src_addr(vpu_src_addr),
        .vpu_src2_addr(vpu_src2_addr),
        .vpu_src_c(vpu_src_c),
        .vpu_src_h(vpu_src_h),
        .vpu_src_w(vpu_src_w),
        .vpu_bias_addr(vpu_bias_addr),
        .vpu_scale_addr(vpu_scale_addr),
        .vpu_dst_addr(vpu_dst_addr),
        .vpu_addr_break(vpu_addr_break),
        .vpu_addr_s(vpu_addr_s),
        .vpu_addr_t(vpu_addr_t)
    );

endmodule
