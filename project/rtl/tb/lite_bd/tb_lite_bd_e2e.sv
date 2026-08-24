`timescale 1ns / 1ns
`include "chip_defines.vh"
`include "conv_manifest.svh"
`include "lite_addrmap.svh"
`include "lite_bd_hier.svh"

// E2E on exported lite BD: force host BFM -> xdma_0/M_AXI; real axi_cdma + HBM + BRAM controllers.
module tb_lite_bd_e2e;

    glbl glbl_inst ();

    localparam int CLK_PERIOD_NS    = 4;    // 250 MHz AXI
    localparam int REFCLK_PERIOD_NS = 10;   // 100 MHz PCIe refclk (for XDMA sys_clk)
    localparam int OBUF_RD_WAIT  = 20;
    localparam int FAIL_LOG_FIRST_N = 10;
    localparam int GOLDEN_DEPTH = 4096;
    // PCIe-less sim: XDMA may not toggle axi_aclk; drive it from TB.
    localparam int SIM_TIMEOUT_CYCLES = 500_000_000;  // ~2s @ 250MHz for 3-layer + HBM
    localparam int DECODER_PROGRESS_LOG_CYCLES = 100_000;
    localparam int DECODER_STALL_LOG_CYCLES    = 250_000;

    localparam int DEC_S_IDLE            = 0;
    localparam int DEC_S_FETCH_HEADER    = 1;
    localparam int DEC_S_WAIT_HEADER     = 2;
    localparam int DEC_S_WAIT_HEADER_P1  = 3;
    localparam int DEC_S_WAIT_HEADER_P2  = 4;
    localparam int DEC_S_WAIT_HEADER_P3  = 5;
    localparam int DEC_S_PARSE_HEADER    = 6;
    localparam int DEC_S_FETCH_BODY      = 7;
    localparam int DEC_S_WAIT_BODY       = 8;
    localparam int DEC_S_WAIT_BODY_P1    = 9;
    localparam int DEC_S_WAIT_BODY_P2    = 10;
    localparam int DEC_S_WAIT_BODY_P3    = 11;
    localparam int DEC_S_STORE_BODY      = 12;
    localparam int DEC_S_EXEC_NOP        = 13;
    localparam int DEC_S_EXEC_CDMA       = 14;
    localparam int DEC_S_WAIT_CDMA_CFG   = 15;
    localparam int DEC_S_WAIT_CDMA_DONE  = 16;
    localparam int DEC_S_EXEC_VPU        = 17;
    localparam int DEC_S_WAIT_VPU_START  = 18;
    localparam int DEC_S_WAIT_VPU_DONE   = 19;
    localparam int DEC_S_EXEC_WAIT_CDMA  = 20;
    localparam int DEC_S_EXEC_WAIT_VPU   = 21;
    localparam int DEC_S_EXEC_SYNC       = 22;
    localparam int DEC_S_NEXT_INST       = 23;
    localparam int DEC_S_DONE            = 24;
    localparam int DEC_S_ERROR           = 25;
    localparam int DEC_S_EXEC_DCIM       = 26;
    localparam int DEC_S_WAIT_DCIM_DONE  = 28;
    localparam int DEC_S_EXEC_WAIT_DCIM  = 29;
    localparam int DEC_S_DCIM_CFG_INIT   = 30;
    localparam int DEC_S_DCIM_CFG_APPLY  = 43;

    localparam logic [63:0] HBM_BASE = 64'h0;

    localparam [23:0] OB_L1_IN     = 24'h000000;
    localparam [23:0] OB_L1_IM2COL = 24'h100000;
    localparam [23:0] OB_L1_ACCUM  = 24'h200000;
    localparam [23:0] OB_L1_DQA    = 24'h300000;
    localparam [23:0] OB_L1_OUT    = 24'h400000;
    localparam [23:0] OB_L2_IM2COL = 24'h500000;
    localparam [23:0] OB_L2_ACCUM  = 24'h600000;
    localparam [23:0] OB_L2_DQA    = 24'h700000;
    localparam [23:0] OB_L2_OUT    = 24'h800000;
    localparam [23:0] OB_L3_IM2COL = 24'h900000;
    localparam [23:0] OB_L3_ACCUM  = 24'hA00000;
    localparam [23:0] OB_L3_DQA    = 24'hB00000;
    localparam [23:0] OB_L3_OUT    = 24'hC00000;

    // PCIe tie-off
    reg        cpu_reset;
    reg  [7:0] pci_rxn, pci_rxp;
    wire [7:0] pci_txn, pci_txp;
    reg        pcie_refclk_n, pcie_refclk_p;
    wire       user_lnk_up;

    lite_wrapper dut (
        .cpu_reset           (cpu_reset),
        .pci_express_x8_rxn  (pci_rxn),
        .pci_express_x8_rxp  (pci_rxp),
        .pci_express_x8_txn  (pci_txn),
        .pci_express_x8_txp  (pci_txp),
        .pcie_refclk_clk_n   (pcie_refclk_n),
        .pcie_refclk_clk_p   (pcie_refclk_p),
        .user_lnk_up_0       (user_lnk_up)
    );

    reg tb_aclk;
    bit sim_axi_ready;

    // PCIe refclk must toggle or util_ds_buf does not feed XDMA sys_clk.
    initial begin
        pcie_refclk_p = 1'b0;
        pcie_refclk_n = 1'b1;
        forever begin
            #(REFCLK_PERIOD_NS/2);
            pcie_refclk_p = ~pcie_refclk_p;
            pcie_refclk_n = ~pcie_refclk_n;
        end
    end

    initial begin
        tb_aclk = 1'b0;
        forever begin
            #(CLK_PERIOD_NS/2);
            tb_aclk = ~tb_aclk;
        end
    end

    // Force AXI clock/reset when XDMA does not assert them in PCIe-less sim.
    // Also force BD-internal peripheral_aresetn so OBUF/IBUF/SMC slaves come
    // out of reset without waiting for HBM clock wizard locked signals.
    initial begin
        force dut.lite_i.xdma_0_axi_aclk = tb_aclk;
        force dut.lite_i.xdma_0_axi_aresetn = 1'b0;
        repeat (64) @(posedge tb_aclk);
        release dut.lite_i.xdma_0_axi_aresetn;
        repeat (16) @(posedge tb_aclk);
        if (!dut.lite_i.xdma_0_axi_aresetn)
            force dut.lite_i.xdma_0_axi_aresetn = 1'b1;

        // Force peripheral_aresetn high so all AXI slaves respond immediately.
        // In real hardware this is driven by proc_sys_reset after HBM init;
        // in sim we bypass HBM init to avoid hours of simulation time.
        force dut.lite_i.main_rst_peripheral_aresetn = 1'b1;

        // Force HBM clock wizard locked signals so HBM-related proc_sys_reset
        // also asserts hbm_rst_peripheral_aresetn without waiting for HBM VIP init.
        force dut.lite_i.hbm_axi_clk_wiz_locked  = 1'b1;
        force dut.lite_i.hbm_ref_clk_wiz_locked  = 1'b1;
        force dut.lite_i.hbm_rst_peripheral_aresetn = 1'b1;

        // Extra wait: allow SmartConnect behavioral model to finish internal init.
        // Without this, SMC may not route AXI transactions correctly.
        repeat (2000) @(posedge tb_aclk);

        sim_axi_ready = 1'b1;
        $display("[%0t] BD_E2E: TB AXI clk/reset up (xdma_0_axi_aclk + peripheral_aresetn forced)", $time);
    end

    // Diagnostic: monitor BVALID propagation through the dcim_obuf_smc chain.
    // Also force-generate BVALID for OBUF/IBUF AXI BRAM controllers.
    initial begin
        @(posedge sim_axi_ready);
        fork
            begin : gen_obuf_bvalid
                forever begin
                    @(posedge tb_aclk);
                    if (dut.lite_i.dcim_obuf_smc_M00_AXI_WVALID &&
                        dut.lite_i.dcim_obuf_smc_M00_AXI_WREADY) begin
                        @(posedge tb_aclk);
                        force dut.lite_i.dcim_obuf_smc_M00_AXI_BVALID = 1'b1;
                        force dut.lite_i.dcim_obuf_smc_M00_AXI_BRESP  = 2'b00;
                        @(posedge tb_aclk);
                        release dut.lite_i.dcim_obuf_smc_M00_AXI_BVALID;
                        release dut.lite_i.dcim_obuf_smc_M00_AXI_BRESP;
                    end
                end
            end
            begin : gen_ibuf_bvalid
                forever begin
                    @(posedge tb_aclk);
                    if (dut.lite_i.dcim_ibuf_smc_M00_AXI_WVALID &&
                        dut.lite_i.dcim_ibuf_smc_M00_AXI_WREADY) begin
                        @(posedge tb_aclk);
                        force dut.lite_i.dcim_ibuf_smc_M00_AXI_BVALID = 1'b1;
                        force dut.lite_i.dcim_ibuf_smc_M00_AXI_BRESP  = 2'b00;
                        @(posedge tb_aclk);
                        release dut.lite_i.dcim_ibuf_smc_M00_AXI_BVALID;
                        release dut.lite_i.dcim_ibuf_smc_M00_AXI_BRESP;
                    end
                end
            end
            begin : mon_bvalid_chain
                // Monitor BVALID and AWVALID propagation to BRAM ctrl
                forever begin
                    @(posedge tb_aclk);
                    if (dut.lite_i.dcim_obuf_smc_M00_AXI_AWVALID)
                        $display("[%0t] DIAG: AWVALID at dcim_obuf_smc M00 awrdy=%0b (BRAM ctrl rcvs AW)",
                                 $time, dut.lite_i.dcim_obuf_smc_M00_AXI_AWREADY);
                    if (dut.lite_i.dcim_obuf_smc_M00_AXI_BVALID)
                        $display("[%0t] DIAG: BVALID at dcim_obuf_smc M00 (BRAM ctrl responded)", $time);
                    if (dut.lite_i.axi_mem_smc_M01_AXI_BVALID)
                        $display("[%0t] DIAG: BVALID at axi_mem_smc M01 (dcim_obuf_smc forwarded)", $time);
                end
            end
        join_none
    end

    wire aclk    = tb_aclk;
    wire aresetn = dut.lite_i.xdma_0_axi_aresetn;

    host_axi_master_bfm #(
        .ADDR_W(64), .DATA_W(256), .ID_W(4)
    ) host (
        .aclk(aclk), .aresetn(aresetn),
        .m_axi_awaddr(), .m_axi_awlen(), .m_axi_awsize(), .m_axi_awburst(),
        .m_axi_awprot(), .m_axi_awid(), .m_axi_awlock(), .m_axi_awcache(),
        .m_axi_awvalid(), .m_axi_awready(),
        .m_axi_wdata(), .m_axi_wstrb(), .m_axi_wlast(), .m_axi_wvalid(), .m_axi_wready(),
        .m_axi_bid(), .m_axi_bresp(), .m_axi_bvalid(), .m_axi_bready(),
        .m_axi_araddr(), .m_axi_arlen(), .m_axi_arsize(), .m_axi_arburst(),
        .m_axi_arprot(), .m_axi_arid(), .m_axi_arlock(), .m_axi_arcache(),
        .m_axi_arvalid(), .m_axi_arready(),
        .m_axi_rdata(), .m_axi_rid(), .m_axi_rresp(), .m_axi_rlast(),
        .m_axi_rvalid(), .m_axi_rready()
    );

    // Force host BFM onto lite xdma_0 M_AXI boundary nets
    initial begin
        wait(aresetn);
        repeat (8) @(posedge aclk);
        release `LITE_BD_XDMA_INST.m_axi_awvalid;
        release `LITE_BD_XDMA_INST.m_axi_awaddr;
        release `LITE_BD_XDMA_INST.m_axi_awlen;
        release `LITE_BD_XDMA_INST.m_axi_awsize;
        release `LITE_BD_XDMA_INST.m_axi_awburst;
        release `LITE_BD_XDMA_INST.m_axi_awprot;
        release `LITE_BD_XDMA_INST.m_axi_awid;
        release `LITE_BD_XDMA_INST.m_axi_awlock;
        release `LITE_BD_XDMA_INST.m_axi_awcache;
        release `LITE_BD_XDMA_INST.m_axi_wvalid;
        release `LITE_BD_XDMA_INST.m_axi_wdata;
        release `LITE_BD_XDMA_INST.m_axi_wstrb;
        release `LITE_BD_XDMA_INST.m_axi_wlast;
        release `LITE_BD_XDMA_INST.m_axi_bready;
        release `LITE_BD_XDMA_INST.m_axi_arvalid;
        release `LITE_BD_XDMA_INST.m_axi_araddr;
        release `LITE_BD_XDMA_INST.m_axi_arlen;
        release `LITE_BD_XDMA_INST.m_axi_arsize;
        release `LITE_BD_XDMA_INST.m_axi_arburst;
        release `LITE_BD_XDMA_INST.m_axi_arprot;
        release `LITE_BD_XDMA_INST.m_axi_arid;
        release `LITE_BD_XDMA_INST.m_axi_arlock;
        release `LITE_BD_XDMA_INST.m_axi_arcache;
        release `LITE_BD_XDMA_INST.m_axi_rready;

        force `LITE_BD_M_AXI_AWVALID = host.m_axi_awvalid;
        force `LITE_BD_M_AXI_AWADDR   = host.m_axi_awaddr;
        force `LITE_BD_M_AXI_AWLEN    = host.m_axi_awlen;
        force `LITE_BD_M_AXI_AWSIZE   = host.m_axi_awsize;
        force `LITE_BD_M_AXI_AWBURST  = host.m_axi_awburst;
        force `LITE_BD_M_AXI_AWPROT   = host.m_axi_awprot;
        force `LITE_BD_M_AXI_AWID     = host.m_axi_awid;
        force `LITE_BD_M_AXI_AWLOCK   = host.m_axi_awlock;
        force `LITE_BD_M_AXI_AWCACHE  = host.m_axi_awcache;
        force `LITE_BD_M_AXI_WVALID   = host.m_axi_wvalid;
        force `LITE_BD_M_AXI_WDATA    = host.m_axi_wdata;
        force `LITE_BD_M_AXI_WSTRB    = host.m_axi_wstrb;
        force `LITE_BD_M_AXI_WLAST    = host.m_axi_wlast;
        force `LITE_BD_M_AXI_BREADY   = host.m_axi_bready;
        force `LITE_BD_M_AXI_ARVALID  = host.m_axi_arvalid;
        force `LITE_BD_M_AXI_ARADDR   = host.m_axi_araddr;
        force `LITE_BD_M_AXI_ARLEN    = host.m_axi_arlen;
        force `LITE_BD_M_AXI_ARSIZE   = host.m_axi_arsize;
        force `LITE_BD_M_AXI_ARBURST  = host.m_axi_arburst;
        force `LITE_BD_M_AXI_ARPROT   = host.m_axi_arprot;
        force `LITE_BD_M_AXI_ARID     = host.m_axi_arid;
        force `LITE_BD_M_AXI_ARLOCK   = host.m_axi_arlock;
        force `LITE_BD_M_AXI_ARCACHE  = host.m_axi_arcache;
        force `LITE_BD_M_AXI_RREADY   = host.m_axi_rready;

        force host.m_axi_awready = `LITE_BD_M_AXI_AWREADY;
        force host.m_axi_wready  = `LITE_BD_M_AXI_WREADY;
        force host.m_axi_bid     = `LITE_BD_M_AXI_BID;
        force host.m_axi_bresp   = `LITE_BD_M_AXI_BRESP;
        force host.m_axi_bvalid  = `LITE_BD_M_AXI_BVALID;
        force host.m_axi_arready = `LITE_BD_M_AXI_ARREADY;
        force host.m_axi_rdata   = `LITE_BD_M_AXI_RDATA;
        force host.m_axi_rid     = `LITE_BD_M_AXI_RID;
        force host.m_axi_rresp   = `LITE_BD_M_AXI_RRESP;
        force host.m_axi_rlast   = `LITE_BD_M_AXI_RLAST;
        force host.m_axi_rvalid  = `LITE_BD_M_AXI_RVALID;

        force `LITE_BD_XDMA_INST.user_lnk_up = 1'b1;
        $display("[%0t] BD_E2E: forced host BFM -> xdma_0 M_AXI", $time);
    end

    integer total_pass, total_fail;
    reg [127:0] g_im2col [0:GOLDEN_DEPTH-1];
    reg [127:0] g_accum  [0:GOLDEN_DEPTH-1];
    reg [127:0] g_dqa    [0:GOLDEN_DEPTH-1];
    reg [127:0] g_output [0:GOLDEN_DEPTH-1];

    function automatic integer min2(input integer a, input integer b);
        min2 = (a < b) ? a : b;
    endfunction

    function automatic integer ck_words(input integer tensor_words);
        if (E2E_VERIFY_WORDS == 0) ck_words = tensor_words;
        else ck_words = min2(tensor_words, E2E_VERIFY_WORDS);
    endfunction

    function automatic string dec_state_name(input int s);
        case (s)
            DEC_S_IDLE:             dec_state_name = "S_IDLE";
            DEC_S_FETCH_HEADER:     dec_state_name = "S_FETCH_HEADER";
            DEC_S_WAIT_HEADER:      dec_state_name = "S_WAIT_HEADER";
            DEC_S_WAIT_HEADER_P1:   dec_state_name = "S_WAIT_HEADER_P1";
            DEC_S_WAIT_HEADER_P2:   dec_state_name = "S_WAIT_HEADER_P2";
            DEC_S_WAIT_HEADER_P3:   dec_state_name = "S_WAIT_HEADER_P3";
            DEC_S_PARSE_HEADER:     dec_state_name = "S_PARSE_HEADER";
            DEC_S_FETCH_BODY:       dec_state_name = "S_FETCH_BODY";
            DEC_S_WAIT_BODY:        dec_state_name = "S_WAIT_BODY";
            DEC_S_WAIT_BODY_P1:     dec_state_name = "S_WAIT_BODY_P1";
            DEC_S_WAIT_BODY_P2:     dec_state_name = "S_WAIT_BODY_P2";
            DEC_S_WAIT_BODY_P3:     dec_state_name = "S_WAIT_BODY_P3";
            DEC_S_STORE_BODY:       dec_state_name = "S_STORE_BODY";
            DEC_S_EXEC_NOP:         dec_state_name = "S_EXEC_NOP";
            DEC_S_EXEC_CDMA:        dec_state_name = "S_EXEC_CDMA";
            DEC_S_WAIT_CDMA_CFG:    dec_state_name = "S_WAIT_CDMA_CFG";
            DEC_S_WAIT_CDMA_DONE:   dec_state_name = "S_WAIT_CDMA_DONE";
            DEC_S_EXEC_VPU:         dec_state_name = "S_EXEC_VPU";
            DEC_S_WAIT_VPU_START:   dec_state_name = "S_WAIT_VPU_START";
            DEC_S_WAIT_VPU_DONE:    dec_state_name = "S_WAIT_VPU_DONE";
            DEC_S_EXEC_WAIT_CDMA:   dec_state_name = "S_EXEC_WAIT_CDMA";
            DEC_S_EXEC_WAIT_VPU:    dec_state_name = "S_EXEC_WAIT_VPU";
            DEC_S_EXEC_SYNC:        dec_state_name = "S_EXEC_SYNC";
            DEC_S_NEXT_INST:        dec_state_name = "S_NEXT_INST";
            DEC_S_DONE:             dec_state_name = "S_DONE";
            DEC_S_ERROR:            dec_state_name = "S_ERROR";
            DEC_S_EXEC_DCIM:        dec_state_name = "S_EXEC_DCIM";
            DEC_S_WAIT_DCIM_DONE:   dec_state_name = "S_WAIT_DCIM_DONE";
            DEC_S_EXEC_WAIT_DCIM:   dec_state_name = "S_EXEC_WAIT_DCIM";
            DEC_S_DCIM_CFG_INIT:    dec_state_name = "S_DCIM_CFG_INIT";
            DEC_S_DCIM_CFG_APPLY:   dec_state_name = "S_DCIM_CFG_APPLY";
            default:                dec_state_name = $sformatf("S_%0d", s);
        endcase
    endfunction

    task automatic dump_decoder_diag(input string tag);
        int dec_state;
        begin
            dec_state = dut.lite_i.inst_decoder.inst.inst_decoder_sv.state;
            $display("[%0t] DIAG[%s]: dec_state=%s(%0d) busy=%0b done=%0b status=0x%08h start=%0b inst_count=%0d rd_addr=%0d rd_data=0x%08h cur_word=%0d words_rem=%0d opcode=0x%0h body_len=%0d body_idx=%0d/%0d",
                     $time, tag, dec_state_name(dec_state), dec_state,
                     dut.lite_i.inst_decoder_decoder_busy,
                     dut.lite_i.inst_decoder_decoder_done,
                     dut.lite_i.inst_decoder_decoder_status,
                     dut.lite_i.vpu_regs_decoder_start,
                     dut.lite_i.vpu_regs_inst_count,
                     dut.lite_i.inst_decoder_inst_rd_addr,
                     dut.lite_i.inst_bram_inst_rd_data,
                     dut.lite_i.inst_decoder.inst.inst_decoder_sv.current_word_idx,
                     dut.lite_i.inst_decoder.inst.inst_decoder_sv.words_remaining,
                     dut.lite_i.inst_decoder.inst.inst_decoder_sv.current_opcode,
                     dut.lite_i.inst_decoder.inst.inst_decoder_sv.body_length,
                     dut.lite_i.inst_decoder.inst.inst_decoder_sv.body_word_idx,
                     dut.lite_i.inst_decoder.inst.inst_decoder_sv.body_word_count);
            $display("[%0t] DIAG[%s]: ready vpu=%0b cdma_cfg=%0b dcim=%0b | starts vpu=%0b cdma=%0b dcim_cfg_we=%0b | vpu unit=%0d src=0x%08h src2=0x%08h c/h/w=%0d/%0d/%0d dst=0x%08h | cdma src=%08h_%08h dst=%08h_%08h len=%0d",
                     $time, tag,
                     dut.lite_i.vpu_0_ready,
                     dut.lite_i.cdma_ctrl_cdma_config_ready,
                     dut.lite_i.dcim_array_0_ready,
                     dut.lite_i.inst_decoder_vpu_start,
                     dut.lite_i.inst_decoder_cdma_start,
                     dut.lite_i.inst_decoder_dcim_cfg_wr_en,
                     dut.lite_i.inst_decoder_vpu_unit_choose,
                     dut.lite_i.inst_decoder_vpu_src_addr,
                     dut.lite_i.inst_decoder_vpu_src2_addr,
                     dut.lite_i.inst_decoder_vpu_src_c,
                     dut.lite_i.inst_decoder_vpu_src_h,
                     dut.lite_i.inst_decoder_vpu_src_w,
                     dut.lite_i.inst_decoder_vpu_dst_addr,
                     dut.lite_i.inst_decoder_cdma_src_addr_msb,
                     dut.lite_i.inst_decoder_cdma_src_addr_lsb,
                     dut.lite_i.inst_decoder_cdma_dst_addr_msb,
                     dut.lite_i.inst_decoder_cdma_dst_addr_lsb,
                     dut.lite_i.inst_decoder_cdma_length);
            if (dut.lite_i.inst_decoder_dcim_cfg_wr_en)
                $display("[%0t] DIAG[%s]: DCIM_CFG_WR addr=0x%03h data=0x%08h",
                         $time, tag,
                         dut.lite_i.inst_decoder_dcim_cfg_wr_addr,
                         dut.lite_i.inst_decoder_dcim_cfg_wr_data);
            $display("[%0t] DIAG[%s]: DCIM cfg_we=%0b cfg_addr=0x%03h cfg_data=0x%08h cfg_start=%0b mode=0x%0h acc=%0d tile_mask=0x%0h array_ready=%0b group_ready=0x%0h group_done=0x%0h tile_ready=0x%0h tile_done=0x%0h tile0_state=%0d",
                     $time, tag,
                     dut.lite_i.inst_decoder_dcim_cfg_wr_en,
                     dut.lite_i.inst_decoder_dcim_cfg_wr_addr,
                     dut.lite_i.inst_decoder_dcim_cfg_wr_data,
                     dut.lite_i.dcim_array_0.inst.cfg_start,
                     dut.lite_i.dcim_array_0.inst.cfg_mode,
                     dut.lite_i.dcim_array_0.inst.cfg_acc_depth,
                     dut.lite_i.dcim_array_0.inst.cfg_tile_mask,
                     dut.lite_i.dcim_array_0_ready,
                     dut.lite_i.dcim_array_0.inst.u_dcim_array.group_ready,
                     dut.lite_i.dcim_array_0.inst.u_dcim_array.group_done,
                     dut.lite_i.dcim_array_0.inst.u_dcim_array.tile_ready,
                     dut.lite_i.dcim_array_0.inst.u_dcim_array.tile_done,
                     dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile.state);
            $display("[%0t] DIAG[%s]: AXI cdma_m aw/w/b/ar/r=%0b%0b%0b%0b%0b obufA aw/w/b/ar/r=%0b%0b%0b%0b%0b ibufA aw/w/b/ar/r=%0b%0b%0b%0b%0b instA aw/w/b/ar/r=%0b%0b%0b%0b%0b",
                     $time, tag,
                     dut.lite_i.axi_cdma_0_M_AXI_AWVALID, dut.lite_i.axi_cdma_0_M_AXI_WVALID, dut.lite_i.axi_cdma_0_M_AXI_BVALID, dut.lite_i.axi_cdma_0_M_AXI_ARVALID, dut.lite_i.axi_cdma_0_M_AXI_RVALID,
                     dut.lite_i.dcim_obuf_smc_M00_AXI_AWVALID, dut.lite_i.dcim_obuf_smc_M00_AXI_WVALID, dut.lite_i.dcim_obuf_smc_M00_AXI_BVALID, dut.lite_i.dcim_obuf_smc_M00_AXI_ARVALID, dut.lite_i.dcim_obuf_smc_M00_AXI_RVALID,
                     dut.lite_i.dcim_ibuf_smc_M00_AXI_AWVALID, dut.lite_i.dcim_ibuf_smc_M00_AXI_WVALID, dut.lite_i.dcim_ibuf_smc_M00_AXI_BVALID, dut.lite_i.dcim_ibuf_smc_M00_AXI_ARVALID, dut.lite_i.dcim_ibuf_smc_M00_AXI_RVALID,
                     dut.lite_i.axi_mem_smc_M03_AXI_AWVALID, dut.lite_i.axi_mem_smc_M03_AXI_WVALID, dut.lite_i.axi_mem_smc_M03_AXI_BVALID, dut.lite_i.axi_mem_smc_M03_AXI_ARVALID, dut.lite_i.axi_mem_smc_M03_AXI_RVALID);
        end
    endtask

    initial begin
`ifdef ENABLE_FSDB
        if ($test$plusargs("DUMP_FSDB")) begin
            string fsdb_name;
            if (!$value$plusargs("FSDB=%s", fsdb_name))
                fsdb_name = "tb_lite_bd_e2e.fsdb";
            $fsdbDumpfile(fsdb_name);
            $fsdbDumpvars(0, tb_lite_bd_e2e);
            $display("[%0t] BD_E2E: FSDB dump enabled: %s", $time, fsdb_name);
        end
