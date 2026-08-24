`timescale 1ns / 1ns
`include "chip_defines.vh"

//////////////////////////////////////////////////////////////////////////////////
// INST_BRAM - 指令存储（真双端口 Block RAM）
//
// Port A: BRAM 接口（供 axi_bram_ctrl IP 连接，XDMA 读写指令）
//         信号命名遵循 axi_bram_ctrl bram_* 端口规范
// Port B: 直读接口（供 INST_Decoder 读取指令，N 拍流水延迟）
//
// 128KB = 32768 × 32-bit，使用 RAMB36E2（32 个 BRAM36）
//////////////////////////////////////////////////////////////////////////////////

module INST_BRAM #(
    parameter DEPTH      = `INST_DEPTH,       // 32768
    parameter ADDR_WIDTH = `INST_ADDR_WIDTH,  // 15 (word address)
    parameter DATA_WIDTH = `INST_DATA_WIDTH,  // 32
    parameter NPIPE      = `INST_BRAM_NPIPE,  // Port B output pipeline stages
    parameter RD_PIPE_A  = `INST_BRAM_RD_PIPE_A // Port A output pipeline stages
) (
    input  wire                       clk,
    input  wire                       rst_n,

    // ========================================
    // Port A: BRAM interface (from axi_bram_ctrl)
    // ========================================
    input  wire                       bram_en_a,
    input  wire [DATA_WIDTH/8-1:0]    bram_we_a,
    input  wire [ADDR_WIDTH+1:0]      bram_addr_a,   // byte address from ctrl
    input  wire [DATA_WIDTH-1:0]      bram_wrdata_a,
    output wire [DATA_WIDTH-1:0]      bram_rddata_a,

    // ========================================
    // Port B: Direct read (INST_Decoder)
    // ========================================
    input  wire [ADDR_WIDTH-1:0]      inst_rd_addr,  // word address
    output wire [DATA_WIDTH-1:0]      inst_rd_data   // pipelined read data
);

    // ========================================
    // BRAM storage (force block RAM inference)
    // ========================================
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};
        if ($test$plusargs("INST_READMEMH")) begin
            $readmemh("inst.hex", mem);
            $display("[%0t] INST_BRAM: readmemh(inst.hex) loaded", $time);
        end
    end

    // ========================================
    // Port A: synchronous read/write (single clock)
    // ========================================
    wire [ADDR_WIDTH-1:0] addr_a = bram_addr_a[ADDR_WIDTH+1:2]; // byte→word

    reg [DATA_WIDTH-1:0] rddata_a_raw;

    always @(posedge clk) begin
        if (bram_en_a) begin
            if (bram_we_a[0]) mem[addr_a][ 7: 0] <= bram_wrdata_a[ 7: 0];
            if (bram_we_a[1]) mem[addr_a][15: 8] <= bram_wrdata_a[15: 8];
            if (bram_we_a[2]) mem[addr_a][23:16] <= bram_wrdata_a[23:16];
            if (bram_we_a[3]) mem[addr_a][31:24] <= bram_wrdata_a[31:24];
            rddata_a_raw <= mem[addr_a]; // read-first mode, 1-cycle latency
        end
    end

    // Port A output pipeline (RD_PIPE_A stages after BRAM read register)
    generate
        if (RD_PIPE_A == 0) begin : gen_porta_no_pipe
            assign bram_rddata_a = rddata_a_raw;
        end else begin : gen_porta_pipe
            reg [DATA_WIDTH-1:0] pipeA [0:RD_PIPE_A-1];
            integer pa;
            always @(posedge clk) begin
                pipeA[0] <= rddata_a_raw;
                for (pa = 1; pa < RD_PIPE_A; pa = pa + 1)
                    pipeA[pa] <= pipeA[pa-1];
            end
            assign bram_rddata_a = pipeA[RD_PIPE_A-1];
        end
    endgenerate

    // ========================================
    // Port B: synchronous read + pipeline
    // ========================================
    reg [DATA_WIDTH-1:0] portb_rd_raw;

    always @(posedge clk) begin
        portb_rd_raw <= mem[inst_rd_addr];
    end

    generate
        if (NPIPE == 0) begin : gen_no_pipe
            assign inst_rd_data = portb_rd_raw;
        end else begin : gen_pipe
            reg [DATA_WIDTH-1:0] pipe [0:NPIPE-1];
            integer p;
            always @(posedge clk) begin
                pipe[0] <= portb_rd_raw;
                for (p = 1; p < NPIPE; p = p + 1)
                    pipe[p] <= pipe[p-1];
            end
            assign inst_rd_data = pipe[NPIPE-1];
        end
    endgenerate

endmodule
