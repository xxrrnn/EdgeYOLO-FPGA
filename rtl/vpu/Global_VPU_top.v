`timescale 1ns/1ns
`include "chip_defines.vh"

// Global_VPU_top - VPU 顶层模块 (chip-v2)
// chip-v2 变更：
//   - 内置 vpu_buf（8MB XPM），VPU 直接读写本地 buffer
//   - 对外暴露 vpu_buf Port B 的 AXI BRAM 接口（CDMA/XDMA 读写）
//   - 删除 obuf_* 端口（不再连接 DCIM OBUF）

module Global_VPU_top #(
    parameter ADDR_WIDTH = `VPU_DATA_WIDTH,
    parameter VPU_ADDR_WIDTH = `VPU_ADDR_WIDTH,
    parameter C_INT_WIDTH_IN = `C_INT_WIDTH_IN,
    parameter BANDWIDTH = `VB_BANDWIDTH,
    parameter FP_CORE_NUM = `FP_CORE_NUM,
    parameter FP_TRAN_NUM = `FP_TRAN_NUM,
    parameter FP_WIDTH    = `FP_WIDTH,
    parameter WB_ADDR_WIDTH = `WB_ADDR_WIDTH,
    parameter MAX_CHANNEL_NUM = `MAX_CHANNEL_NUM,
    parameter INTERVAL_NUM = `INTERVAL_NUM,
    parameter RAM_DEPTH_GB    = `RAM_DEPTH_GB,
    parameter RAM_DEPTH_WB    = `RAM_DEPTH_WB,
    parameter Q_INT_WIDTH_OUT = `Q_INT_WIDTH_OUT
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK, ASSOCIATED_BUSIF wb_bram:vpu_buf_bram, ASSOCIATED_RESET rst_n, FREQ_HZ 250000000, PHASE 0.0, INSERT_VIP 0" *)
    input   wire                     clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RST_N RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RST_N, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
    input   wire                     rst_n,

    output  wire                     ready,
    input   wire                     vpu_start,

    input   wire[ADDR_WIDTH - 1:0]   unit_choose,
    input   wire[ADDR_WIDTH - 1:0]   src_addr,
    input   wire[ADDR_WIDTH - 1:0]   src2_addr,
    input   wire[ADDR_WIDTH - 1:0]   src_c,
    input   wire[ADDR_WIDTH - 1:0]   src_h,
    input   wire[ADDR_WIDTH - 1:0]   src_w,
    input   wire[ADDR_WIDTH - 1:0]   bias_addr,
    input   wire[ADDR_WIDTH - 1:0]   scale_addr,
    input   wire[ADDR_WIDTH - 1:0]   dst_addr,
    input   wire [ADDR_WIDTH-1:0]    addr_break,
    input   wire [ADDR_WIDTH-1:0]    addr_s,
    input   wire [ADDR_WIDTH-1:0]    addr_t,
    input   wire [3:0]               vpu_flags,

    // VPU_BUF Port B: AXI BRAM 接口（CDMA/XDMA 访问 vpu_buf）
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 vpu_buf_bram CLK" *)
    (* X_INTERFACE_MODE = "Slave" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME vpu_buf_bram, MEM_SIZE 8388608, MEM_WIDTH 128, MEM_ECC NONE, MASTER_TYPE BRAM_CTRL, READ_LATENCY 10, READ_WRITE_MODE READ_WRITE" *)
    input  wire                      vpu_buf_bram_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 vpu_buf_bram RST" *)
    input  wire                      vpu_buf_bram_rst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 vpu_buf_bram EN" *)
    input  wire                      vpu_buf_bram_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 vpu_buf_bram WE" *)
    input  wire [15:0]               vpu_buf_bram_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 vpu_buf_bram ADDR" *)
    input  wire [`VPU_BUF_AXI_ADDR_WIDTH-1:0] vpu_buf_bram_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 vpu_buf_bram DIN" *)
    input  wire [127:0]              vpu_buf_bram_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 vpu_buf_bram DOUT" *)
    output wire [127:0]              vpu_buf_bram_dout,

    // Weight Buffer (WB) BRAM 接口 - 128-bit
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram CLK" *)
    (* X_INTERFACE_MODE = "Slave" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME wb_bram, MEM_SIZE 32768, MEM_WIDTH 128, MEM_ECC NONE, MASTER_TYPE BRAM_CTRL, READ_LATENCY 1, READ_WRITE_MODE READ_WRITE" *)
    input  wire                      wb_bram_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram RST" *)
    input  wire                      wb_bram_rst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram EN" *)
    input  wire                      wb_bram_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram WE" *)
    input  wire [15:0]               wb_bram_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram ADDR" *)
    input  wire [WB_ADDR_WIDTH-1:0]  wb_bram_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram DIN" *)
    input  wire [127:0]              wb_bram_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram DOUT" *)
    output wire [127:0]              wb_bram_dout
);

    localparam NB_COL = `NB_COL;
    localparam COL_WIDTH = `COL_WIDTH;
    localparam BYTE_ADDR_SHIFT = $clog2(BANDWIDTH / 8);

    wire [WB_ADDR_WIDTH-1:0] wb_bram_word_addr = wb_bram_addr >> BYTE_ADDR_SHIFT;

    // -----------------------------------------------------------------------
    // VPU → vpu_buf 内部连接
    // -----------------------------------------------------------------------
    wire [`VPU_BUF_ADDR_WIDTH-1:0]     vpu_obuf_addr;
    wire                               vpu_obuf_en;
    wire [`DCIM_BUF_DATA_WIDTH/8-1:0]  vpu_obuf_we;
    wire [`DCIM_BUF_DATA_WIDTH-1:0]    vpu_obuf_din;
    wire [`DCIM_BUF_DATA_WIDTH-1:0]    vpu_obuf_dout;
    wire                               vpu_obuf_rd_valid;

    // -----------------------------------------------------------------------
    // vpu_buf Port B: AXI BRAM 字节地址 → 字地址
    // -----------------------------------------------------------------------
    wire [`VPU_BUF_ADDR_WIDTH-1:0] vpu_buf_portb_addr = vpu_buf_bram_addr[BYTE_ADDR_SHIFT +: `VPU_BUF_ADDR_WIDTH];

    wire [`DCIM_BUF_DATA_WIDTH-1:0] vpu_buf_portb_dout;
    assign vpu_buf_bram_dout = vpu_buf_portb_dout;

    // -----------------------------------------------------------------------
    // vpu_buf 实例化
    // -----------------------------------------------------------------------
    vpu_buf u_vpu_buf (
        .clk(clk),
        // Port A: VPU 读/写
        .wea(vpu_obuf_we),
        .mem_ena(vpu_obuf_en),
        .dina(vpu_obuf_din),
        .addra(vpu_obuf_addr),
        .douta(vpu_obuf_dout),
        .douta_valid(vpu_obuf_rd_valid),
        // Port B: AXI BRAM（CDMA/XDMA）
        .web(vpu_buf_bram_we),
        .mem_enb(vpu_buf_bram_en),
        .dinb(vpu_buf_bram_din),
        .addrb(vpu_buf_portb_addr),
        .doutb(vpu_buf_portb_dout)
    );

`ifdef SIMULATION
    always @(posedge clk) begin
        if (|vpu_obuf_we && vpu_obuf_en) begin
            $display("[%0t] VPU_BUF_WRITE addr=0x%0h din[127:0]=%h",
                $time, vpu_obuf_addr, vpu_obuf_din);
        end
        if (~|vpu_obuf_we && vpu_obuf_en && vpu_obuf_rd_valid) begin
            $display("[%0t] VPU_BUF_READ_VALID addr(delayed) douta=%h",
                $time, vpu_obuf_dout);
        end
    end
`endif

    // -----------------------------------------------------------------------
    // Global_VPU 实例化
    // -----------------------------------------------------------------------
    Global_VPU #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .VB_ADDR_WIDTH(VPU_ADDR_WIDTH),
        .C_INT_WIDTH_IN(C_INT_WIDTH_IN),
        .BANDWIDTH(BANDWIDTH),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_TRAN_NUM(FP_TRAN_NUM),
        .FP_WIDTH(FP_WIDTH),
        .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
        .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM),
        .INTERVAL_NUM(INTERVAL_NUM),
        .RAM_DEPTH_GB(RAM_DEPTH_GB),
        .RAM_DEPTH_WB(RAM_DEPTH_WB),
        .Q_INT_WIDTH_OUT(Q_INT_WIDTH_OUT)
    ) u_global_vpu (
        .clk(clk),
        .rst_n(rst_n),
        .config_ready(ready),
        .config_valid(1'b1),
        .start(vpu_start),
        .unit_choose(unit_choose),
        .src_addr(src_addr),
        .src2_addr(src2_addr),
        .src_c(src_c),
        .src_h(src_h),
        .src_w(src_w),
        .scale_addr(scale_addr),
        .bias_addr(bias_addr),
        .dst_addr(dst_addr),
        .addr_break(addr_break),
        .addr_s(addr_s),
        .addr_t(addr_t),
        .vpu_flags(vpu_flags),
        // VPU_BUF 端口（原 obuf 端口，现连接内部 vpu_buf）
        .obuf_addr(vpu_obuf_addr),
        .obuf_en(vpu_obuf_en),
        .obuf_we(vpu_obuf_we),
        .obuf_din(vpu_obuf_din),
        .obuf_dout(vpu_obuf_dout),
        .obuf_rd_valid(vpu_obuf_rd_valid),
        // WB 接口
        .wb_addra(wb_bram_word_addr[WB_ADDR_WIDTH-1:0]),
        .wb_dina(wb_bram_din),
        .wb_wea(wb_bram_we),
        .wb_ena(wb_bram_en),
        .wb_douta(wb_bram_dout)
    );

endmodule
