
//  vpu_buf.v - VPU 本地 Buffer (chip-v2 架构)
//  ============================================================================
//  4MB 双端口 URAM 存储，16 bank（复用 obuf_bank 参数化模块）
//  - Port A：VPU 读/写（同 SLR0，零跨越）
//  - Port B：AXI BRAM Controller 读/写（CDMA/XDMA 访问）
//  ============================================================================

`include "chip_defines.vh"

module vpu_buf (
    input clk,
    // Port A (VPU internal R/W)
    input [`DCIM_BUF_NUM_COL-1:0] wea,
    input mem_ena,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dina,
    input [`VPU_BUF_ADDR_WIDTH-1:0] addra,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] douta,
    output wire douta_valid,
    // Port B (AXI BRAM Controller R/W)
    input [`DCIM_BUF_NUM_COL-1:0] web,
    input mem_enb,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dinb,
    input [`VPU_BUF_ADDR_WIDTH-1:0] addrb,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] doutb
);

localparam BANK_BITS     = `VPU_BUF_BANK_BITS;
localparam BANK_ADDR_W   = `VPU_BUF_BANK_ADDR_WIDTH;
localparam NUM_BANKS     = `VPU_BUF_NUM_BANKS;
localparam NBPIPE        = `VPU_BUF_NBPIPE;
localparam DATA_WIDTH    = `DCIM_BUF_DATA_WIDTH;
localparam NUM_COL       = `DCIM_BUF_NUM_COL;

// 输入寄存（同 SLR，1 级）
reg [NUM_COL-1:0]              wea_reg;
reg                            mem_ena_reg;
reg [DATA_WIDTH-1:0]           dina_reg;
reg [`VPU_BUF_ADDR_WIDTH-1:0] addra_reg;

