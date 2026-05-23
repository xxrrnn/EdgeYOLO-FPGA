
//  Xilinx UltraRAM True Dual Port Mode - Byte write with Multi-Bank Architecture
//  ============================================================================
//  优化版本 v2：双级输入寄存器（中心 reg1 → per-bank reg2）以收敛时序
//
//  关键优化：
//  1. 多 Bank 并行：将大容量存储分成 NUM_BANKS 个独立 bank
//  2. 双级输入寄存器：
//     - reg1（中心，1 份）：吸收上游长 routing（含 SLR 跨越）
//     - reg2（per-bank，N 份）：被 Vivado 放置到各 bank URAM cascade 起点附近，
//       彻底打断 "中心 reg → 远端 URAM cascade 末端" 这条 -2 ns 失败路径
//  3. 输出流水线：保持原有的 NBPIPE 级输出流水，bank 选择 pipeline 长度 +1
//  ============================================================================
//
//  时序契约（重要）：
//  - 写延迟：从 wea/dina/addra/mem_ena 输入到末端 URAM 实际写入完成
//      = 2 拍 (IN_REG1 + IN_REG2) + URAM 内部 cascade 传播
//    写为 fire-and-forget，外部无需感知。
//  - 读延迟：从 mem_ena 输入到 douta 出 = IN_REG1 + IN_REG2 + memrega + NBPIPE + douta
//      = 1 + 1 + 1 + NBPIPE + 1 = NBPIPE + 4
//    当 NBPIPE=2 时为 6 拍。原 v1 为 5 拍，**调用方需相应放宽等待**
//    （im2col_unit.READ_LATENCY 已从 9 → 10）。
//  ============================================================================

module obuf #(
  parameter AWIDTH   = 14,  // Address Width
  parameter NUM_COL  = 16,  // Number of columns (bytes)
  parameter DWIDTH   = 128, // Data Width
  parameter NBPIPE   = 3,   // Number of pipeline Registers
  parameter NUM_BANKS = 4   // Number of parallel banks
) (
    input clk,
    // Port A (External AXI interface)
    input [NUM_COL-1:0] wea,
    input mem_ena,
    input [DWIDTH-1:0] dina,
    input [AWIDTH-1:0] addra,
    output reg [DWIDTH-1:0] douta,
    // Port B (Internal Tile write interface)
    input [NUM_COL-1:0] web,
    input mem_enb,
    input [DWIDTH-1:0] dinb,
    input [AWIDTH-1:0] addrb,
    output reg [DWIDTH-1:0] doutb
);

// ============================================================================
// 参数计算
// ============================================================================
localparam BANK_BITS = $clog2(NUM_BANKS);
localparam BANK_AWIDTH = AWIDTH - BANK_BITS;
localparam CWIDTH = DWIDTH / NUM_COL;

// ============================================================================
// 第 1 级输入寄存器（中心，1 份）
// 作用：吸收上游 routing 与 SLR 跨越延迟
// ============================================================================
(* shreg_extract = "no" *) reg [NUM_COL-1:0] wea_reg;
(* shreg_extract = "no" *) reg               mem_ena_reg;
(* shreg_extract = "no" *) reg [DWIDTH-1:0]  dina_reg;
(* shreg_extract = "no" *) reg [AWIDTH-1:0]  addra_reg;

(* shreg_extract = "no" *) reg [NUM_COL-1:0] web_reg;
(* shreg_extract = "no" *) reg               mem_enb_reg;
(* shreg_extract = "no" *) reg [DWIDTH-1:0]  dinb_reg;
(* shreg_extract = "no" *) reg [AWIDTH-1:0]  addrb_reg;

always @(posedge clk) begin
    wea_reg     <= wea;
    mem_ena_reg <= mem_ena;
    dina_reg    <= dina;
    addra_reg   <= addra;

    web_reg     <= web;
    mem_enb_reg <= mem_enb;
    dinb_reg    <= dinb;
    addrb_reg   <= addrb;
end

// NOTE: wea_reg/web_reg must start at 0 on power-on to avoid phantom writes.
// obuf_bank's write operations are gated by mem_ena AND wea. If wea_reg is X,
// it could trigger writes. Declare initial values:
initial begin
    wea_reg     = 0;
    mem_ena_reg = 0;
    web_reg     = 0;
    mem_enb_reg = 0;
end

