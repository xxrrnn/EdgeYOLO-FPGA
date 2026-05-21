
//  Xilinx UltraRAM True Dual Port Mode - Byte write with Multi-Bank Architecture
//  ============================================================================
//  优化版本：使用多 bank 并行结构减少 URAM 级联深度
//  
//  关键优化：
//  1. 多 Bank 并行：将大容量存储分成 NUM_BANKS 个独立 bank
//  2. 输入寄存器：在地址/使能/写使能路径上添加寄存器
//  3. 输出流水线：保持原有的 NBPIPE 级输出流水
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
// 输入寄存器
// ============================================================================
(* shreg_extract = "no" *) reg [NUM_COL-1:0] wea_reg;
(* shreg_extract = "no" *) reg mem_ena_reg;
(* shreg_extract = "no" *) reg [DWIDTH-1:0] dina_reg;
(* shreg_extract = "no" *) reg [AWIDTH-1:0] addra_reg;

(* shreg_extract = "no" *) reg [NUM_COL-1:0] web_reg;
(* shreg_extract = "no" *) reg mem_enb_reg;
(* shreg_extract = "no" *) reg [DWIDTH-1:0] dinb_reg;
(* shreg_extract = "no" *) reg [AWIDTH-1:0] addrb_reg;

always @(posedge clk) begin
    wea_reg    <= wea;
    mem_ena_reg <= mem_ena;
    dina_reg   <= dina;
    addra_reg  <= addra;
    
    web_reg    <= web;
    mem_enb_reg <= mem_enb;
    dinb_reg   <= dinb;
    addrb_reg  <= addrb;
end

// ============================================================================
// Bank 选择信号
// ============================================================================
wire [BANK_BITS-1:0] bank_sel_a = addra_reg[AWIDTH-1 -: BANK_BITS];
wire [BANK_BITS-1:0] bank_sel_b = addrb_reg[AWIDTH-1 -: BANK_BITS];
wire [BANK_AWIDTH-1:0] bank_addr_a = addra_reg[BANK_AWIDTH-1:0];
wire [BANK_AWIDTH-1:0] bank_addr_b = addrb_reg[BANK_AWIDTH-1:0];

// ============================================================================
// 多 Bank 存储阵列
// ============================================================================
wire [DWIDTH-1:0] bank_douta [0:NUM_BANKS-1];
wire [DWIDTH-1:0] bank_doutb [0:NUM_BANKS-1];

genvar bank;
generate
    for (bank = 0; bank < NUM_BANKS; bank = bank + 1) begin : gen_banks
        wire bank_ena = mem_ena_reg && (bank_sel_a == bank);
        wire bank_enb = mem_enb_reg && (bank_sel_b == bank);
        
        obuf_bank #(
            .AWIDTH(BANK_AWIDTH),
            .NUM_COL(NUM_COL),
            .DWIDTH(DWIDTH),
            .NBPIPE(NBPIPE)
        ) u_bank (
            .clk(clk),
            .wea(wea_reg),
            .mem_ena(bank_ena),
            .dina(dina_reg),
            .addra(bank_addr_a),
            .douta(bank_douta[bank]),
            .web(web_reg),
            .mem_enb(bank_enb),
            .dinb(dinb_reg),
            .addrb(bank_addr_b),
            .doutb(bank_doutb[bank])
        );
    end
endgenerate

// ============================================================================
// Bank 选择流水线
// ============================================================================
localparam TOTAL_PIPE = NBPIPE + 2;

(* shreg_extract = "no" *) reg [BANK_BITS-1:0] bank_sel_a_pipe [0:TOTAL_PIPE-1];
(* shreg_extract = "no" *) reg [BANK_BITS-1:0] bank_sel_b_pipe [0:TOTAL_PIPE-1];

integer i;
always @(posedge clk) begin
    bank_sel_a_pipe[0] <= bank_sel_a;
    bank_sel_b_pipe[0] <= bank_sel_b;
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
