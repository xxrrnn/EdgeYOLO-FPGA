`timescale 1ns/1ns
// HBM stub for module_tb / e2e simulation.
//
// 升级版：内置 256-bit AXI SRAM，支持 CDMA 真实读写 HBM。
// - 4K × 256-bit = 128KB，覆盖 module_tb 所有 case（最大 feature ~3.4MB 分块后首层 ~16KB）
// - 支持 INCR burst（ARLEN/AWLEN up to 15），OKAY 响应
// - apb_complete_0=1（SmartConnect 认为 HBM ready）
// - CDMA 以 256-bit/beat 访问，最大 burst 16 beats = 512B；典型 feature map ≤ 16KB 约 32 burst
//
// 层次路径：dut.lite_i.hbm_0.mem[word_addr] 用于 backdoor preload

module lite_hbm_0_0 (
    input  wire         HBM_REF_CLK_0,
    input  wire         AXI_00_ACLK,
    input  wire         AXI_00_ARESET_N,
    // AR channel
    input  wire [32:0]  AXI_00_ARADDR,
    input  wire [1:0]   AXI_00_ARBURST,
    input  wire [5:0]   AXI_00_ARID,
    input  wire [3:0]   AXI_00_ARLEN,
    input  wire [2:0]   AXI_00_ARSIZE,
    input  wire         AXI_00_ARVALID,
    // AW channel
    input  wire [32:0]  AXI_00_AWADDR,
    input  wire [1:0]   AXI_00_AWBURST,
    input  wire [5:0]   AXI_00_AWID,
    input  wire [3:0]   AXI_00_AWLEN,
    input  wire [2:0]   AXI_00_AWSIZE,
    input  wire         AXI_00_AWVALID,
    // R/W data
    input  wire         AXI_00_RREADY,
    input  wire         AXI_00_BREADY,
    input  wire [255:0] AXI_00_WDATA,
    input  wire         AXI_00_WLAST,
    input  wire [31:0]  AXI_00_WSTRB,
    input  wire [31:0]  AXI_00_WDATA_PARITY,
    input  wire         AXI_00_WVALID,
    // APB
    input  wire         APB_0_PCLK,
    input  wire         APB_0_PRESET_N,
    // AR/AW ready
    output wire         AXI_00_ARREADY,
    output wire         AXI_00_AWREADY,
    // R channel
    output wire [31:0]  AXI_00_RDATA_PARITY,
    output wire [255:0] AXI_00_RDATA,
    output wire [5:0]   AXI_00_RID,
    output wire         AXI_00_RLAST,
    output wire [1:0]   AXI_00_RRESP,
    output wire         AXI_00_RVALID,
    // W ready / B channel
    output wire         AXI_00_WREADY,
    output wire [5:0]   AXI_00_BID,
    output wire [1:0]   AXI_00_BRESP,
    output wire         AXI_00_BVALID,
    // APB
    output wire         apb_complete_0,
    output wire         DRAM_0_STAT_CATTRIP,
    output wire [6:0]   DRAM_0_STAT_TEMP
);

    // 内部 SRAM：16K × 256-bit = 512KB
    // 覆盖 module_tb 所有 case：最大 conv_pipeline feature ~3.4MB（分块后首层 ~16KB），
    // concat 双路各 268KB（HBM_OFF_INPUT1=0x40000+12800B ≈ 268KB），合计 ≤ 512KB
    // backdoor 路径：dut.lite_i.hbm_0.mem[word_addr]
    localparam MEM_DEPTH = 16384;        // 256-bit words = 512KB
    localparam BYTE_PER_WORD = 32;       // 256-bit = 32 bytes
    localparam ADDR_BITS = $clog2(MEM_DEPTH);

    reg [255:0] mem [0:MEM_DEPTH-1];

    // 初始化全零：用 SV aggregate 初始化语法，避免大 for-loop 仿真事件风暴
    initial mem = '{default: 256'h0};

    // -----------------------------------------------------------------------
    localparam WS_IDLE = 0, WS_BURST = 1, WS_RESP = 2;
    reg [1:0]  ws = WS_IDLE;
    reg [32:0] aw_addr_r;
    reg [3:0]  aw_len_r;
    reg [5:0]  aw_id_r;
    reg [3:0]  aw_beat;

    reg aw_ready_r = 1'b1;
    reg w_ready_r  = 1'b0;
    reg b_valid_r  = 1'b0;
    reg [5:0] b_id_r = 6'b0;

    always @(posedge AXI_00_ACLK or negedge AXI_00_ARESET_N) begin
        if (!AXI_00_ARESET_N) begin
            ws         <= WS_IDLE;
            aw_ready_r <= 1'b1;
            w_ready_r  <= 1'b0;
            b_valid_r  <= 1'b0;
        end else begin
            case (ws)
                WS_IDLE: begin
                    b_valid_r <= 1'b0;
                    if (AXI_00_AWVALID && aw_ready_r) begin
                        aw_addr_r  <= AXI_00_AWADDR;
                        aw_len_r   <= AXI_00_AWLEN;
                        aw_id_r    <= AXI_00_AWID;
                        aw_beat    <= 4'd0;
                        aw_ready_r <= 1'b0;
                        w_ready_r  <= 1'b1;
                        ws         <= WS_BURST;
                    end
                end
                WS_BURST: begin
                    if (AXI_00_WVALID && w_ready_r) begin
                        // 写 SRAM（byte strobe 按 32B 粒度）
                        begin : do_write
                            integer i;
                            reg [ADDR_BITS-1:0] widx;
                            widx = (aw_addr_r + aw_beat * BYTE_PER_WORD) >> $clog2(BYTE_PER_WORD);
                            for (i = 0; i < 32; i++) begin
                                if (AXI_00_WSTRB[i])
                                    mem[widx][i*8 +: 8] <= AXI_00_WDATA[i*8 +: 8];
                            end
                        end
                        aw_beat <= aw_beat + 4'd1;
                        if (AXI_00_WLAST || aw_beat == aw_len_r) begin
                            w_ready_r <= 1'b0;
                            b_valid_r <= 1'b1;
                            b_id_r    <= aw_id_r;
                            ws        <= WS_RESP;
                        end
                    end
                end
                WS_RESP: begin
                    if (AXI_00_BREADY && b_valid_r) begin
                        b_valid_r  <= 1'b0;
                        aw_ready_r <= 1'b1;
                        ws         <= WS_IDLE;
                    end
                end
            endcase
        end
    end

    // -----------------------------------------------------------------------
    // Read path state machine
    // -----------------------------------------------------------------------
    localparam RS_IDLE = 0, RS_BURST = 1;
    reg [1:0]  rs = RS_IDLE;
    reg [32:0] ar_addr_r;
    reg [3:0]  ar_len_r;
    reg [5:0]  ar_id_r;
    reg [3:0]  ar_beat;

    reg        ar_ready_r = 1'b1;
    reg        r_valid_r  = 1'b0;
    reg        r_last_r   = 1'b0;
    reg [255:0] r_data_r  = 256'b0;
    reg [5:0]  r_id_r     = 6'b0;

    always @(posedge AXI_00_ACLK or negedge AXI_00_ARESET_N) begin
        if (!AXI_00_ARESET_N) begin
            rs         <= RS_IDLE;
            ar_ready_r <= 1'b1;
            r_valid_r  <= 1'b0;
            r_last_r   <= 1'b0;
        end else begin
            case (rs)
                RS_IDLE: begin
                    r_last_r <= 1'b0;
                    if (AXI_00_ARVALID && ar_ready_r) begin
                        ar_addr_r  <= AXI_00_ARADDR;
                        ar_len_r   <= AXI_00_ARLEN;
                        ar_id_r    <= AXI_00_ARID;
                        ar_beat    <= 4'd0;
                        ar_ready_r <= 1'b0;
                        // 第一拍直接驱动数据
                        r_data_r  <= mem[AXI_00_ARADDR >> $clog2(BYTE_PER_WORD)];
                        r_id_r    <= AXI_00_ARID;
                        r_valid_r <= 1'b1;
                        r_last_r  <= (AXI_00_ARLEN == 4'd0);
                        rs        <= RS_BURST;
                    end
                end
                RS_BURST: begin
                    if (AXI_00_RREADY && r_valid_r) begin
                        ar_beat <= ar_beat + 4'd1;
                        if (r_last_r) begin
                            r_valid_r  <= 1'b0;
                            ar_ready_r <= 1'b1;
                            rs         <= RS_IDLE;
                        end else begin
                            begin : do_read
                                reg [ADDR_BITS-1:0] ridx;
                                ridx = (ar_addr_r + (ar_beat + 1) * BYTE_PER_WORD) >> $clog2(BYTE_PER_WORD);
                                r_data_r <= mem[ridx];
                            end
                            r_last_r <= (ar_beat + 4'd1 == ar_len_r);
                        end
                    end
                end
            endcase
        end
    end

    // -----------------------------------------------------------------------
    // Output assignments
    // -----------------------------------------------------------------------
    assign AXI_00_ARREADY      = ar_ready_r;
    assign AXI_00_AWREADY      = aw_ready_r;
    assign AXI_00_RDATA_PARITY = 32'b0;
    assign AXI_00_RDATA        = r_data_r;
    assign AXI_00_RID          = r_id_r;
    assign AXI_00_RLAST        = r_last_r;
    assign AXI_00_RRESP        = 2'b0;   // OKAY
    assign AXI_00_RVALID       = r_valid_r;
    assign AXI_00_WREADY       = w_ready_r;
    assign AXI_00_BID          = b_id_r;
    assign AXI_00_BRESP        = 2'b0;   // OKAY
    assign AXI_00_BVALID       = b_valid_r;
    assign apb_complete_0      = 1'b1;
    assign DRAM_0_STAT_CATTRIP = 1'b0;
    assign DRAM_0_STAT_TEMP    = 7'b0;

    // 初始化全零（用 packed 方式避免大循环带来的仿真启动开销）
    // VCS 对 reg array 的 for-loop 0-time initial 在大容量时非常慢；
    // 改为系统任务方式：未被 backdoor 写入的区域在 CDMA 读时产生 0（寄存器默认值）
    // 实际上 concat/cdma_memtest 等 case 不使用 HBM，无需初始化；
    // conv_pipeline 等 case 通过 backdoor_load_memh128 精确初始化目标区域。

endmodule