// 第 1 级的 bank 选择（用 reg 后的 addr 算）
wire [BANK_BITS-1:0]    bank_sel_a_q1 = addra_reg[AWIDTH-1 -: BANK_BITS];
wire [BANK_BITS-1:0]    bank_sel_b_q1 = addrb_reg[AWIDTH-1 -: BANK_BITS];
wire [BANK_AWIDTH-1:0]  bank_addr_a_q1 = addra_reg[BANK_AWIDTH-1:0];
wire [BANK_AWIDTH-1:0]  bank_addr_b_q1 = addrb_reg[BANK_AWIDTH-1:0];

// ============================================================================
// 多 Bank 存储阵列（每 bank 内嵌第 2 级输入寄存器）
// ============================================================================
wire [DWIDTH-1:0] bank_douta [0:NUM_BANKS-1];
wire [DWIDTH-1:0] bank_doutb [0:NUM_BANKS-1];

genvar bank;
generate
    for (bank = 0; bank < NUM_BANKS; bank = bank + 1) begin : gen_banks
        // 第 1 级 bank 命中信号（参与第 2 级的 mem_ena 计算）
        wire bank_hit_a_q1 = mem_ena_reg && (bank_sel_a_q1 == bank);
        wire bank_hit_b_q1 = mem_enb_reg && (bank_sel_b_q1 == bank);

        // 第 2 级 per-bank 输入寄存器（综合后会被放在该 bank URAM cascade 附近）
        (* shreg_extract = "no" *) reg [NUM_COL-1:0]      wea_reg2;
        (* shreg_extract = "no" *) reg                    mem_ena_reg2;
        (* shreg_extract = "no" *) reg [DWIDTH-1:0]       dina_reg2;
        (* shreg_extract = "no" *) reg [BANK_AWIDTH-1:0]  addra_reg2;

        (* shreg_extract = "no" *) reg [NUM_COL-1:0]      web_reg2;
        (* shreg_extract = "no" *) reg                    mem_enb_reg2;
        (* shreg_extract = "no" *) reg [DWIDTH-1:0]       dinb_reg2;
        (* shreg_extract = "no" *) reg [BANK_AWIDTH-1:0]  addrb_reg2;

        initial begin
            wea_reg2 = 0; mem_ena_reg2 = 0;
            web_reg2 = 0; mem_enb_reg2 = 0;
        end
        always @(posedge clk) begin
            wea_reg2     <= wea_reg;
            dina_reg2    <= dina_reg;
            addra_reg2   <= bank_addr_a_q1;
            mem_ena_reg2 <= bank_hit_a_q1;

            web_reg2     <= web_reg;
            dinb_reg2    <= dinb_reg;
            addrb_reg2   <= bank_addr_b_q1;
            mem_enb_reg2 <= bank_hit_b_q1;
        end

        obuf_bank #(
            .AWIDTH(BANK_AWIDTH),
            .NUM_COL(NUM_COL),
            .DWIDTH(DWIDTH),
            .NBPIPE(NBPIPE)
        ) u_bank (
            .clk(clk),
            .wea(wea_reg2),
            .mem_ena(mem_ena_reg2),
            .dina(dina_reg2),
            .addra(addra_reg2),
            .douta(bank_douta[bank]),
            .web(web_reg2),
            .mem_enb(mem_enb_reg2),
            .dinb(dinb_reg2),
            .addrb(addrb_reg2),
            .doutb(bank_doutb[bank])
        );
    end
endgenerate

// ============================================================================
// Bank 选择流水线（相比 v1 多 1 拍，匹配新增的 reg2）
// ============================================================================
// 读路径总延迟（端到端）：
//   IN_REG1 (1) + IN_REG2 (1) + memrega (1) + NBPIPE + douta (1) = NBPIPE + 4
// bank_sel pipe 用于追踪某个读请求最后落在哪个 bank 的输出 mux 上：
//   IN_REG1 已用 bank_sel_a_q1（来自 addra_reg），后续需要再 pipe NBPIPE+3 拍
//   到达最终 output mux（douta）
localparam TOTAL_PIPE = NBPIPE + 3;

(* shreg_extract = "no" *) reg [BANK_BITS-1:0] bank_sel_a_pipe [0:TOTAL_PIPE-1];
(* shreg_extract = "no" *) reg [BANK_BITS-1:0] bank_sel_b_pipe [0:TOTAL_PIPE-1];

integer i;
always @(posedge clk) begin
    bank_sel_a_pipe[0] <= bank_sel_a_q1;
    bank_sel_b_pipe[0] <= bank_sel_b_q1;
    for (i = 1; i < TOTAL_PIPE; i = i + 1) begin
        bank_sel_a_pipe[i] <= bank_sel_a_pipe[i-1];
        bank_sel_b_pipe[i] <= bank_sel_b_pipe[i-1];
    end
