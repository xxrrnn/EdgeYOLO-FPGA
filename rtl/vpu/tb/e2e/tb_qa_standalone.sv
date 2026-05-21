`timescale 1ns/1ps
`include "chip_defines.vh"

// Standalone QA unit test - no DCIM/OBUF overhead
module tb_qa_standalone;

    localparam CLK_PERIOD = 4.0;
    localparam ADDR_WIDTH = 32;
    localparam GB_BANDWIDTH = `GB_BANDWIDTH;      // 128
    localparam GB_ADDR_WIDTH = `GB_ADDR_WIDTH;    // 24
    localparam WB_BANDWIDTH = `WB_BANDWIDTH;      // 128
    localparam WB_ADDR_WIDTH = `WB_ADDR_WIDTH;    // 15
    localparam FP_CORE_NUM = `FP_CORE_NUM;        // 4
    localparam FP_TRAN_NUM = `FP_TRAN_NUM;        // 4
    localparam FP_WIDTH = `FP_WIDTH;              // 32
    localparam Q_INT_WIDTH_OUT = `Q_INT_WIDTH_OUT; // 8
    localparam MAX_CHANNEL_NUM = `MAX_CHANNEL_NUM; // 512

    reg clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    reg rst_n = 0;

    // QA ports
    reg  qa_unit_start;
    wire qa_unit_ready;
    reg  [ADDR_WIDTH-1:0] qa_src_addr, qa_scale_addr, qa_dst_addr;
    reg  [ADDR_WIDTH-1:0] qa_src_c, qa_src_h, qa_src_w;

    // FP MAC interface
    wire                              fp_array_tvalid;
    wire                              fp_array_tready;
    wire [FP_CORE_NUM*FP_WIDTH-1:0]   fp_a_tdata, fp_b_tdata, fp_c_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0]   fp_res;
    wire                              fp_res_tvalid;

    // GB (OBUF mock) interface
    wire [GB_ADDR_WIDTH-1:0]  gb_addrb;
    wire [GB_BANDWIDTH-1:0]   gb_dinb;
    wire [GB_BANDWIDTH/8-1:0] gb_web;
    wire                      gb_enb;
    reg  [GB_BANDWIDTH-1:0]   gb_doutb;

    // WB interface
    wire [WB_ADDR_WIDTH-1:0]  wb_addrb;
    wire [WB_BANDWIDTH-1:0]   wb_dinb;
    wire                      wb_enb;
    wire                      wb_web;
    reg  [WB_BANDWIDTH-1:0]   wb_doutb;

    // GB (OBUF) memory model - small
    reg [127:0] obuf_mem [0:255];
    reg [127:0] obuf_rd_reg;
    always @(posedge clk) begin
        if (gb_enb) begin
            if (|gb_web) begin
                obuf_mem[gb_addrb[7:0]] <= gb_dinb;
                $display("[%0t] QA WRITE OBUF[%0d] = 0x%032h", $time, gb_addrb[7:0], gb_dinb);
            end
            obuf_rd_reg <= obuf_mem[gb_addrb[7:0]];
        end
    end
    assign gb_doutb = obuf_rd_reg;

    // WB memory model
    reg [127:0] wb_mem [0:15];
    always @(posedge clk) begin
        if (wb_enb)
            wb_doutb <= wb_mem[wb_addrb[3:0]];
    end

    // QA unit
    qa_unit #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_BANDWIDTH(GB_BANDWIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .WB_BANDWIDTH(WB_BANDWIDTH),
        .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_WIDTH(FP_WIDTH),
        .Q_INT_WIDTH_OUT(Q_INT_WIDTH_OUT),
        .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM)
    ) u_qa (
        .clk(clk),
        .rst_n(rst_n),
        .qa_unit_start(qa_unit_start),
        .qa_unit_ready(qa_unit_ready),
        .qa_src_addr(qa_src_addr),
        .qa_scale_addr(qa_scale_addr),
        .qa_dst_addr(qa_dst_addr),
        .qa_src_c(qa_src_c),
        .qa_src_h(qa_src_h),
        .qa_src_w(qa_src_w),
        .fp_array_tvalid(fp_array_tvalid),
        .fp_array_tready(fp_array_tready),
        .fp_a_tdata(fp_a_tdata),
        .fp_b_tdata(fp_b_tdata),
        .fp_c_tdata(fp_c_tdata),
        .fp_res(fp_res),
        .fp_res_tvalid(fp_res_tvalid),
        .gb_addrb(gb_addrb),
        .gb_dinb(gb_dinb),
        .gb_web(gb_web),
        .gb_enb(gb_enb),
        .gb_doutb(gb_doutb),
        .wb_addrb(wb_addrb),
        .wb_dinb(wb_dinb),
        .wb_enb(wb_enb),
        .wb_web(wb_web),
        .wb_doutb(wb_doutb)
    );

    // FP MAC array (real Vivado IP)
    fp_mac_array #(
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_WIDTH(FP_WIDTH)
    ) u_fp_mac (
        .clk(clk),
        .fp_array_tvalid(fp_array_tvalid),
        .fp_array_tready(fp_array_tready),
        .a_tdata(fp_a_tdata),
        .b_tdata(fp_b_tdata),
        .c_tdata(fp_c_tdata),
        .res(fp_res),
        .res_tvalid(fp_res_tvalid)
    );

    // Test
    integer i;
    initial begin
        $display("=== tb_qa_standalone: QA unit test ===");
        $display("  FP_CORE_NUM=%0d, GB_BW=%0d, FP_WIDTH=%0d", FP_CORE_NUM, GB_BANDWIDTH, FP_WIDTH);

        qa_unit_start = 0;
        qa_src_addr = 0; qa_scale_addr = 0; qa_dst_addr = 0;
        qa_src_c = 0; qa_src_h = 0; qa_src_w = 0;

        // Init OBUF with FP32 data: 4 values per word, all = 10.0 (0x41200000)
        // 1 pixel × 4 channels = 1 word (simplest case)
        for (i = 0; i < 256; i = i + 1) obuf_mem[i] = 0;
        obuf_mem[0] = {32'hc0400000, 32'h42c89a00, 32'h40b66666, 32'h40200000}; // FP32: -3.0, 100.3, 5.7, 2.5

        // Init WB: scale = 0.1 (0x3dcccccd) at word 0
        for (i = 0; i < 16; i = i + 1) wb_mem[i] = 0;
        wb_mem[0] = {96'h0, 32'h3f000000};  // scale=0.5 in lowest 32 bits

        #20; rst_n = 1;
        #20;

        // Configure QA: 1 pixel × 4 channels
        qa_src_addr  = 32'h0;    // OBUF source (word addr after >>4 = 0)
        qa_scale_addr = 32'h0;   // WB byte addr 0
        qa_dst_addr  = 32'h0100; // OBUF dest (word addr after >>4 = 0x10)
        qa_src_c = 4;            // 4 channels
        qa_src_h = 1;            // 1 pixel high
        qa_src_w = 1;            // 1 pixel wide

        $display("[%0t] Starting QA: src=0x%h dst=0x%h c=%0d h=%0d w=%0d scale_addr=0x%h",
                 $time, qa_src_addr, qa_dst_addr, qa_src_c, qa_src_h, qa_src_w, qa_scale_addr);
        $display("  Input FP32: [2.5, 5.7, 100.3, -3.0], Scale: 0.5");
        $display("  Expected: 2.5*0.5=1, 5.7*0.5=3, 100.3*0.5=50, -3.0*0.5=-2 → INT8 = 1");

        @(posedge clk);
        qa_unit_start = 1;
        @(posedge clk);
        qa_unit_start = 0;

        // Wait for completion
        fork
            begin : wait_done
                wait(qa_unit_ready == 0);  // started
                $display("[%0t] QA started: total_blocks=%0d threshold=%0d",
                         $time, u_qa.qa_x_total_blocks_reg, u_qa.qa_x_load_done_threshold);
                wait(qa_unit_ready == 1);  // done
                $display("[%0t] QA done (ready=1)", $time);
            end
            begin : timeout
                #40000;  // 10K cycles
                $display("[%0t] TIMEOUT! state=%0d cnt=%0d done=%b total_blocks=%0d",
                         $time, u_qa.c_state, u_qa.qa_x_load_cnt, u_qa.qa_done,
                         u_qa.qa_x_total_blocks_reg);
                disable wait_done;
            end
        join

        // Check output
        $display("[%0t] OBUF[0x10] = 0x%032h (QA INT8 output)", $time, obuf_mem[16]);
        // Expected: INT8(1) packed = 0x01010101 (4 channels each = 1)
        $display("  QA output bytes: [%0d, %0d, %0d, %0d]", 
                 $signed(obuf_mem[16][7:0]), $signed(obuf_mem[16][15:8]),
                 $signed(obuf_mem[16][23:16]), $signed(obuf_mem[16][31:24]));
        if (obuf_mem[16][7:0] == 8'd1 && obuf_mem[16][15:8] == 8'd3 && obuf_mem[16][23:16] == 8'd50)
            $display("PASS: QA output matches expected [1, 3, 50, -2]");
        else
            $display("FAIL: Expected [1, 3, 50, -2]");

        $finish;
    end

endmodule
