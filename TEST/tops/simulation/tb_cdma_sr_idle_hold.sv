`timescale 1ns / 1ns
`include "chip_defines.vh"

// Isolated CDMA_Controller vs a behavioral AXI CDMA SR model.
// idle_hold: cycles after BTT write where SR.Idle stays 1 (stale pre-start Idle).
// xfer_cycles: cycles SR.Idle stays 0 (the real transfer).
module tb_cdma_sr_idle_hold (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cdma_start,
    input  wire [15:0] idle_hold,
    input  wire [15:0] xfer_cycles,
    output wire        ctrl_ready,
    output wire        ip_idle,
    output wire        ip_busy,
    output wire        first_poll_valid,
    output wire        first_poll_idle,
    output wire [31:0] cycle_ctr,
    output wire        awvalid_o,
    output wire        wvalid_o,
    output wire        bvalid_o,
    output wire        arvalid_o,
    output wire        rvalid_o
);
    localparam int AW = 32;
    localparam int DW = 32;
    localparam logic [7:0] SR_OFF  = 8'h04;
    localparam logic [7:0] LEN_OFF = 8'h28;

    wire        cfg_ready;
    wire        cfg_valid = cfg_ready;

    wire [AW-1:0] awaddr;
    wire [2:0]    awprot;
    wire          awvalid;
    wire          awready = 1'b1;
    wire [DW-1:0] wdata;
    wire [DW/8-1:0] wstrb;
    wire          wvalid;
    wire          wready = 1'b1;
    wire [1:0]    bresp = 2'b00;
    logic         bvalid;
    wire          bready;
    wire [AW-1:0] araddr;
    wire [2:0]    arprot;
    wire          arvalid;
    wire          arready = 1'b1;
    logic [DW-1:0] rdata;
    wire [1:0]    rresp = 2'b00;
    logic         rvalid;
    wire          rready;

    assign ctrl_ready = cfg_ready;
    assign awvalid_o = awvalid;
    assign wvalid_o  = wvalid;
    assign bvalid_o  = bvalid;
    assign arvalid_o = arvalid;
    assign rvalid_o  = rvalid;

    CDMA_Controller #(
        .CDMA_BASE_ADDR(0),
        .C_CDMA_AXILM_ADDR_WIDTH(AW),
        .C_CDMA_AXILM_DATA_WIDTH(DW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cdma_start(cdma_start),
        .cdma_config_valid(cfg_valid),
        .cdma_config_ready(cfg_ready),
        .cdma_src_addr_msb(32'h0),
        .cdma_src_addr_lsb(32'h1000_0000),
        .cdma_dst_addr_msb(32'h1),
        .cdma_dst_addr_lsb(32'h0),
        .cdma_length(32'd512000),
        .cdma_axilm_awaddr(awaddr),
        .cdma_axilm_awprot(awprot),
        .cdma_axilm_awvalid(awvalid),
        .cdma_axilm_awready(awready),
        .cdma_axilm_wdata(wdata),
        .cdma_axilm_wstrb(wstrb),
        .cdma_axilm_wvalid(wvalid),
        .cdma_axilm_wready(wready),
        .cdma_axilm_bresp(bresp),
        .cdma_axilm_bvalid(bvalid),
        .cdma_axilm_bready(bready),
        .cdma_axilm_araddr(araddr),
        .cdma_axilm_arprot(arprot),
        .cdma_axilm_arvalid(arvalid),
        .cdma_axilm_arready(arready),
        .cdma_axilm_rdata(rdata),
        .cdma_axilm_rresp(rresp),
        .cdma_axilm_rvalid(rvalid),
        .cdma_axilm_rready(rready)
    );

    logic [31:0] cyc;
    assign cycle_ctr = cyc;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cyc <= '0;
        else        cyc <= cyc + 1'b1;
    end

    typedef enum logic [1:0] { IP_IDLE, IP_HOLD, IP_BUSY } ip_e;
    ip_e         ip_phase;
    logic [15:0] hold_cnt, busy_cnt;
    logic        saw_btt;
    logic        poll_after_btt_valid;
    logic        poll_after_btt_idle;
    logic [31:0] awaddr_hold;

    assign ip_idle = (ip_phase != IP_BUSY);
    assign ip_busy = (ip_phase == IP_BUSY);
    assign first_poll_valid = poll_after_btt_valid;
    assign first_poll_idle  = poll_after_btt_idle;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid <= 1'b0;
            rvalid <= 1'b0;
            rdata  <= '0;
            ip_phase <= IP_IDLE;
            hold_cnt <= '0;
            busy_cnt <= '0;
            saw_btt  <= 1'b0;
            poll_after_btt_valid <= 1'b0;
            poll_after_btt_idle  <= 1'b0;
            awaddr_hold <= '0;
        end else begin
            if (bvalid && bready) bvalid <= 1'b0;
            else if (awvalid && awready && wvalid && wready) begin
                awaddr_hold <= awaddr;
                bvalid <= 1'b1;
            end

            if (rvalid && rready) rvalid <= 1'b0;
            else if (arvalid && arready && !rvalid) begin
                rvalid <= 1'b1;
                if (araddr[7:0] == SR_OFF)
                    rdata <= {30'd0, ip_idle, 1'b0};
                else
                    rdata <= '0;
                if (saw_btt && !poll_after_btt_valid && araddr[7:0] == SR_OFF) begin
                    poll_after_btt_valid <= 1'b1;
                    poll_after_btt_idle  <= ip_idle;
                end
            end

            if (awvalid && awready && wvalid && wready && awaddr[7:0] == LEN_OFF) begin
                saw_btt <= 1'b1;
                if (idle_hold == 16'd0) begin
                    ip_phase <= IP_BUSY;
                    busy_cnt <= (xfer_cycles == 16'd0) ? 16'd1 : xfer_cycles;
                    hold_cnt <= '0;
                end else begin
                    ip_phase <= IP_HOLD;
                    hold_cnt <= idle_hold;
                    busy_cnt <= (xfer_cycles == 16'd0) ? 16'd1 : xfer_cycles;
                end
            end else if (ip_phase == IP_HOLD) begin
                if (hold_cnt <= 16'd1) begin
                    ip_phase <= IP_BUSY;
                    hold_cnt <= '0;
                end else begin
                    hold_cnt <= hold_cnt - 1'b1;
                end
            end else if (ip_phase == IP_BUSY) begin
                if (busy_cnt <= 16'd1) begin
                    ip_phase <= IP_IDLE;
                    busy_cnt <= '0;
                end else begin
                    busy_cnt <= busy_cnt - 1'b1;
                end
            end
        end
    end
endmodule
