
//  Xilinx UltraRAM True Dual Port Mode - Byte write with Multi-Bank Architecture
//  ============================================================================
//  优化版本：使用多 bank 并行结构减少 URAM 级联深度
//  
//  关键优化：
//  1. 多 Bank 并行：将大容量存储分成 NUM_BANKS 个独立 bank
//  2. 输入寄存器：在地址/使能/写使能路径上添加寄存器
//  3. 输出流水线：DCIM_IBUF_NBPIPE + DCIM_IBUF_BANK_SEL_PIPE_EXTRA → DCIM_IBUF_BANK_MUX_PIPE
//  参数统一见 rtl/chip/chip_defines.vh（勿在本模块再声明 parameter/localparam）
//  ============================================================================

`include "chip_defines.vh"

module ibuf (
    input clk,
    // Port A (External AXI interface - write)
    input [`DCIM_BUF_NUM_COL-1:0] wea,
    input mem_ena,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dina,
    input [`DCIM_IBUF_ADDR_WIDTH-1:0] addra,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] douta,
    // Port B (Internal Tile read interface)
    input [`DCIM_BUF_NUM_COL-1:0] web,
    input mem_enb,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dinb,
    input [`DCIM_IBUF_ADDR_WIDTH-1:0] addrb,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] doutb
);

// ============================================================================
// 输入寄存器
// ============================================================================
(* shreg_extract = "no" *) reg [`DCIM_BUF_NUM_COL-1:0] wea_reg;
(* shreg_extract = "no" *) reg mem_ena_reg;
(* shreg_extract = "no" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] dina_reg;
(* shreg_extract = "no" *) reg [`DCIM_IBUF_ADDR_WIDTH-1:0] addra_reg;

(* shreg_extract = "no" *) reg [`DCIM_BUF_NUM_COL-1:0] web_reg;
(* shreg_extract = "no" *) reg mem_enb_reg;
(* shreg_extract = "no" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] dinb_reg;
(* shreg_extract = "no" *) reg [`DCIM_IBUF_ADDR_WIDTH-1:0] addrb_reg;

// 内部信号
wire [`DCIM_BUF_NUM_COL-1:0] wea_int;
wire mem_ena_int;
wire [`DCIM_BUF_DATA_WIDTH-1:0] dina_int;
wire [`DCIM_IBUF_ADDR_WIDTH-1:0] addra_int;

wire [`DCIM_BUF_NUM_COL-1:0] web_int;
wire mem_enb_int;
wire [`DCIM_BUF_DATA_WIDTH-1:0] dinb_int;
wire [`DCIM_IBUF_ADDR_WIDTH-1:0] addrb_int;

generate
if (`DCIM_IBUF_IN_REG > 0) begin : gen_in_reg
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
    
    assign wea_int    = wea_reg;
    assign mem_ena_int = mem_ena_reg;
    assign dina_int   = dina_reg;
    assign addra_int  = addra_reg;
    
    assign web_int    = web_reg;
    assign mem_enb_int = mem_enb_reg;
    assign dinb_int   = dinb_reg;
    assign addrb_int  = addrb_reg;
end else begin : gen_no_in_reg
    assign wea_int    = wea;
    assign mem_ena_int = mem_ena;
    assign dina_int   = dina;
    assign addra_int  = addra;
    
    assign web_int    = web;
    assign mem_enb_int = mem_enb;
    assign dinb_int   = dinb;
    assign addrb_int  = addrb;
end
endgenerate

// ============================================================================
// Bank 选择信号
// ============================================================================
wire [`DCIM_IBUF_BANK_BITS-1:0] bank_sel_a = addra_int[`DCIM_IBUF_ADDR_WIDTH-1 -: `DCIM_IBUF_BANK_BITS];
wire [`DCIM_IBUF_BANK_BITS-1:0] bank_sel_b = addrb_int[`DCIM_IBUF_ADDR_WIDTH-1 -: `DCIM_IBUF_BANK_BITS];
wire [`DCIM_IBUF_BANK_ADDR_WIDTH-1:0] bank_addr_a = addra_int[`DCIM_IBUF_BANK_ADDR_WIDTH-1:0];
wire [`DCIM_IBUF_BANK_ADDR_WIDTH-1:0] bank_addr_b = addrb_int[`DCIM_IBUF_BANK_ADDR_WIDTH-1:0];

// ============================================================================
// 多 Bank 存储阵列
// ============================================================================
wire [`DCIM_BUF_DATA_WIDTH-1:0] bank_douta [0:`DCIM_IBUF_NUM_BANKS-1];
wire [`DCIM_BUF_DATA_WIDTH-1:0] bank_doutb [0:`DCIM_IBUF_NUM_BANKS-1];

genvar bank;
generate
    for (bank = 0; bank < `DCIM_IBUF_NUM_BANKS; bank = bank + 1) begin : gen_banks
        wire bank_ena = mem_ena_int && (bank_sel_a == bank);
        wire bank_enb = mem_enb_int && (bank_sel_b == bank);
        
        ibuf_bank u_bank (
            .clk(clk),
            .wea(wea_int),
            .mem_ena(bank_ena),
            .dina(dina_int),
            .addra(bank_addr_a),
            .douta(bank_douta[bank]),
            .web(web_int),
            .mem_enb(bank_enb),
            .dinb(dinb_int),
            .addrb(bank_addr_b),
            .doutb(bank_doutb[bank])
        );
    end
endgenerate

// ============================================================================
// Bank 选择流水线
// ============================================================================
(* shreg_extract = "no", max_fanout = 32 *) reg [`DCIM_IBUF_BANK_BITS-1:0] bank_sel_a_pipe [0:`DCIM_IBUF_BANK_MUX_PIPE-1];
(* shreg_extract = "no", max_fanout = 32 *) reg [`DCIM_IBUF_BANK_BITS-1:0] bank_sel_b_pipe [0:`DCIM_IBUF_BANK_MUX_PIPE-1];

integer i;
always @(posedge clk) begin
    bank_sel_a_pipe[0] <= bank_sel_a;
    bank_sel_b_pipe[0] <= bank_sel_b;
    for (i = 1; i < `DCIM_IBUF_BANK_MUX_PIPE; i = i + 1) begin
        bank_sel_a_pipe[i] <= bank_sel_a_pipe[i-1];
        bank_sel_b_pipe[i] <= bank_sel_b_pipe[i-1];
    end
