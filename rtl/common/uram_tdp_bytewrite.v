`timescale 1ns / 1ns
// ============================================================================
// uram_tdp_bytewrite.v  —  Xilinx UltraRAM True Dual Port, Byte-Write
// ============================================================================
// 参考 Xilinx UG573 / PG058 URAM byte-write 示例编码，综合直接映射到 URAM，
// 仿真行为与综合完全一致（无需 ifdef SIMULATION 分支）。
//
// 读模式：No-Change（写时不更新读输出寄存器）
// 延迟：NBPIPE + 2 拍
//   ∙ 第 1 拍：mem[addr] → memreg（无流水时直接捕获）
//   ∙ 第 2..NBPIPE+1 拍：流水线寄存器
//   ∙ 第 NBPIPE+2 拍：dout 寄存器
// 典型使用：NBPIPE=8 → 10 拍延迟
//
// Port A/B 均支持 byte-enable 写；read 只在 ~|we 时更新输出流水。
// ============================================================================

module uram_tdp_bytewrite #(
    parameter AWIDTH  = 12,   // 地址位宽
    parameter NUM_COL = 16,   // byte-enable 列数（byte 粒度 = DWIDTH/8）
    parameter DWIDTH  = 128,  // 数据位宽 = NUM_COL × COL_WIDTH
    parameter NBPIPE  = 8     // 额外流水级数；总延迟 = NBPIPE + 2
) (
    input  wire              clk,
    // Port A
    input  wire [NUM_COL-1:0] wea,
    input  wire               mem_ena,
    input  wire [DWIDTH-1:0]  dina,
    input  wire [AWIDTH-1:0]  addra,
    output reg  [DWIDTH-1:0]  douta,
    // Port B
    input  wire [NUM_COL-1:0] web,
    input  wire               mem_enb,
    input  wire [DWIDTH-1:0]  dinb,
    input  wire [AWIDTH-1:0]  addrb,
    output reg  [DWIDTH-1:0]  doutb
);

    localparam COL_WIDTH = DWIDTH / NUM_COL;  // 每个 byte-enable 列的宽度（= 8）
    localparam DEPTH     = 1 << AWIDTH;

    // -----------------------------------------------------------------------
    // 内存阵列（综合：推断为 URAM；仿真：普通 reg 数组）
    // -----------------------------------------------------------------------
    (* ram_style = "ultra" *)
    reg [DWIDTH-1:0] mem [0:DEPTH-1];

    integer i, j;

    // -----------------------------------------------------------------------
    // Port A：byte-enable 写 + no-change 读捕获
    // -----------------------------------------------------------------------
    reg [DWIDTH-1:0] memrega;

    always @(posedge clk) begin
        if (mem_ena) begin
            for (i = 0; i < NUM_COL; i = i + 1)
                if (wea[i])
                    mem[addra][i*COL_WIDTH +: COL_WIDTH] <= dina[i*COL_WIDTH +: COL_WIDTH];
            if (~|wea)
                memrega <= mem[addra];
        end
    end

    // Port A 使能流水
    // 使用 mem_ena（不含 |wea 归约）：保持 CE 路径为单比特 FDRE，
    // 避免 Vivado 将 CE 转为 URAM DOUT→FDRE.D 的 LUT MUX（会增加 6~8 逻辑级，
    // 叠加 7 级 URAM cascade 后 data path 超出 4ns 周期导致 timing violation）。
    // douta_valid 的正确性（写时不置 1）由上层 vpu_buf.v 的 rd_valid_pipe_a
    // 单独保证（mem_ena & ~wr_en_a），此处无需在 pipeline CE 中过滤写操作。
    reg [NBPIPE:0] men_pipe_a;
    always @(posedge clk)
        men_pipe_a <= {men_pipe_a[NBPIPE-1:0], mem_ena};

    // Port A 数据流水
    reg [DWIDTH-1:0] dat_pipe_a [0:NBPIPE-1];
    always @(posedge clk) begin
        if (men_pipe_a[0])
            dat_pipe_a[0] <= memrega;
    end
    genvar gpa;
    generate
        for (gpa = 1; gpa < NBPIPE; gpa = gpa + 1) begin : gen_pipe_a
            always @(posedge clk)
                if (men_pipe_a[gpa])
                    dat_pipe_a[gpa] <= dat_pipe_a[gpa-1];
        end
    endgenerate

    always @(posedge clk)
        if (men_pipe_a[NBPIPE])
            douta <= dat_pipe_a[NBPIPE-1];

    // -----------------------------------------------------------------------
    // Port B：byte-enable 写 + no-change 读捕获
    // -----------------------------------------------------------------------
    reg [DWIDTH-1:0] memregb;

    always @(posedge clk) begin
        if (mem_enb) begin
            for (i = 0; i < NUM_COL; i = i + 1)
                if (web[i])
                    mem[addrb][i*COL_WIDTH +: COL_WIDTH] <= dinb[i*COL_WIDTH +: COL_WIDTH];
            if (~|web)
                memregb <= mem[addrb];
        end
    end

    // Port B 使能流水（同 Port A：使用 mem_enb，不含 |web 归约）
    reg [NBPIPE:0] men_pipe_b;
    always @(posedge clk)
        men_pipe_b <= {men_pipe_b[NBPIPE-1:0], mem_enb};

    // Port B 数据流水
    reg [DWIDTH-1:0] dat_pipe_b [0:NBPIPE-1];
    always @(posedge clk) begin
        if (men_pipe_b[0])
            dat_pipe_b[0] <= memregb;
    end
    genvar gpb;
    generate
        for (gpb = 1; gpb < NBPIPE; gpb = gpb + 1) begin : gen_pipe_b
            always @(posedge clk)
                if (men_pipe_b[gpb])
                    dat_pipe_b[gpb] <= dat_pipe_b[gpb-1];
        end
    endgenerate

    always @(posedge clk)
        if (men_pipe_b[NBPIPE])
            doutb <= dat_pipe_b[NBPIPE-1];

    // -----------------------------------------------------------------------
    // 仿真初始化（综合时 URAM 自动清零，此处在仿真中显式清零）
    // -----------------------------------------------------------------------
    initial begin
        for (j = 0; j < DEPTH; j = j + 1)
            mem[j] = {DWIDTH{1'b0}};
        douta    = {DWIDTH{1'b0}};
        doutb    = {DWIDTH{1'b0}};
        memrega  = {DWIDTH{1'b0}};
        memregb  = {DWIDTH{1'b0}};
        men_pipe_a = {(NBPIPE+1){1'b0}};
        men_pipe_b = {(NBPIPE+1){1'b0}};
        for (j = 0; j < NBPIPE; j = j + 1) begin
            dat_pipe_a[j] = {DWIDTH{1'b0}};
            dat_pipe_b[j] = {DWIDTH{1'b0}};
        end
    end

endmodule
