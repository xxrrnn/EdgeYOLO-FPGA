
//  obuf_bank.v - 参数化双端口 URAM Bank 模块 (chip-v2)
//  ============================================================================
//  通用 URAM bank：可被 tile_obuf / vpu_buf 实例化（不同 ADDR_WIDTH/NBPIPE）
//  - Port A: 读/写（AXI/VPU 访问）
//  - Port B: 读/写（Tile 写入 / AXI 访问）
//  ============================================================================

`include "chip_defines.vh"

module obuf_bank #(
    parameter BANK_ADDR_WIDTH = `DCIM_TILE_OBUF_BANK_ADDR_WIDTH,
    parameter DATA_WIDTH      = `DCIM_BUF_DATA_WIDTH,
    parameter NUM_COL         = `DCIM_BUF_NUM_COL,
    parameter COL_WIDTH       = `DCIM_BUF_COL_WIDTH,
    parameter NBPIPE          = `DCIM_TILE_OBUF_NBPIPE
)(
    input clk,
    // Port A
    input [NUM_COL-1:0] wea,
    input mem_ena,
    input [DATA_WIDTH-1:0] dina,
    input [BANK_ADDR_WIDTH-1:0] addra,
    output reg [DATA_WIDTH-1:0] douta,
    // Port B
    input [NUM_COL-1:0] web,
    input mem_enb,
    input [DATA_WIDTH-1:0] dinb,
    input [BANK_ADDR_WIDTH-1:0] addrb,
    output reg [DATA_WIDTH-1:0] doutb
);

(* ram_style = "ultra" *)
reg [DATA_WIDTH-1:0] mem [(1<<BANK_ADDR_WIDTH)-1:0];

integer mem_init_i;
initial begin
    for (mem_init_i = 0; mem_init_i < (1<<BANK_ADDR_WIDTH); mem_init_i = mem_init_i + 1)
        mem[mem_init_i] = {DATA_WIDTH{1'b0}};
end

// Port A 读/写
reg [DATA_WIDTH-1:0] memrega;
(* shreg_extract = "no" *) reg [DATA_WIDTH-1:0] mem_pipe_a [NBPIPE-1:0];
reg mem_en_pipe_a [NBPIPE:0];

// Port B 读/写
reg [DATA_WIDTH-1:0] memregb;
(* shreg_extract = "no" *) reg [DATA_WIDTH-1:0] mem_pipe_b [NBPIPE-1:0];
reg mem_en_pipe_b [NBPIPE:0];

integer i;

// Port A 写
always @(posedge clk) begin
    if (mem_ena) begin
        for (i = 0; i < NUM_COL; i = i + 1) begin
            if (wea[i])
                mem[addra][i*COL_WIDTH +: COL_WIDTH] <= dina[i*COL_WIDTH +: COL_WIDTH];
        end
    end
end

// Port A 读
always @(posedge clk) begin
    if (mem_ena && ~|wea)
        memrega <= mem[addra];
end

always @(posedge clk) begin
    mem_en_pipe_a[0] <= mem_ena && ~|wea;
    for (i = 0; i < NBPIPE; i = i + 1)
        mem_en_pipe_a[i+1] <= mem_en_pipe_a[i];
end

always @(posedge clk) begin
    if (mem_en_pipe_a[0])
        mem_pipe_a[0] <= memrega;
    for (i = 1; i < NBPIPE; i = i + 1)
        if (mem_en_pipe_a[i])
            mem_pipe_a[i] <= mem_pipe_a[i-1];
end

always @(posedge clk) begin
    if (mem_en_pipe_a[NBPIPE])
        douta <= mem_pipe_a[NBPIPE-1];
end

// Port B 写
always @(posedge clk) begin
    if (mem_enb) begin
        for (i = 0; i < NUM_COL; i = i + 1) begin
            if (web[i])
                mem[addrb][i*COL_WIDTH +: COL_WIDTH] <= dinb[i*COL_WIDTH +: COL_WIDTH];
        end
    end
end

// Port B 读
always @(posedge clk) begin
    if (mem_enb && ~|web)
        memregb <= mem[addrb];
end

always @(posedge clk) begin
    mem_en_pipe_b[0] <= mem_enb && ~|web;
    for (i = 0; i < NBPIPE; i = i + 1)
        mem_en_pipe_b[i+1] <= mem_en_pipe_b[i];
end

always @(posedge clk) begin
    if (mem_en_pipe_b[0])
        mem_pipe_b[0] <= memregb;
    for (i = 1; i < NBPIPE; i = i + 1)
        if (mem_en_pipe_b[i])
            mem_pipe_b[i] <= mem_pipe_b[i-1];
end

always @(posedge clk) begin
    if (mem_en_pipe_b[NBPIPE])
        doutb <= mem_pipe_b[NBPIPE-1];
end

integer pipe_init;
initial begin
    douta = {DATA_WIDTH{1'b0}};
    doutb = {DATA_WIDTH{1'b0}};
    memrega = {DATA_WIDTH{1'b0}};
    memregb = {DATA_WIDTH{1'b0}};
    for (pipe_init = 0; pipe_init < NBPIPE; pipe_init = pipe_init + 1) begin
        mem_pipe_a[pipe_init] = {DATA_WIDTH{1'b0}};
        mem_pipe_b[pipe_init] = {DATA_WIDTH{1'b0}};
    end
    for (pipe_init = 0; pipe_init <= NBPIPE; pipe_init = pipe_init + 1) begin
        mem_en_pipe_a[pipe_init] = 1'b0;
        mem_en_pipe_b[pipe_init] = 1'b0;
    end
end

endmodule
