`timescale 1ns / 1ps

module tb_DCIM_Macro;

    // =========================
    // 参数定义（可根据需要调整）
    // =========================
    localparam WEIGHT_DW           = 8;
    localparam ACT_DW              = 8;
    localparam OUT_DW              = 32;
    localparam NUM_CELL            = 1024;
    localparam NUM_CELL_PER_DCIM   = 32;
    localparam ADDR_WIDTH          = 16;
    localparam IBUF_ADDR_WIDTH     = 15;
    localparam OBUF_ADDR_WIDTH     = 4;
    localparam IBUF_BANDWIDTH      = 256;
    localparam OBUF_BANDWIDTH      = 256;
    localparam RAM_NBPIPE          = 1;
    localparam MAX_CHANNEL_NUM         = 512;



/* mem */

localparam ACT_CHANNEL_NUM = 64;
localparam ACT_HEIGHT = 3;
localparam ACT_WIDTH  = 3;
localparam ACT_BLOCKS = 18;
localparam ACT_BYTES  = 18 * 32;

reg [255:0] act [0:17];

initial begin
    $display("Loading G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/DCIM_MACRO/mem/mac_act_data.mem ...");
    $readmemh("G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/DCIM_MACRO/mem/mac_act_data.mem", act);
    $display("Loaded %0d blocks into act", ACT_BLOCKS);
end




localparam WEIGHT_CHANNEL_NUM = 64;
localparam WEIGHT_HEIGHT = 3;
localparam WEIGHT_WIDTH  = 3;
localparam WEIGHT_BLOCKS = 576;
localparam WEIGHT_BYTES  = 576 * 32;

reg [255:0] weight [0:575];

initial begin
    $display("Loading G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/DCIM_MACRO/mem/mac_weight_data.mem ...");
    $readmemh("G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/DCIM_MACRO/mem/mac_weight_data.mem", weight);
    $display("Loaded %0d blocks into weight", WEIGHT_BLOCKS);
end




localparam EXPECTED_CHANNEL_NUM = 32;
localparam EXPECTED_HEIGHT = 32;
localparam EXPECTED_WIDTH  = 32;
localparam EXPECTED_BLOCKS = 4;
localparam EXPECTED_BYTES  = 4 * 32;

reg [255:0] expected [0:3];

initial begin
    $display("Loading G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/DCIM_MACRO/mem/mac_expected_data.mem ...");
    $readmemh("G:/PKU/Yolo_on_FPGA/Architecture/YOLO rtl/DCIM_MACRO/mem/mac_expected_data.mem", expected);
    $display("Loaded %0d blocks into expected", EXPECTED_BLOCKS);
end


/* mem */

    reg [OBUF_BANDWIDTH - 1 : 0]        expected_data;
    reg [EXPECTED_BLOCKS - 1 : 0]        expected_true;
    reg                                  is_match;

    // =========================
    // 信号定义
    // =========================
    reg                           clk;
    reg                           rst_n;
    reg                           start;
    wire                          dcim_ready;

    reg  [ADDR_WIDTH-1:0]         wsrc_base_addr;
    reg  [ADDR_WIDTH-1:0]         asrc_base_addr;
    reg  [ADDR_WIDTH-1:0]         dst_addr;
    reg  [ADDR_WIDTH-1:0]         kernel_c;
    reg  [ADDR_WIDTH-1:0]         kernel_h;
    reg  [ADDR_WIDTH-1:0]         kernel_w;

    reg  [IBUF_BANDWIDTH/8-1:0]   ibuf_wea;
    reg  [IBUF_ADDR_WIDTH-1:0]    ibuf_addra;
    reg  [IBUF_BANDWIDTH-1:0]     ibuf_dina;
    reg                           ibuf_ena;
    wire [IBUF_BANDWIDTH-1:0]     ibuf_douta;

    reg  [IBUF_BANDWIDTH/8-1:0]   obuf_wea;
    reg  [IBUF_ADDR_WIDTH-1:0]    obuf_addra;
    reg  [IBUF_BANDWIDTH-1:0]     obuf_dina;
    reg                           obuf_ena;
    wire [IBUF_BANDWIDTH-1:0]     obuf_douta;

    integer i;
    wire        is_match_wire                 ;
    assign      is_match_wire = obuf_douta == expected_data;

    // =========================
    // DUT 实例化
    // =========================
    DCIM_Macro #(
        .WEIGHT_DW(WEIGHT_DW),
        .ACT_DW(ACT_DW),
        .OUT_DW(OUT_DW),
        .NUM_CELL(NUM_CELL),
        .NUM_CELL_PER_DCIM(NUM_CELL_PER_DCIM),
        .ADDR_WIDTH(ADDR_WIDTH),
        .IBUF_ADDR_WIDTH(IBUF_ADDR_WIDTH),
        .OBUF_ADDR_WIDTH(OBUF_ADDR_WIDTH),
        .IBUF_BANDWIDTH(IBUF_BANDWIDTH),
        .OBUF_BANDWIDTH(OBUF_BANDWIDTH),
        .RAM_NBPIPE(RAM_NBPIPE),
        .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .dcim_ready(dcim_ready),

        .wsrc_base_addr(wsrc_base_addr),
        .asrc_base_addr(asrc_base_addr),
        .dst_addr(dst_addr),
        .kernel_c(kernel_c),
        .kernel_h(kernel_h),
        .kernel_w(kernel_w),

        .ibuf_wea(ibuf_wea),
        .ibuf_addra(ibuf_addra),
        .ibuf_dina(ibuf_dina),
        .ibuf_ena(ibuf_ena),
        .ibuf_douta(ibuf_douta),

        .obuf_wea(obuf_wea),
        .obuf_addra(obuf_addra),
        .obuf_dina(obuf_dina),
        .obuf_ena(obuf_ena),
        .obuf_douta(obuf_douta)
    );

    // =========================
    // 简单测试逻辑
    // =========================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        expected_data = 0;
        expected_true = 0;
        is_match = 0;


        rst_n = 0;
        start = 0;
        wsrc_base_addr = 0;
        asrc_base_addr = WEIGHT_BYTES;
        dst_addr = 0;
        kernel_c = 0;
        kernel_h = 0;
        kernel_w = 0;
        ibuf_wea = 0;
        ibuf_addra = 0;
        ibuf_dina = 0;
        ibuf_ena = 0;
        obuf_wea = 0;
        obuf_addra = 0;
        obuf_dina = 0;
        obuf_ena = 0;
        #20 rst_n = 1;


        $display("[%0t] Start ibuf init (Port A writes)...", $time);
        ibuf_ena = 1'b1;
        for (i = 0; i < WEIGHT_BLOCKS; i = i + 1) begin
            @(posedge clk);
            ibuf_addra <= i[IBUF_ADDR_WIDTH-1:0] + (wsrc_base_addr >> 5);
            ibuf_dina  <= weight[i];
            ibuf_wea   <= {32{1'b1}}; // write all bytes
        end
        
        repeat(100)@(posedge clk);

        ibuf_ena = 1'b1;
        for (i = 0; i < ACT_BLOCKS; i = i + 1) begin
            @(posedge clk);
            ibuf_addra <= i[IBUF_ADDR_WIDTH-1:0] + (asrc_base_addr >> 5);
            ibuf_dina  <= act[i];
            ibuf_wea   <= {32{1'b1}}; // write all bytes
        end

        

        dst_addr = 0;
        kernel_c = WEIGHT_CHANNEL_NUM;
        kernel_h = WEIGHT_HEIGHT;
        kernel_w = WEIGHT_WIDTH;
        
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        #100;
        wait(dcim_ready);
        for (i = 0; i < EXPECTED_BLOCKS; i = i + 1) begin
            @(posedge clk);
            obuf_ena = 1'b1;
            obuf_wea = {32{1'b0}};  // 只读
            obuf_addra = (dst_addr >> 5 )+ i;
            repeat(10) @(posedge clk);
            expected_data = expected[i];
            expected_true[i] = obuf_douta == expected_data;
            is_match =  obuf_douta == expected_data;
            @(posedge clk);
            obuf_ena = 1'b0;
        end

        
    end

endmodule