end

// ============================================================================
// 输出多路选择器
// ============================================================================
always @(posedge clk) begin
    douta <= bank_douta[bank_sel_a_pipe[TOTAL_PIPE-1]];
    doutb <= bank_doutb[bank_sel_b_pipe[TOTAL_PIPE-1]];
end

endmodule


// ============================================================================
// obuf_bank - 单个 Bank 的 URAM 存储模块
// ============================================================================
module obuf_bank #(
  parameter AWIDTH  = 12,
  parameter NUM_COL = 16,
  parameter DWIDTH  = 128,
  parameter NBPIPE  = 3
) (
    input clk,
    input [NUM_COL-1:0] wea,
    input mem_ena,
    input [DWIDTH-1:0] dina,
    input [AWIDTH-1:0] addra,
    output reg [DWIDTH-1:0] douta,
    input [NUM_COL-1:0] web,
    input mem_enb,
    input [DWIDTH-1:0] dinb,
    input [AWIDTH-1:0] addrb,
    output reg [DWIDTH-1:0] doutb
);

localparam CWIDTH = DWIDTH / NUM_COL;

(* ram_style = "ultra" *)
reg [DWIDTH-1:0] mem [(1<<AWIDTH)-1:0];

// Initialize mem to 0 to avoid X propagation in simulation.
// On actual FPGA, URAM is initialized to 0 by configuration bitstream.
integer mem_init_i;
initial begin
    for (mem_init_i = 0; mem_init_i < (1<<AWIDTH); mem_init_i = mem_init_i + 1)
        mem[mem_init_i] = {DWIDTH{1'b0}};
end

reg [DWIDTH-1:0] memrega;
reg [DWIDTH-1:0] mem_pipe_rega [NBPIPE-1:0];
reg mem_en_pipe_rega [NBPIPE:0];

reg [DWIDTH-1:0] memregb;
reg [DWIDTH-1:0] mem_pipe_regb [NBPIPE-1:0];
reg mem_en_pipe_regb [NBPIPE:0];

integer i;

// Port A 写操作
always @(posedge clk) begin
    if (mem_ena) begin
        for (i = 0; i < NUM_COL; i = i + 1) begin
            if (wea[i])
                mem[addra][i*CWIDTH +: CWIDTH] <= dina[i*CWIDTH +: CWIDTH];
        end
    end
end

// Port A 读操作
always @(posedge clk) begin
    if (mem_ena && ~|wea)
        memrega <= mem[addra];
end

always @(posedge clk) begin
    mem_en_pipe_rega[0] <= mem_ena && ~|wea;
    for (i = 0; i < NBPIPE; i = i + 1)
        mem_en_pipe_rega[i+1] <= mem_en_pipe_rega[i];
end

always @(posedge clk) begin
    if (mem_en_pipe_rega[0])
        mem_pipe_rega[0] <= memrega;
end

always @(posedge clk) begin
    for (i = 0; i < NBPIPE-1; i = i + 1) begin
        if (mem_en_pipe_rega[i+1])
            mem_pipe_rega[i+1] <= mem_pipe_rega[i];
    end
end

always @(posedge clk) begin
    if (mem_en_pipe_rega[NBPIPE])
        douta <= mem_pipe_rega[NBPIPE-1];
end

// Port B 写操作
always @(posedge clk) begin
    if (mem_enb) begin
        for (i = 0; i < NUM_COL; i = i + 1) begin
            if (web[i])
                mem[addrb][i*CWIDTH +: CWIDTH] <= dinb[i*CWIDTH +: CWIDTH];
        end
    end
end

// Port B 读操作
always @(posedge clk) begin
    if (mem_enb && ~|web)
        memregb <= mem[addrb];
end

always @(posedge clk) begin
    mem_en_pipe_regb[0] <= mem_enb && ~|web;
    for (i = 0; i < NBPIPE; i = i + 1)
        mem_en_pipe_regb[i+1] <= mem_en_pipe_regb[i];
end

always @(posedge clk) begin
    if (mem_en_pipe_regb[0])
        mem_pipe_regb[0] <= memregb;
end

always @(posedge clk) begin
    for (i = 0; i < NBPIPE-1; i = i + 1) begin
        if (mem_en_pipe_regb[i+1])
            mem_pipe_regb[i+1] <= mem_pipe_regb[i];
    end
end

always @(posedge clk) begin
    if (mem_en_pipe_regb[NBPIPE])
        doutb <= mem_pipe_regb[NBPIPE-1];
end

endmodule
