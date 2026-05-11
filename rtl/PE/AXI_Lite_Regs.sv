`timescale 1ns / 1ps

// ============================================================================
// AXI_Lite_Regs - AXI-Lite 配置寄存器模块
// ============================================================================
//
// 功能：提供 AXI-Lite 从接口，用于配置 PE Array 参数
//
// 寄存器映射（32-bit 对齐）：
//   0x00: CTRL      - 控制寄存器 [0]=start, [1]=soft_reset
//   0x04: STATUS    - 状态寄存器 [0]=ready, [1]=done, [15:8]=tile_ready, [23:16]=tile_done
//   0x08: MODE      - 计算模式 [2:0]=mode
//   0x0C: ACC_DEPTH - 累加深度 [6:0]=acc_depth
//   0x10: NUM_ROWS  - 激活行数 [15:0]=num_rows
//   0x14: WEI_BASE  - 权重基地址 [13:0]=wei_base_addr
//   0x18: ACT_BASE  - 激活基地址 [13:0]=act_base_addr
//   0x1C: OUT_BASE  - 输出基地址 [13:0]=out_base_addr
//   0x20-0x3C: TILE_OUT_OFFSET[0-7] - 各 Tile 输出偏移 [13:0]
//
// ============================================================================

module AXI_Lite_Regs #(
    parameter NUM_TILES      = 8,
    parameter BUF_ADDR_WIDTH = 14,
    parameter ACC_UBD_WD     = 7,
    
    // AXI-Lite 参数
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8
)(
    // AXI-Lite 从接口
    input  wire                                  S_AXI_ACLK,
    input  wire                                  S_AXI_ARESETN,
    
    // 写地址通道
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  wire [2:0]                            S_AXI_AWPROT,
    input  wire                                  S_AXI_AWVALID,
    output wire                                  S_AXI_AWREADY,
    
    // 写数据通道
    input  wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]     S_AXI_WSTRB,
    input  wire                                  S_AXI_WVALID,
    output wire                                  S_AXI_WREADY,
    
    // 写响应通道
    output wire [1:0]                            S_AXI_BRESP,
    output wire                                  S_AXI_BVALID,
    input  wire                                  S_AXI_BREADY,
    
    // 读地址通道
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  wire [2:0]                            S_AXI_ARPROT,
    input  wire                                  S_AXI_ARVALID,
    output wire                                  S_AXI_ARREADY,
    
    // 读数据通道
    output wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_RDATA,
    output wire [1:0]                            S_AXI_RRESP,
    output wire                                  S_AXI_RVALID,
    input  wire                                  S_AXI_RREADY,
    
    // PE Array 控制接口
    output wire                                  pe_start,
    output wire                                  pe_soft_reset,
    input  wire                                  pe_ready,
    input  wire                                  pe_done,
    input  wire [NUM_TILES-1:0]                  pe_tile_ready,
    input  wire [NUM_TILES-1:0]                  pe_tile_done,
    
    // PE Array 配置接口
    output wire [2:0]                            pe_mode,
    output wire [ACC_UBD_WD-1:0]                 pe_acc_depth,
    output wire [15:0]                           pe_num_rows,
    output wire [BUF_ADDR_WIDTH-1:0]             pe_wei_base_addr,
    output wire [BUF_ADDR_WIDTH-1:0]             pe_act_base_addr,
    output wire [BUF_ADDR_WIDTH-1:0]             pe_out_base_addr,
    output wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]   pe_tile_out_offset
);

    // ========================================================================
    // AXI-Lite 信号
    // ========================================================================
    
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg                          axi_awready;
    reg                          axi_wready;
    reg [1:0]                    axi_bresp;
    reg                          axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg                          axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0]                    axi_rresp;
    reg                          axi_rvalid;
    
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;
    
    // ========================================================================
    // 配置寄存器
    // ========================================================================
    
    reg [31:0] reg_ctrl;           // 0x00
    reg [31:0] reg_mode;           // 0x08
    reg [31:0] reg_acc_depth;      // 0x0C
    reg [31:0] reg_num_rows;       // 0x10
    reg [31:0] reg_wei_base;       // 0x14
    reg [31:0] reg_act_base;       // 0x18
    reg [31:0] reg_out_base;       // 0x1C
    reg [31:0] reg_tile_out_offset [0:NUM_TILES-1];  // 0x20-0x3C
    
    // 状态寄存器（只读）
    wire [31:0] reg_status = {8'b0, pe_tile_done, pe_tile_ready, 6'b0, pe_done, pe_ready};
    
    // 输出映射
    assign pe_start      = reg_ctrl[0];
    assign pe_soft_reset = reg_ctrl[1];
    assign pe_mode       = reg_mode[2:0];
    assign pe_acc_depth  = reg_acc_depth[ACC_UBD_WD-1:0];
    assign pe_num_rows   = reg_num_rows[15:0];
    assign pe_wei_base_addr = reg_wei_base[BUF_ADDR_WIDTH-1:0];
    assign pe_act_base_addr = reg_act_base[BUF_ADDR_WIDTH-1:0];
    assign pe_out_base_addr = reg_out_base[BUF_ADDR_WIDTH-1:0];
    
    genvar gi;
    generate
        for (gi = 0; gi < NUM_TILES; gi = gi + 1) begin : gen_tile_offset
            assign pe_tile_out_offset[gi*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = 
                   reg_tile_out_offset[gi][BUF_ADDR_WIDTH-1:0];
        end
    endgenerate
    
    // ========================================================================
    // AXI-Lite 写逻辑
    // ========================================================================
    
    wire aw_en;
    reg  aw_en_reg;
    
    assign aw_en = ~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en_reg;
    
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            aw_en_reg <= 1'b1;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en_reg) begin
                aw_en_reg <= 1'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                aw_en_reg <= 1'b1;
            end
        end
    end
    
    // AWREADY
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            axi_awaddr  <= 0;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en_reg) begin
                axi_awready <= 1'b1;
                axi_awaddr  <= S_AXI_AWADDR;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end
    
    // WREADY
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_wready <= 1'b0;
        end else begin
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en_reg) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end
    
    // 寄存器写入
    wire slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
    
    integer i;
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            reg_ctrl      <= 32'b0;
            reg_mode      <= 32'h6;  // 默认 INT8
            reg_acc_depth <= 32'b0;
            reg_num_rows  <= 32'b0;
            reg_wei_base  <= 32'b0;
            reg_act_base  <= 32'b0;
            reg_out_base  <= 32'b0;
            for (i = 0; i < NUM_TILES; i = i + 1) begin
                reg_tile_out_offset[i] <= 32'b0;
            end
        end else begin
            // start 信号自动清零（单周期脉冲效果由 PE 内部上升沿检测实现）
            // 这里保持电平，由软件控制
            
            if (slv_reg_wren) begin
                case (axi_awaddr[7:2])
                    6'h00: reg_ctrl      <= S_AXI_WDATA;
                    6'h02: reg_mode      <= S_AXI_WDATA;
                    6'h03: reg_acc_depth <= S_AXI_WDATA;
                    6'h04: reg_num_rows  <= S_AXI_WDATA;
                    6'h05: reg_wei_base  <= S_AXI_WDATA;
                    6'h06: reg_act_base  <= S_AXI_WDATA;
                    6'h07: reg_out_base  <= S_AXI_WDATA;
                    6'h08: reg_tile_out_offset[0] <= S_AXI_WDATA;
                    6'h09: reg_tile_out_offset[1] <= S_AXI_WDATA;
                    6'h0A: reg_tile_out_offset[2] <= S_AXI_WDATA;
                    6'h0B: reg_tile_out_offset[3] <= S_AXI_WDATA;
                    6'h0C: reg_tile_out_offset[4] <= S_AXI_WDATA;
                    6'h0D: reg_tile_out_offset[5] <= S_AXI_WDATA;
                    6'h0E: reg_tile_out_offset[6] <= S_AXI_WDATA;
                    6'h0F: reg_tile_out_offset[7] <= S_AXI_WDATA;
                    default: ;
                endcase
            end
        end
    end
    
    // 写响应
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b0;
        end else begin
            if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0;  // OKAY
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end
    
    // ========================================================================
    // AXI-Lite 读逻辑
    // ========================================================================
    
    // ARREADY
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr  <= 0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end
    
    // RVALID & RDATA
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b0;
            axi_rdata  <= 0;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b0;  // OKAY
                
                case (axi_araddr[7:2])
                    6'h00: axi_rdata <= reg_ctrl;
                    6'h01: axi_rdata <= reg_status;
                    6'h02: axi_rdata <= reg_mode;
                    6'h03: axi_rdata <= reg_acc_depth;
                    6'h04: axi_rdata <= reg_num_rows;
                    6'h05: axi_rdata <= reg_wei_base;
                    6'h06: axi_rdata <= reg_act_base;
                    6'h07: axi_rdata <= reg_out_base;
                    6'h08: axi_rdata <= reg_tile_out_offset[0];
                    6'h09: axi_rdata <= reg_tile_out_offset[1];
                    6'h0A: axi_rdata <= reg_tile_out_offset[2];
                    6'h0B: axi_rdata <= reg_tile_out_offset[3];
                    6'h0C: axi_rdata <= reg_tile_out_offset[4];
                    6'h0D: axi_rdata <= reg_tile_out_offset[5];
                    6'h0E: axi_rdata <= reg_tile_out_offset[6];
                    6'h0F: axi_rdata <= reg_tile_out_offset[7];
                    default: axi_rdata <= 32'b0;
                endcase
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