reg [NUM_COL-1:0]              web_reg;
reg                            mem_enb_reg;
reg [DATA_WIDTH-1:0]           dinb_reg;
reg [`VPU_BUF_ADDR_WIDTH-1:0] addrb_reg;

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

initial begin
    wea_reg = 0; mem_ena_reg = 0;
    web_reg = 0; mem_enb_reg = 0;
end

// Bank 选择
wire [BANK_BITS-1:0]    bank_sel_a = addra_reg[`VPU_BUF_ADDR_WIDTH-1 -: BANK_BITS];
wire [BANK_BITS-1:0]    bank_sel_b = addrb_reg[`VPU_BUF_ADDR_WIDTH-1 -: BANK_BITS];
wire [BANK_ADDR_W-1:0]  bank_addr_a = addra_reg[BANK_ADDR_W-1:0];
wire [BANK_ADDR_W-1:0]  bank_addr_b = addrb_reg[BANK_ADDR_W-1:0];

// 原始读取 debug（在需要时启用）
// `ifdef SIMULATION
// always @(posedge clk) begin
//     if (mem_ena_reg && ~|wea_reg)
//         $display("[%0t] VPU_BUF_RD: addra_reg=0x%0h bank=%0d bank_addr=0x%0h",
//                  $time, addra_reg, bank_sel_a, bank_addr_a);
// end
// `endif

// Bank 存储阵列
wire [DATA_WIDTH-1:0] bank_douta [0:NUM_BANKS-1];
wire [DATA_WIDTH-1:0] bank_doutb [0:NUM_BANKS-1];

genvar bank;
generate
    for (bank = 0; bank < NUM_BANKS; bank = bank + 1) begin : gen_banks
        wire bank_hit_a = mem_ena_reg && (bank_sel_a == bank);
        wire bank_hit_b = mem_enb_reg && (bank_sel_b == bank);

        obuf_bank #(
            .BANK_ADDR_WIDTH(BANK_ADDR_W),
            .DATA_WIDTH(DATA_WIDTH),
            .NUM_COL(NUM_COL),
            .COL_WIDTH(`DCIM_BUF_COL_WIDTH),
            .NBPIPE(NBPIPE)
        ) u_bank (
            .clk(clk),
            .wea(wea_reg),
            .mem_ena(bank_hit_a),
            .dina(dina_reg),
            .addra(bank_addr_a),
            .douta(bank_douta[bank]),
            .web(web_reg),
            .mem_enb(bank_hit_b),
            .dinb(dinb_reg),
            .addrb(bank_addr_b),
            .doutb(bank_doutb[bank])
        );
    end
endgenerate

// Bank 选择流水线（enable-gated：只有 en 为高时才锁存 bank_sel，避免空泡污染）
// 时序：
//   addra 发出 (N) → addra_reg (N+1) → obuf_bank memrega (N+2) → mem_pipe_a[0] (N+3)
//   → ... → mem_pipe_a[NBPIPE-1] (N+2+NBPIPE) → obuf_bank douta (N+3+NBPIPE)
//   → vpu_buf douta (N+4+NBPIPE)  [额外一级 MUX 寄存]
// read_en_pipe_a[NBPIPE] 在 (N+1+NBPIPE) 为高（早于 douta 3 拍）
// douta_valid 需要 read_en_pipe_a[NBPIPE] 再延 3 拍
reg [BANK_BITS-1:0] bank_sel_a_pipe [0:NBPIPE];
reg [BANK_BITS-1:0] bank_sel_b_pipe [0:NBPIPE];
reg read_en_pipe_a [0:NBPIPE];
reg read_en_pipe_b [0:NBPIPE];
reg douta_valid_r;
reg douta_valid_r0;
reg douta_valid_r1;
// Port B 延迟链（与 Port A 对称，供 doutb 门控使用）
reg doutb_valid_r0;
reg doutb_valid_r1;
// 在 r0 时刻锁存选中 bank 的数据，避免 burst 场景下 pipe 推进污染
reg [DATA_WIDTH-1:0] douta_mux_r0;
reg [DATA_WIDTH-1:0] doutb_mux_r0;

integer i;
always @(posedge clk) begin
    // stage 0: 仅在 read enable 有效时锁存当前 bank_sel
    if (mem_ena_reg && ~|wea_reg)
        bank_sel_a_pipe[0] <= bank_sel_a;
    if (mem_enb_reg && ~|web_reg)
        bank_sel_b_pipe[0] <= bank_sel_b;
    read_en_pipe_a[0]  <= mem_ena_reg && ~|wea_reg;
    read_en_pipe_b[0]  <= mem_enb_reg && ~|web_reg;
    // stages 1..NBPIPE: en-gated shift
    for (i = 1; i <= NBPIPE; i = i + 1) begin
        if (read_en_pipe_a[i-1])
            bank_sel_a_pipe[i] <= bank_sel_a_pipe[i-1];
        if (read_en_pipe_b[i-1])
            bank_sel_b_pipe[i] <= bank_sel_b_pipe[i-1];
    end
    for (i = 0; i < NBPIPE; i = i + 1) begin
        read_en_pipe_a[i+1] <= read_en_pipe_a[i];
        read_en_pipe_b[i+1] <= read_en_pipe_b[i];
    end
end

integer init_j;
initial begin
    douta = {DATA_WIDTH{1'b0}};
    doutb = {DATA_WIDTH{1'b0}};
    douta_valid_r0 = 1'b0;
    douta_valid_r1 = 1'b0;
    douta_valid_r  = 1'b0;
    doutb_valid_r0 = 1'b0;
    doutb_valid_r1 = 1'b0;
    douta_mux_r0   = {DATA_WIDTH{1'b0}};
    doutb_mux_r0   = {DATA_WIDTH{1'b0}};
    for (init_j = 0; init_j <= NBPIPE; init_j = init_j + 1) begin
        bank_sel_a_pipe[init_j] = 0;
        bank_sel_b_pipe[init_j] = 0;
        read_en_pipe_a[init_j] = 0;
        read_en_pipe_b[init_j] = 0;
    end
end

// r0: bank_douta/doutb 刚稳定（read_en_pipe[NBPIPE] 后 1 拍），锁存 MUX 结果
// r1: douta/doutb 更新（r0 后 1 拍，此时 r0 寄存器已稳定）
// valid: 向下游输出（r1 后 1 拍）
always @(posedge clk) douta_valid_r0 <= read_en_pipe_a[NBPIPE];
always @(posedge clk) douta_valid_r1 <= douta_valid_r0;
always @(posedge clk) douta_valid_r  <= douta_valid_r1;
assign douta_valid = douta_valid_r;

always @(posedge clk) doutb_valid_r0 <= read_en_pipe_b[NBPIPE];
always @(posedge clk) doutb_valid_r1 <= doutb_valid_r0;

// r0 时刻锁存 MUX 结果（此时 bank_sel_a_pipe[NBPIPE] 与 bank_douta 对齐）
always @(posedge clk) begin
    if (douta_valid_r0)
        douta_mux_r0 <= bank_douta[bank_sel_a_pipe[NBPIPE]];
    if (doutb_valid_r0)
        doutb_mux_r0 <= bank_doutb[bank_sel_b_pipe[NBPIPE]];
end

// MUX_R0 debug（在需要时启用）
// `ifdef SIMULATION
// always @(posedge clk) begin
//     if (douta_valid_r0)
//         $display("[%0t] VPU_BUF_MUX_R0: sel=%0d bank_douta=0x%0h",
//                  $time, bank_sel_a_pipe[NBPIPE], bank_douta[bank_sel_a_pipe[NBPIPE]]);
// end
// `endif

// r1 时刻将锁存结果推入 douta/doutb（输出寄存一拍，使 valid 与 data 同步）
always @(posedge clk) begin
    if (douta_valid_r1)
        douta <= douta_mux_r0;
    if (doutb_valid_r1)
        doutb <= doutb_mux_r0;
end

endmodule
