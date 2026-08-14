`timescale 1ns/1ps
`include "chip_defines.vh"

// Cycle-accurate decoder -> CDMA_Controller handshake test.
// The AXI-CDMA data mover is represented by a synthesizable behavioural model
// that copies the real YOLO model.0.conv OH-tile activation image at 32 B/cycle.
// The following DCIM_EXEC is forbidden to start until every destination word is
// committed.  This directly distinguishes an IDLE/accept race from a correct
// busy-then-idle wait.
module tb_cdma_decoder_wait_verilator (
    input wire clk,
    input wire rst_n,
    input wire decoder_start
);
    localparam integer TRANSFER_WORDS = 32000; // 4000 pixels * 8 x 128-bit words
    localparam integer TRANSFER_BYTES = TRANSFER_WORDS * 16;

    wire [31:0] inst_count = 32'd8;

    wire [`INST_ADDR_WIDTH-1:0] inst_rd_addr;
    wire [31:0] inst_rd_data;
    reg [31:0] inst_mem [0:15];
    reg [31:0] inst_q0, inst_q1, inst_q2, inst_q3;

    always @(posedge clk) begin
        inst_q0 <= inst_mem[inst_rd_addr];
        inst_q1 <= inst_q0;
        inst_q2 <= inst_q1;
        inst_q3 <= inst_q2;
    end
    assign inst_rd_data = inst_q3;

    wire decoder_busy, decoder_done;
    wire [31:0] decoder_status;
    wire cdma_start, cdma_config_valid, cdma_config_ready;
    wire [31:0] cdma_src_msb, cdma_src_lsb, cdma_dst_msb, cdma_dst_lsb;
    wire [31:0] cdma_length;
    wire dcim_cfg_wr_en;
    wire [11:0] dcim_cfg_wr_addr;
    wire [31:0] dcim_cfg_wr_data;

    INST_Decoder u_decoder (
        .clk(clk), .rst_n(rst_n),
        .decoder_start(decoder_start), .inst_count(inst_count),
        .decoder_busy(decoder_busy), .decoder_done(decoder_done),
        .decoder_status(decoder_status),
        .inst_rd_addr(inst_rd_addr), .inst_rd_data(inst_rd_data),
        .cdma_start(cdma_start), .cdma_config_valid(cdma_config_valid),
        .cdma_config_ready(cdma_config_ready),
        .cdma_src_addr_msb(cdma_src_msb), .cdma_src_addr_lsb(cdma_src_lsb),
        .cdma_dst_addr_msb(cdma_dst_msb), .cdma_dst_addr_lsb(cdma_dst_lsb),
        .cdma_length(cdma_length),
        .vpu_start(), .vpu_ready(1'b1), .vpu_unit_choose(),
        .vpu_src_addr(), .vpu_src2_addr(), .vpu_src_c(), .vpu_src_h(),
        .vpu_src_w(), .vpu_bias_addr(), .vpu_scale_addr(), .vpu_dst_addr(),
        .vpu_addr_break(), .vpu_addr_s(), .vpu_addr_t(), .vpu_flags(),
        .dcim_cfg_wr_en(dcim_cfg_wr_en),
        .dcim_cfg_wr_addr(dcim_cfg_wr_addr),
        .dcim_cfg_wr_data(dcim_cfg_wr_data), .dcim_ready(1'b1)
    );

    wire [31:0] axil_awaddr, axil_wdata, axil_araddr;
    wire [2:0] axil_awprot, axil_arprot;
    wire [3:0] axil_wstrb;
    wire axil_awvalid, axil_wvalid, axil_bready;
    wire axil_arvalid, axil_rready;
    reg axil_rvalid = 1'b0;
    reg [31:0] axil_rdata = 32'h2;

    CDMA_Controller u_controller (
        .clk(clk), .rst_n(rst_n),
        .cdma_start(cdma_start), .cdma_config_valid(cdma_config_valid),
        .cdma_config_ready(cdma_config_ready),
        .cdma_src_addr_msb(cdma_src_msb), .cdma_src_addr_lsb(cdma_src_lsb),
        .cdma_dst_addr_msb(cdma_dst_msb), .cdma_dst_addr_lsb(cdma_dst_lsb),
        .cdma_length(cdma_length),
        .cdma_axilm_awaddr(axil_awaddr), .cdma_axilm_awprot(axil_awprot),
        .cdma_axilm_awvalid(axil_awvalid), .cdma_axilm_awready(1'b1),
        .cdma_axilm_wdata(axil_wdata), .cdma_axilm_wstrb(axil_wstrb),
        .cdma_axilm_wvalid(axil_wvalid), .cdma_axilm_wready(1'b1),
        .cdma_axilm_bresp(2'b00), .cdma_axilm_bvalid(1'b1),
        .cdma_axilm_bready(axil_bready),
        .cdma_axilm_araddr(axil_araddr), .cdma_axilm_arprot(axil_arprot),
        .cdma_axilm_arvalid(axil_arvalid), .cdma_axilm_arready(1'b1),
        .cdma_axilm_rdata(axil_rdata), .cdma_axilm_rresp(2'b00),
        .cdma_axilm_rvalid(axil_rvalid), .cdma_axilm_rready(axil_rready)
    );

    reg [127:0] src_mem [0:TRANSFER_WORDS-1];
    reg [127:0] dst_mem [0:TRANSFER_WORDS-1];
    reg mover_busy = 1'b0;
    reg mover_complete = 1'b0;
    integer launch_delay_cfg = 0;
    integer launch_delay_count = 0;
    integer copy_word = 0;
    integer cycle = 0;
    integer accept_cycle = -1;
    integer busy_cycle = -1;
    integer complete_cycle = -1;
    integer dcim_cycle = -1;
    integer mismatch_count;
    integer i;
    string act_hex;

    // One-cycle AXI-Lite read response. SR[1] is the Xilinx CDMA IDLE bit.
    always @(posedge clk) begin
        axil_rvalid <= axil_arvalid;
        if (axil_arvalid)
            axil_rdata <= mover_busy ? 32'h0 : 32'h2;
    end

    // Model the data phase started by the BTT/LEN register write.
    always @(posedge clk) begin
        cycle <= cycle + 1;
        if (!rst_n) begin
            mover_busy <= 1'b0;
            mover_complete <= 1'b0;
            launch_delay_count <= 0;
            copy_word <= 0;
        end else begin
            if (cdma_start && cdma_config_ready && accept_cycle < 0)
                accept_cycle <= cycle;
            if (axil_awvalid && axil_wvalid &&
                (axil_awaddr[7:0] == 8'h28)) begin
                if (axil_wdata != TRANSFER_BYTES)
                    $fatal(1, "BTT mismatch got=%0d expected=%0d", axil_wdata,
                           TRANSFER_BYTES);
                mover_complete <= 1'b0;
                copy_word <= 0;
                if (launch_delay_cfg == 0) begin
                    mover_busy <= 1'b1;
                    busy_cycle <= cycle;
                end else begin
                    // A real AXI CDMA may continue to report SR.IDLE for a
                    // short interval after accepting BTT.  This interval is
                    // the adversarial case the controller must not confuse
                    // with completion.
                    mover_busy <= 1'b0;
                    launch_delay_count <= launch_delay_cfg;
                end
            end else if (launch_delay_count > 0) begin
                launch_delay_count <= launch_delay_count - 1;
                if (launch_delay_count == 1) begin
                    mover_busy <= 1'b1;
                    busy_cycle <= cycle;
                end
            end else if (mover_busy) begin
                dst_mem[copy_word] <= src_mem[copy_word];
                if (copy_word + 1 < TRANSFER_WORDS)
                    dst_mem[copy_word + 1] <= src_mem[copy_word + 1];
                if (copy_word + 2 >= TRANSFER_WORDS) begin
                    mover_busy <= 1'b0;
                    mover_complete <= 1'b1;
                    copy_word <= TRANSFER_WORDS;
                    complete_cycle <= cycle;
                end else begin
                    copy_word <= copy_word + 2;
                end
            end

            if (dcim_cfg_wr_en && dcim_cfg_wr_addr == 12'h000 &&
                dcim_cfg_wr_data[0]) begin
                dcim_cycle <= cycle;
                if (!mover_complete)
                    $fatal(1, "EARLY_DCIM cycle=%0d copied_words=%0d/%0d controller_state=%0d decoder_state=%0d",
                           cycle, copy_word, TRANSFER_WORDS,
                           u_controller.c_state, u_decoder.state);
                mismatch_count = 0;
                for (i = 0; i < TRANSFER_WORDS; i = i + 1)
                    if (dst_mem[i] !== src_mem[i])
                        mismatch_count = mismatch_count + 1;
                if (mismatch_count != 0)
                    $fatal(1, "DATA_MISMATCH words=%0d/%0d", mismatch_count,
                           TRANSFER_WORDS);
                $display("CDMA_WAIT_PASS bytes=%0d accept_cycle=%0d busy_cycle=%0d complete_cycle=%0d dcim_cycle=%0d gap=%0d",
                         TRANSFER_BYTES, accept_cycle, busy_cycle,
                         complete_cycle, cycle, cycle-complete_cycle);
                $finish;
            end
        end
    end

    initial begin
        void'($value$plusargs("SR_BUSY_DELAY_CYCLES=%d", launch_delay_cfg));
        if (!$value$plusargs("ACT_HEX=%s", act_hex))
            $fatal(1, "missing +ACT_HEX=<real YOLO act0.hex>");
        $readmemh(act_hex, src_mem);
        for (i = 0; i < TRANSFER_WORDS; i = i + 1)
            dst_mem[i] = '0;

        // CDMA_COPY 0x0 -> 0x0010_0000, 512000 B; DCIM_EXEC; END.
        inst_mem[0] = 32'h1000_0014;
        inst_mem[1] = 32'h0000_0000;
        inst_mem[2] = 32'h0000_0000;
        inst_mem[3] = 32'h0000_0000;
        inst_mem[4] = 32'h0010_0000;
        inst_mem[5] = TRANSFER_BYTES;
        inst_mem[6] = 32'h6000_0000;
        inst_mem[7] = 32'hf000_0000;
        inst_q0 = '0;
        inst_q1 = '0;
        inst_q2 = '0;
        inst_q3 = '0;

    end
endmodule
