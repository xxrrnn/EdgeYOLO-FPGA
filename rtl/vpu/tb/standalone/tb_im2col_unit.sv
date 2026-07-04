`timescale 1ns/1ps

// ============================================================================
// tb_im2col_unit - im2col_unit 功能验证 testbench
// ============================================================================
// 测试策略：
//   1. 用随机数据填充 OBUF（模拟 feature map NHWC 布局）
//   2. 配置 im2col_unit 参数（来自 network.json 某层）
//   3. 启动 im2col_unit
//   4. 等待 done
//   5. 从 OBUF 读出 im2col 结果，dump 到文件
//   6. Python 脚本对比验证
// ============================================================================

module tb_im2col_unit;

    parameter ADDR_WIDTH    = 32;
    parameter VB_BANDWIDTH  = 128;
    parameter VPU_ADDR_WIDTH = 24;
    parameter FP_WIDTH      = 32;

    // 测试配置（model.1.conv: CH_IN=16, 3×3, stride=2, padding=1, H=160, W=160）
    localparam CH_IN   = 16;
    localparam H       = 8;   // 缩小尺寸加速仿真
    localparam W       = 8;
    localparam KH      = 3;
    localparam KW      = 3;
    localparam STRIDE  = 2;
    localparam PAD     = 1;
    localparam OH      = (H + 2*PAD - KH) / STRIDE + 1;  // 4
    localparam OW      = (W + 2*PAD - KW) / STRIDE + 1;  // 4

    localparam SRC_ADDR = 24'h000000;  // feature 起始字节地址
    localparam DST_ADDR = 24'h010000;  // im2col 输出起始字节地址

    // addr_break 打包
    localparam [31:0] ADDR_BREAK = {KH[7:0], KW[7:0], STRIDE[3:0], STRIDE[3:0], PAD[3:0], PAD[3:0]};

    // OBUF 大小（128-bit word = 16 bytes）
    localparam OBUF_DEPTH = 1 << 17;  // 128K words = 2MB

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    reg clk, rst_n;
    initial clk = 0;
    always #2 clk = ~clk;  // 250 MHz

    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end

    // =========================================================================
    // OBUF 模拟（dual port RAM）
    // =========================================================================
    reg [VB_BANDWIDTH-1:0] obuf_mem [0:OBUF_DEPTH-1];

    // DUT 接口
    wire [VPU_ADDR_WIDTH-1:0]      gb_addrb;
    wire [VB_BANDWIDTH-1:0]       gb_dinb;
    wire [VB_BANDWIDTH/8-1:0]     gb_web;
    wire                          gb_enb;
    reg  [VB_BANDWIDTH-1:0]       gb_doutb;
    reg                           gb_doutb_valid;

    // OBUF 模拟读写
    wire [VPU_ADDR_WIDTH-5:0] obuf_word_addr = gb_addrb >> 4;  // 字节地址 >> 4 = 128-bit 字地址
    reg                        gb_read_pending;

    always @(posedge clk) begin
        gb_doutb_valid <= 1'b0;
        if (gb_enb) begin
            if (|gb_web) begin
                // 写操作
                integer i;
                for (i = 0; i < VB_BANDWIDTH/8; i = i + 1) begin
                    if (gb_web[i])
                        obuf_mem[obuf_word_addr][i*8 +: 8] <= gb_dinb[i*8 +: 8];
                end
            end else begin
                gb_read_pending <= 1'b1;
            end
        end
        if (gb_read_pending) begin
            gb_doutb        <= obuf_mem[obuf_word_addr];
            gb_doutb_valid  <= 1'b1;
            gb_read_pending <= 1'b0;
        end
    end

    // =========================================================================
    // DUT
    // =========================================================================
    reg  im2col_start;
    wire im2col_ready;

    reg [ADDR_WIDTH-1:0] cfg_src_addr, cfg_dst_addr, cfg_src_c, cfg_src_h, cfg_src_w;
    reg [ADDR_WIDTH-1:0] cfg_addr_break, cfg_addr_s, cfg_addr_t;

    im2col_unit #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .VB_BANDWIDTH(VB_BANDWIDTH),
        .VPU_ADDR_WIDTH(VPU_ADDR_WIDTH),
        .FP_WIDTH(FP_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .im2col_unit_start(im2col_start),
        .im2col_unit_ready(im2col_ready),
        .im2col_src_addr(cfg_src_addr),
        .im2col_dst_addr(cfg_dst_addr),
        .im2col_src_c(cfg_src_c),
        .im2col_src_h(cfg_src_h),
        .im2col_src_w(cfg_src_w),
        .im2col_addr_break(cfg_addr_break),
        .im2col_addr_s(cfg_addr_s),
        .im2col_addr_t(cfg_addr_t),
        .gb_addrb(gb_addrb),
        .gb_dinb(gb_dinb),
        .gb_web(gb_web),
        .gb_enb(gb_enb),
        .gb_doutb(gb_doutb),
        .gb_doutb_valid(gb_doutb_valid)
    );

    // =========================================================================
    // 测试流程
    // =========================================================================
    integer i, j, k, fd;
    reg [7:0] pixel_val;

    initial begin
        im2col_start = 0;
        cfg_src_addr = SRC_ADDR;
        cfg_dst_addr = DST_ADDR;
        cfg_src_c    = CH_IN;
        cfg_src_h    = H;
        cfg_src_w    = W;
        cfg_addr_break = ADDR_BREAK;
        cfg_addr_s   = OH;
        cfg_addr_t   = OW;

        // 初始化 OBUF 为 0
        for (i = 0; i < OBUF_DEPTH; i = i + 1)
            obuf_mem[i] = 0;

        // 填充 feature map 到 OBUF（NHWC: feature[h][w][c]）
        // 每像素 CH_IN bytes，地址 = SRC_ADDR + (h*W + w)*CH_IN + c
        for (i = 0; i < H; i = i + 1) begin
            for (j = 0; j < W; j = j + 1) begin
                for (k = 0; k < CH_IN; k = k + 1) begin
                    pixel_val = ((i * W + j) * CH_IN + k) & 8'hFF;
                    // 写入 OBUF：地址 = SRC_ADDR + pixel_byte_offset
                    // 字节地址 → word_addr[19:0] = byte_addr >> 4
                    // byte_in_word = byte_addr & 0xF
                    begin
                        integer byte_addr, word_idx, byte_in_word;
                        byte_addr = SRC_ADDR + (i*W + j)*CH_IN + k;
                        word_idx = byte_addr >> 4;
                        byte_in_word = byte_addr & 4'hF;
                        obuf_mem[word_idx][byte_in_word*8 +: 8] = pixel_val;
                    end
                end
            end
        end
        $display("Feature map loaded: H=%0d W=%0d CH_IN=%0d", H, W, CH_IN);

        // 等 reset 完成
        @(posedge rst_n);
        repeat(5) @(posedge clk);

        // 启动 im2col
        $display("Starting im2col: kH=%0d kW=%0d stride=%0d pad=%0d OH=%0d OW=%0d",
                 KH, KW, STRIDE, PAD, OH, OW);
        im2col_start = 1;
        @(posedge clk);
        im2col_start = 0;

        // 等待完成
        wait(im2col_ready == 1);
        repeat(10) @(posedge clk);
        $display("im2col done!");

        // dump 输入 feature 和输出 im2col 到文件
        fd = $fopen("tb_im2col_input.hex", "w");
        for (i = 0; i < (H * W * CH_IN + 15) / 16; i = i + 1) begin
            $fwrite(fd, "%032h\n", obuf_mem[(SRC_ADDR >> 4) + i]);
        end
        $fclose(fd);

        fd = $fopen("tb_im2col_output.hex", "w");
        for (i = 0; i < (OH * OW * KH * KW * CH_IN + 15) / 16; i = i + 1) begin
            $fwrite(fd, "%032h\n", obuf_mem[(DST_ADDR >> 4) + i]);
        end
        $fclose(fd);
        $display("Output dumped to tb_im2col_output.hex");

        // 简单 self-check：验证第一个输出像素 (oh=0,ow=0)
        // 该像素 kernel 位置 (kh=0,kw=0): ih=-1, iw=-1 → padding → 应该全 0
        begin
            integer first_word_addr;
            first_word_addr = DST_ADDR >> 4;
            if (obuf_mem[first_word_addr] == 0)
                $display("PASS: First pixel (pad area) is zero");
            else
                $display("FAIL: First pixel expected 0, got %h", obuf_mem[first_word_addr]);
        end

        // kernel 位置 (kh=1,kw=1): ih=0, iw=0 → feature[0][0][0:15]
        begin
            integer check_word_addr, expected_byte_addr;
            expected_byte_addr = DST_ADDR + (0*OW + 0)*(KH*KW*CH_IN) + (1*KW + 1)*CH_IN;
            check_word_addr = expected_byte_addr >> 4;
            if (obuf_mem[check_word_addr] == obuf_mem[SRC_ADDR >> 4])
                $display("PASS: (oh=0,ow=0,kh=1,kw=1) matches feature[0][0]");
            else
                $display("FAIL: Expected %h, got %h",
                         obuf_mem[SRC_ADDR >> 4], obuf_mem[check_word_addr]);
        end

        $display("Simulation complete.");
        $finish;
    end

    // Timeout
    initial begin
        #1000000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