end

// ============================================================================
// 输出多路选择器
// ============================================================================
always @(posedge clk) begin
    douta <= bank_douta[bank_sel_a_pipe[`DCIM_IBUF_BANK_MUX_PIPE-1]];
    doutb <= bank_doutb[bank_sel_b_pipe[`DCIM_IBUF_BANK_MUX_PIPE-1]];
end

endmodule


// ============================================================================
// ibuf_bank - 单个 Bank 的 URAM 存储模块
// ============================================================================
module ibuf_bank (
    input clk,
    input [`DCIM_BUF_NUM_COL-1:0] wea,
    input mem_ena,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dina,
    input [`DCIM_IBUF_BANK_ADDR_WIDTH-1:0] addra,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] douta,
    input [`DCIM_BUF_NUM_COL-1:0] web,
    input mem_enb,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dinb,
    input [`DCIM_IBUF_BANK_ADDR_WIDTH-1:0] addrb,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] doutb
);

(* ram_style = "ultra" *)
reg [`DCIM_BUF_DATA_WIDTH-1:0] mem [(1<<`DCIM_IBUF_BANK_ADDR_WIDTH)-1:0];

// Port A/B 读：单拍 mem[addr]→memrega + mem_rstage/NBPIPE（memrega 勿 DONT_TOUCH，见 obuf_bank）
reg [`DCIM_BUF_DATA_WIDTH-1:0] memrega;
(* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] mem_rstage_rega;
(* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] mem_pipe_rega [`DCIM_IBUF_NBPIPE-1:0];
reg mem_en_pipe_rega [`DCIM_IBUF_BANK_RD_EN_DEPTH:0];

reg [`DCIM_BUF_DATA_WIDTH-1:0] memregb;
(* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] mem_rstage_regb;
(* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] mem_pipe_regb [`DCIM_IBUF_NBPIPE-1:0];
reg mem_en_pipe_regb [`DCIM_IBUF_BANK_RD_EN_DEPTH:0];

integer i;

// Port A 写操作
always @(posedge clk) begin
    if (mem_ena) begin
        for (i = 0; i < `DCIM_BUF_NUM_COL; i = i + 1) begin
            if (wea[i])
                mem[addra][i*`DCIM_BUF_COL_WIDTH +: `DCIM_BUF_COL_WIDTH] <= dina[i*`DCIM_BUF_COL_WIDTH +: `DCIM_BUF_COL_WIDTH];
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
    for (i = 0; i < `DCIM_IBUF_BANK_RD_EN_DEPTH; i = i + 1)
        mem_en_pipe_rega[i+1] <= mem_en_pipe_rega[i];
end

always @(posedge clk) begin
    if (mem_en_pipe_rega[0])
        mem_rstage_rega <= memrega;
end

always @(posedge clk) begin
    if (mem_en_pipe_rega[1])
        mem_pipe_rega[0] <= mem_rstage_rega;
end

always @(posedge clk) begin
    for (i = 0; i < `DCIM_IBUF_NBPIPE-1; i = i + 1) begin
        if (mem_en_pipe_rega[i+2])
            mem_pipe_rega[i+1] <= mem_pipe_rega[i];
    end
end

always @(posedge clk) begin
    if (mem_en_pipe_rega[`DCIM_IBUF_BANK_RD_EN_DEPTH])
        douta <= mem_pipe_rega[`DCIM_IBUF_NBPIPE-1];
end

// Port B 写操作
always @(posedge clk) begin
    if (mem_enb) begin
        for (i = 0; i < `DCIM_BUF_NUM_COL; i = i + 1) begin
            if (web[i])
                mem[addrb][i*`DCIM_BUF_COL_WIDTH +: `DCIM_BUF_COL_WIDTH] <= dinb[i*`DCIM_BUF_COL_WIDTH +: `DCIM_BUF_COL_WIDTH];
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
    for (i = 0; i < `DCIM_IBUF_BANK_RD_EN_DEPTH; i = i + 1)
        mem_en_pipe_regb[i+1] <= mem_en_pipe_regb[i];
end

always @(posedge clk) begin
    if (mem_en_pipe_regb[0])
        mem_rstage_regb <= memregb;
end

always @(posedge clk) begin
    if (mem_en_pipe_regb[1])
        mem_pipe_regb[0] <= mem_rstage_regb;
end

always @(posedge clk) begin
    for (i = 0; i < `DCIM_IBUF_NBPIPE-1; i = i + 1) begin
        if (mem_en_pipe_regb[i+2])
            mem_pipe_regb[i+1] <= mem_pipe_regb[i];
    end
end

always @(posedge clk) begin
    if (mem_en_pipe_regb[`DCIM_IBUF_BANK_RD_EN_DEPTH])
        doutb <= mem_pipe_regb[`DCIM_IBUF_NBPIPE-1];
end

endmodule
