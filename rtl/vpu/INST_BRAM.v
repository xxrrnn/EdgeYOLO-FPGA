`timescale 1ns / 1ps
`include "chip_defines.vh"

//////////////////////////////////////////////////////////////////////////////////
// INST_BRAM - 指令存储 BRAM（双端口）
// 
// 功能：
//   - 端口 A：AXI4-Lite Slave 接口，供 XDMA 写入指令
//   - 端口 B：直接 wire 接口，供 INST_Decoder 读取指令
//
// 特点：
//   - 真双端口 BRAM，支持同时读写
//   - 端口 A 支持读写（AXI 接口）
//   - 端口 B 只读（wire 接口，1 周期延迟）
//////////////////////////////////////////////////////////////////////////////////

module INST_BRAM #(
    parameter DEPTH = `INST_DEPTH,
    parameter ADDR_WIDTH = `INST_ADDR_WIDTH,
    parameter AXI_ADDR_WIDTH = `INST_AXI_ADDR_WIDTH,
    parameter AXI_DATA_WIDTH = `INST_DATA_WIDTH,
    parameter ENABLE_PIPELINE = 1        // 启用内部流水线优化（默认开启）
) (
    input  wire                          clk,
    input  wire                          rst_n,
    
    // ========================================
    // 端口 A：AXI4-Lite Slave 接口（XDMA 写入）
    // ========================================
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                    s_axi_awprot,
    input  wire                          s_axi_awvalid,
    output reg                           s_axi_awready,
    
    input  wire [AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]   s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready,
    
    output reg  [1:0]                    s_axi_bresp,
    output reg                           s_axi_bvalid,
    input  wire                          s_axi_bready,
    
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                    s_axi_arprot,
    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready,
    
    output reg  [AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                    s_axi_rresp,
    output reg                           s_axi_rvalid,
    input  wire                          s_axi_rready,
    
    // ========================================
    // 端口 B：直接 wire 接口（INST_Decoder 读取）
    // ========================================
    input  wire [ADDR_WIDTH-1:0]         inst_rd_addr,   // 读地址（字地址）
    output reg  [31:0]                   inst_rd_data    // 读数据（流水线延迟取决于ENABLE_PIPELINE）
);

    // BRAM 存储
    // CASCADE_HEIGHT=4: 限制 RAMB36E2 级联深度为 4 级（默认被综合器推断为 7 级，
    // 导致 CASDOUT 链路径延迟 3.6ns，超过 250MHz 时钟周期减去 clock skew 后的余量）。
    // 降至 4 级后，级联延迟从 ~1.47ns 降至 ~0.84ns，剩余地址译码改用 LUT output mux，
    // 总路径约 3.0ns，可满足 4ns 周期（含 0.35ns skew + 0.10ns uncertainty）。
    (* CASCADE_HEIGHT = 4 *) reg [31:0] mem [0:DEPTH-1];
    
    // 初始化为 0
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0;
        // BD sim: port-B reads this array directly; optional backdoor load
        if ($test$plusargs("INST_READMEMH")) begin
            $readmemh("inst.hex", mem);
            $display("[%0t] INST_BRAM: readmemh(inst.hex) loaded", $time);
        end
    end
    
    // ========================================
    // 端口 B：直接读取 + 可选的内部流水线优化
    // ========================================
    // 当BRAM深度很大时，Vivado会自动推断CASCADE BRAM，导致长延迟路径
    // 通过内部流水线打断这个路径，改善时序
    
    generate
        if (ENABLE_PIPELINE) begin : gen_pipelined_read
            // 三级流水打断 BRAM CASCADE 长链（128KB = 8个 RAMB36 级联）：
            // Stage 0: BRAM 读取 (mem[addr])  → inst_rd_data_s0
            // Stage 1: 中间寄存器              → inst_rd_data_s1
            // Stage 2: 输出寄存器              → inst_rd_data
            //
            // KEEP="TRUE"（非 DONT_TOUCH）：阻止 Vivado retiming/opt 删除中间级，
            // 同时允许 placer 自由选址（DONT_TOUCH 会固化位置，迫使 BRAM cascade
            // 末端输出绕线到固定 FF 坐标，反而拉长 routing 延迟造成时序违规）。
            (* KEEP = "TRUE" *) reg [31:0] inst_rd_data_s0;
            (* KEEP = "TRUE" *) reg [31:0] inst_rd_data_s1;

            always @(posedge clk) begin
                if (!rst_n) begin
                    inst_rd_data_s0 <= 32'h0;
                    inst_rd_data_s1 <= 32'h0;
                    inst_rd_data    <= 32'h0;
                end else begin
                    inst_rd_data_s0 <= mem[inst_rd_addr];
                    inst_rd_data_s1 <= inst_rd_data_s0;
                    inst_rd_data    <= inst_rd_data_s1;
                end
            end

        end else begin : gen_direct_read
            // 原始单周期读取（向后兼容）
            always @(posedge clk) begin
                inst_rd_data <= mem[inst_rd_addr];
            end
        end
    endgenerate
    
    // ========================================
    // 端口 A：AXI4-Lite Slave 逻辑
    // ========================================
    
    // 写通道
    reg [AXI_ADDR_WIDTH-1:0] aw_addr_reg;
    reg aw_en;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            aw_en <= 1'b1;
            aw_addr_reg <= 0;
        end else begin
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                aw_en <= 1'b0;
                aw_addr_reg <= s_axi_awaddr;
            end else if (s_axi_bready && s_axi_bvalid) begin
                aw_en <= 1'b1;
                s_axi_awready <= 1'b0;
            end else begin
                s_axi_awready <= 1'b0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_wready <= 1'b0;
        end else begin
            if (~s_axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en) begin
                s_axi_wready <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end
        end
    end
    
    // 写入 BRAM
    wire wr_en = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;
    wire [ADDR_WIDTH-1:0] wr_addr = aw_addr_reg[ADDR_WIDTH+1:2];  // 字节地址转字地址
    
    always @(posedge clk) begin
        if (wr_en) begin
            if (s_axi_wstrb[0]) mem[wr_addr][7:0]   <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) mem[wr_addr][15:8]  <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) mem[wr_addr][23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) mem[wr_addr][31:24] <= s_axi_wdata[31:24];
        end
    end
    
    // 写响应
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (s_axi_awready && s_axi_awvalid && ~s_axi_bvalid && s_axi_wready && s_axi_wvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end
    
    // 读通道
    reg [AXI_ADDR_WIDTH-1:0] ar_addr_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
            ar_addr_reg   <= 0;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                ar_addr_reg   <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end
    
    wire [ADDR_WIDTH-1:0] rd_addr = ar_addr_reg[ADDR_WIDTH+1:2];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= 0;
        end else begin
            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                s_axi_rdata  <= mem[rd_addr];
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