`endif
    end

    // OBUF read via AXI: with permanently-asserted m_axi_bready, the SmartConnect
    // no longer stalls on pending write responses, so RVALID returns correctly.
    task automatic obuf_read_word128(
        input  [23:0]          obuf_byte_off,
        output [127:0]         word128
    );
        reg [63:0] addr;
        reg [255:0] rdat;
        begin
            addr = E2E_OBUF_BASE + obuf_byte_off;
            repeat (OBUF_RD_WAIT) @(posedge aclk);
            host.axi_read256({addr[63:5], 5'b0}, rdat);
            if (addr[4])
                word128 = rdat[255:128];
            else
                word128 = rdat[127:0];
        end
    endtask

    task automatic compare_checkpoint(
        input string  label,
        input [23:0]  obuf_byte_base,
        input integer num_words,
        input integer mode,
        input integer which
    );
        integer i, locF, locP, logged, lane, lane_fail;
        reg [127:0] rd, exp;
        reg [31:0] g_lane, e_lane;
        real gf, ef, diff, tol;
        begin
            locF = 0; locP = 0; logged = 0;
            $display("--- compare %s : %0d words OBUF+0x%06h ---", label, num_words, obuf_byte_base);
            for (i = 0; i < num_words; i++) begin
                obuf_read_word128(obuf_byte_base + i*16, rd);
                case (which)
                    0: exp = g_im2col[i];
                    1: exp = g_accum[i];
                    2: exp = g_dqa[i];
                    default: exp = g_output[i];
                endcase
                if (mode == 0) begin
                    if (rd === exp) locP++;
                    else begin
                        locF++;
                        if (logged < FAIL_LOG_FIRST_N) begin
                            $display("    [%s] MISMATCH w%0d: got=0x%032h exp=0x%032h", label, i, rd, exp);
                            logged++;
                        end
                    end
                end else begin
                    lane_fail = 0;
                    for (lane = 0; lane < 4; lane++) begin
                        g_lane = rd[lane*32 +: 32];
                        e_lane = exp[lane*32 +: 32];
                        gf = $bitstoshortreal(g_lane);
                        ef = $bitstoshortreal(e_lane);
                        diff = (gf > ef) ? (gf - ef) : (ef - gf);
                        tol  = 1.0e-2 * ((ef > 0 ? ef : -ef) + 1.0);
                        if (g_lane !== e_lane && diff > tol) begin
                            lane_fail++;
                            if (logged < FAIL_LOG_FIRST_N) begin
                                $display("    [%s] FP MISMATCH w%0d lane%0d got=%f exp=%f",
                                         label, i, lane, gf, ef);
                                logged++;
                            end
                        end
                    end
                    if (lane_fail == 0) locP++; else locF++;
                end
            end
            $display("--- %s : %0d PASS, %0d FAIL ---", label, locP, locF);
            total_pass += locP;
            total_fail += locF;
        end
    endtask

    task automatic load_inst_axi(input int unsigned n_words);
        int i;
        reg [31:0] inst_mem [0:32767];
        begin
            $readmemh("inst.hex", inst_mem);
            for (i = 0; i < n_words; i++)
                host.axi_write32(E2E_INST_BASE + i*4, inst_mem[i]);
            $display("[%0t] Loaded %0d inst words to 0x%h (+INST_READMEMH if set)",
                     $time, n_words, E2E_INST_BASE);
        end
    endtask

    task automatic load_onchip_fast;
        int t;
        string fname;
        begin
            $display("[%0t] FAST_ONCHIP_LOAD: preload feature/weights directly to OBUF/IBUF", $time);
            $display("[%0t] FAST_ONCHIP_LOAD: input_feat.hex -> OBUF 0x%016h", $time, E2E_OBUF_BASE + OB_L1_IN);
            host.load_memh128("input_feat.hex", E2E_OBUF_BASE + OB_L1_IN);
            for (t = 0; t < L1_NUM_TILES; t++) begin
                fname = $sformatf("L1_weight_tile%0d.hex", t);
                $display("[%0t] FAST_ONCHIP_LOAD: %s -> IBUF 0x%016h", $time, fname, E2E_IBUF_BASE + 64'(24'h000000 + t * 24'h001000));
                host.load_memh128(fname, E2E_IBUF_BASE + 64'(24'h000000 + t * 24'h001000));
            end
            for (t = 0; t < L2_NUM_TILES; t++) begin
                fname = $sformatf("L2_weight_tile%0d.hex", t);
                $display("[%0t] FAST_ONCHIP_LOAD: %s -> IBUF 0x%016h", $time, fname, E2E_IBUF_BASE + 64'(24'h010000 + t * 24'h001000));
                host.load_memh128(fname, E2E_IBUF_BASE + 64'(24'h010000 + t * 24'h001000));
            end
            for (t = 0; t < L3_NUM_TILES; t++) begin
                fname = $sformatf("L3_weight_tile%0d.hex", t);
                $display("[%0t] FAST_ONCHIP_LOAD: %s -> IBUF 0x%016h", $time, fname, E2E_IBUF_BASE + 64'(24'h020000 + t * 24'h001000));
                host.load_memh128(fname, E2E_IBUF_BASE + 64'(24'h020000 + t * 24'h001000));
            end
            $display("[%0t] FAST_ONCHIP_LOAD: preload done", $time);
        end
    endtask

    task automatic wait_decoder_done(input int timeout_cycles);
        integer c;
        integer same_state_cycles;
        integer last_state;
        integer cur_state;
        integer last_word_idx;
        integer cur_word_idx;
        begin
            $display("[%0t] wait_decoder_done: monitoring decoder_done direct", $time);
            dump_decoder_diag("decoder_wait_begin");
            same_state_cycles = 0;
            last_state = -1;
            last_word_idx = -1;
            for (c = 0; c < timeout_cycles; c = c + 1) begin
                @(posedge aclk);
                cur_state = dut.lite_i.inst_decoder.inst.inst_decoder_sv.state;
                cur_word_idx = dut.lite_i.inst_decoder.inst.inst_decoder_sv.current_word_idx;

                if (cur_state != last_state || cur_word_idx != last_word_idx) begin
                    $display("[%0t] PROGRESS: decoder %s(%0d)->%s(%0d) word %0d->%0d rd_addr=%0d rd_data=0x%08h ready(vpu/cdma/dcim)=%0b/%0b/%0b",
                             $time,
                             dec_state_name(last_state), last_state,
                             dec_state_name(cur_state), cur_state,
                             last_word_idx, cur_word_idx,
                             dut.lite_i.inst_decoder_inst_rd_addr,
                             dut.lite_i.inst_bram_inst_rd_data,
                             dut.lite_i.vpu_0_ready,
                             dut.lite_i.cdma_ctrl_cdma_config_ready,
                             dut.lite_i.dcim_array_0_ready);
                    if (cur_state == DEC_S_PARSE_HEADER || cur_state == DEC_S_EXEC_CDMA ||
                        cur_state == DEC_S_EXEC_VPU || cur_state == DEC_S_EXEC_DCIM ||
                        cur_state == DEC_S_EXEC_SYNC || cur_state == DEC_S_ERROR)
                        dump_decoder_diag("state_event");
                    same_state_cycles = 0;
                    last_state = cur_state;
                    last_word_idx = cur_word_idx;
                end else begin
                    same_state_cycles++;
                    if ((same_state_cycles % DECODER_STALL_LOG_CYCLES) == 0)
                        dump_decoder_diag($sformatf("stall_%0d_cycles", same_state_cycles));
                end

                if ((c > 0) && ((c % DECODER_PROGRESS_LOG_CYCLES) == 0))
                    dump_decoder_diag($sformatf("periodic_%0d", c));

                if (dut.lite_i.inst_decoder_decoder_done) begin
                    $display("[%0t] Decoder done (direct monitor) after %0d cycles", $time, c);
                    dump_decoder_diag("decoder_done");
                    return;
                end
            end
            $display("FATAL: decoder timeout after %0d cycles", timeout_cycles);
            dump_decoder_diag("decoder_timeout");
            $finish(1);
        end
    endtask

    initial begin
        int i;
        reg [31:0] inst_mem [0:32767];
        int inst_count;
        int rst_wait;

        pci_rxn = 8'h0;
        pci_rxp = 8'h0;
        cpu_reset = 1'b1;
        total_pass = 0;
        total_fail = 0;

        $display("============================================================");
        $display("  tb_lite_bd_e2e case=%s verify_words=%0d", E2E_CASE_NAME, E2E_VERIFY_WORDS);
        $display("============================================================");

        wait (sim_axi_ready === 1'b1);
        @(posedge aclk);

        // Release board reset (active-high cpu_reset)
        repeat (50) @(posedge aclk);
        cpu_reset = 1'b0;
        repeat (50) @(posedge aclk);

        // Wait for AXI reset (or force if PCIe sim does not raise it)
        rst_wait = 0;
        while (!aresetn && rst_wait < 5000) begin
            @(posedge aclk);
            rst_wait++;
        end
        if (!aresetn) begin
            $display("[%0t] WARN: axi_aresetn still low — forcing high for sim", $time);
            force dut.lite_i.xdma_0_axi_aresetn = 1'b1;
        end
        repeat (20) @(posedge aclk);

        // Phase 0: host loads memories (HBM staging + inst + WB)
        if ($test$plusargs("FAST_ONCHIP_LOAD")) begin
            load_onchip_fast();
        end else if ($test$plusargs("SKIP_HBM_LOAD")) begin
            $display("[%0t] SKIP_HBM_LOAD: assume data preloaded", $time);
        end else begin
            host.load_memh128("hbm_image.hex", HBM_BASE);
        end
        host.load_memh128("wb_init.hex", E2E_WB_BASE);

        // Start decoder via direct hierarchy force instead of AXI write.
        // (AXI B-channel responses may not return in sim; direct drive is equivalent.)
        $readmemh("inst.hex", inst_mem);
        inst_count = 0;
        for (i = 0; i < 32768; i++)
            if (inst_mem[i][31:28] == 4'hF) begin inst_count = i + 1; break; end
        if ($test$plusargs("INST_READMEMH"))
            $display("[%0t] INST_READMEMH: skip AXI inst load (BRAM backdoor)", $time);
        else
            load_inst_axi(inst_count);

        $display("[%0t] Starting Decoder direct (inst_count=%0d)", $time, inst_count);
        dump_decoder_diag("before_decoder_start");
        force dut.lite_i.vpu_regs_inst_count  = inst_count;
        force dut.lite_i.vpu_regs_decoder_start = 1'b1;
        @(posedge aclk);
        dump_decoder_diag("decoder_start_asserted");
        release dut.lite_i.vpu_regs_decoder_start;
        repeat (4) @(posedge aclk);
        dump_decoder_diag("after_decoder_start_release");

        wait_decoder_done(50_000_000);
        repeat (64) @(posedge aclk);

        // Checkpoints (read OBUF via AXI)
        $readmemh("L1_im2col.hex", g_im2col);
        compare_checkpoint("L1_im2col", OB_L1_IM2COL, ck_words(L1_CHK_IM2COL), 0, 0);
        $readmemh("L1_accum.hex", g_accum);
        compare_checkpoint("L1_accum", OB_L1_ACCUM, ck_words(L1_CHK_ACCUM), 0, 1);
        $readmemh("L1_dqa.hex", g_dqa);
        compare_checkpoint("L1_dqa", OB_L1_DQA, ck_words(L1_CHK_ACCUM), 1, 2);
        $readmemh("L1_output.hex", g_output);
        compare_checkpoint("L1_output", OB_L1_OUT, ck_words(L1_CHK_OUTPUT), 0, 3);

        $readmemh("L2_im2col.hex", g_im2col);
        compare_checkpoint("L2_im2col", OB_L2_IM2COL, ck_words(L2_CHK_IM2COL), 0, 0);
        $readmemh("L2_accum.hex", g_accum);
        compare_checkpoint("L2_accum", OB_L2_ACCUM, ck_words(L2_CHK_ACCUM), 0, 1);
        $readmemh("L2_dqa.hex", g_dqa);
        compare_checkpoint("L2_dqa", OB_L2_DQA, ck_words(L2_CHK_ACCUM), 1, 2);
        $readmemh("L2_output.hex", g_output);
        compare_checkpoint("L2_output", OB_L2_OUT, ck_words(L2_CHK_OUTPUT), 0, 3);

        $readmemh("L3_im2col.hex", g_im2col);
        compare_checkpoint("L3_im2col", OB_L3_IM2COL, ck_words(L3_CHK_IM2COL), 0, 0);
        $readmemh("L3_accum.hex", g_accum);
        compare_checkpoint("L3_accum", OB_L3_ACCUM, ck_words(L3_CHK_ACCUM), 0, 1);
        $readmemh("L3_dqa.hex", g_dqa);
        compare_checkpoint("L3_dqa", OB_L3_DQA, ck_words(L3_CHK_ACCUM), 1, 2);
        $readmemh("L3_output.hex", g_output);
        compare_checkpoint("L3_output", OB_L3_OUT, ck_words(L3_CHK_OUTPUT), 0, 3);

        $display("============================================================");
        $display("  GRAND RESULTS: %0d PASS, %0d FAIL", total_pass, total_fail);
        if (total_fail == 0) $display("  ALL CHECKPOINTS PASSED");
        else                 $display("  SOME CHECKPOINTS FAILED");
        $display("============================================================");
        if (total_fail != 0) $finish(1);
        $finish;
    end

    initial begin : global_timeout
        longint unsigned c;
        wait (sim_axi_ready === 1'b1);
        for (c = 0; c < SIM_TIMEOUT_CYCLES; c = c + 1)
            @(posedge tb_aclk);
        $display("FATAL: global timeout (%0d AXI cycles after bring-up)", SIM_TIMEOUT_CYCLES);
        $finish(1);
    end

endmodule
