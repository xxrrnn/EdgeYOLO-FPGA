
//  tile_obuf.v - Per-Tile Output Buffer (chip-v2 架构)
//  ============================================================================
//  256KB 双端口 URAM 存储，4 bank（复用 obuf_bank 参数化模块）
//  - Port A：CDMA/AXI 读取（也支持写入）
//  - Port B：DCIM Tile 写入
//  与 Tile 位于同一 SLR，零跨越延迟。
//  ============================================================================

`include "chip_defines.vh"

module tile_obuf (
    input clk,
    // Port A (CDMA/AXI read, optional write)
    input [`DCIM_BUF_NUM_COL-1:0] wea,
    input mem_ena,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dina,
    input [`DCIM_TILE_OBUF_ADDR_WIDTH-1:0] addra,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] douta,
    output wire douta_valid,
    // Port B (Tile write interface)
    input [`DCIM_BUF_NUM_COL-1:0] web,
    input mem_enb,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dinb,
    input [`DCIM_TILE_OBUF_ADDR_WIDTH-1:0] addrb
);

localparam BANK_BITS     = `DCIM_TILE_OBUF_BANK_BITS;
localparam BANK_ADDR_W   = `DCIM_TILE_OBUF_BANK_ADDR_WIDTH;
localparam NUM_BANKS     = `DCIM_TILE_OBUF_NUM_BANKS;
localparam NBPIPE        = `DCIM_TILE_OBUF_NBPIPE;
localparam DATA_WIDTH    = `DCIM_BUF_DATA_WIDTH;
localparam NUM_COL       = `DCIM_BUF_NUM_COL;

// 输入寄存（同 SLR，1 级）
reg [NUM_COL-1:0]              wea_reg;
reg                            mem_ena_reg;
reg [DATA_WIDTH-1:0]           dina_reg;
reg [`DCIM_TILE_OBUF_ADDR_WIDTH-1:0] addra_reg;

reg [NUM_COL-1:0]              web_reg;
reg                            mem_enb_reg;
reg [DATA_WIDTH-1:0]           dinb_reg;
reg [`DCIM_TILE_OBUF_ADDR_WIDTH-1:0] addrb_reg;

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
wire [BANK_BITS-1:0]    bank_sel_a = addra_reg[`DCIM_TILE_OBUF_ADDR_WIDTH-1 -: BANK_BITS];
wire [BANK_BITS-1:0]    bank_sel_b = addrb_reg[`DCIM_TILE_OBUF_ADDR_WIDTH-1 -: BANK_BITS];
wire [BANK_ADDR_W-1:0]  bank_addr_a = addra_reg[BANK_ADDR_W-1:0];
wire [BANK_ADDR_W-1:0]  bank_addr_b = addrb_reg[BANK_ADDR_W-1:0];

// Bank 存储阵列（复用 obuf_bank）
wire [DATA_WIDTH-1:0] bank_douta [0:NUM_BANKS-1];

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
            .doutb()
        );
    end
endgenerate

// Bank 选择流水线（Port A 读）
reg [BANK_BITS-1:0] bank_sel_a_pipe [0:NBPIPE-1];
reg read_en_pipe [0:NBPIPE];

integer i;
always @(posedge clk) begin
    bank_sel_a_pipe[0] <= bank_sel_a;
    read_en_pipe[0]    <= mem_ena_reg && ~|wea_reg;
    for (i = 1; i < NBPIPE; i = i + 1)
        bank_sel_a_pipe[i] <= bank_sel_a_pipe[i-1];
    for (i = 0; i < NBPIPE; i = i + 1)
        read_en_pipe[i+1] <= read_en_pipe[i];
end

integer init_j;
initial begin
    douta = {DATA_WIDTH{1'b0}};
    for (init_j = 0; init_j < NBPIPE; init_j = init_j + 1)
        bank_sel_a_pipe[init_j] = 0;
    for (init_j = 0; init_j <= NBPIPE; init_j = init_j + 1)
        read_en_pipe[init_j] = 0;
end

assign douta_valid = read_en_pipe[NBPIPE];

always @(posedge clk) begin
    douta <= bank_douta[bank_sel_a_pipe[NBPIPE-1]];
end

endmodule
