`timescale 1ps / 1ps
`include "chip_defines.vh"
`include "lite_addrmap.svh"
`ifndef LITE_BD_DUT
  `define LITE_BD_DUT dut
`endif
`define LITE_BD_DUT tb_lite_bd_module.dut
`include "lite_bd_hier.svh"

module tb_lite_bd_module;

    glbl glbl_inst ();

    localparam int CLK_PERIOD_PS = 4000;
    localparam int REFCLK_PERIOD_PS = 10000;
    localparam int OBUF_RD_WAIT = 20;
    localparam int FAIL_LOG_FIRST_N = 16;
    localparam int GOLDEN_DEPTH = 262144;
    localparam int SIM_TIMEOUT_CYCLES = 200_000_000;
    localparam int MAX_INST_WORDS = 32768;
    localparam int MAX_PRELOADS = 1024;
    localparam int MAX_CHECKS = 1024;
    localparam int MAX_SUITE_CASES = 1024;

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
        .pcie_refclk_clk_n   (pcie_refclk_n),
        .pcie_refclk_clk_p   (pcie_refclk_p),
        .user_lnk_up_0       (user_lnk_up)
    );

    reg tb_aclk;
    bit sim_axi_ready;
    string run_dir;
    string suite_base_dir;

    initial begin : fsdb_dump_control
        if ($test$plusargs("FSDB")) begin
            $fsdbDumpfile("tb_lite_bd_module.fsdb");
            $fsdbDumpvars(0, tb_lite_bd_module, "+mda");
            $fsdbDumpMDA();
            $display("[%0t] MODULE_TB: FSDB dump enabled: tb_lite_bd_module.fsdb", $time);
        end
    end

    initial begin
        pcie_refclk_p = 1'b0;
        pcie_refclk_n = 1'b1;
        forever begin
            #(REFCLK_PERIOD_PS/2);
            pcie_refclk_p = ~pcie_refclk_p;
            pcie_refclk_n = ~pcie_refclk_n;
        end
    end

    initial begin
        tb_aclk = 1'b0;
        forever begin
            #(CLK_PERIOD_PS/2);
            tb_aclk = ~tb_aclk;
        end
    end

    initial begin
        force dut.lite_i.xdma_0_axi_aclk = tb_aclk;
        force dut.lite_i.xdma_0_axi_aresetn = 1'b0;
        repeat (64) @(posedge tb_aclk);
        release dut.lite_i.xdma_0_axi_aresetn;
        repeat (16) @(posedge tb_aclk);
        if (!dut.lite_i.xdma_0_axi_aresetn)
            force dut.lite_i.xdma_0_axi_aresetn = 1'b1;
        sim_axi_ready = 1'b1;
        $display("[%0t] MODULE_TB: TB AXI clk/reset up", $time);
    end

    wire aclk = tb_aclk;
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
        force `LITE_BD_M_AXI_AWADDR  = host.m_axi_awaddr;
        force `LITE_BD_M_AXI_AWLEN   = host.m_axi_awlen;
        force `LITE_BD_M_AXI_AWSIZE  = host.m_axi_awsize;
        force `LITE_BD_M_AXI_AWBURST = host.m_axi_awburst;
        force `LITE_BD_M_AXI_AWPROT  = host.m_axi_awprot;
        force `LITE_BD_M_AXI_AWID    = host.m_axi_awid;
        force `LITE_BD_M_AXI_AWLOCK  = host.m_axi_awlock;
        force `LITE_BD_M_AXI_AWCACHE = host.m_axi_awcache;
        force `LITE_BD_M_AXI_WVALID  = host.m_axi_wvalid;
        force `LITE_BD_M_AXI_WDATA   = host.m_axi_wdata;
        force `LITE_BD_M_AXI_WSTRB   = host.m_axi_wstrb;
        force `LITE_BD_M_AXI_WLAST   = host.m_axi_wlast;
        force `LITE_BD_M_AXI_BREADY  = host.m_axi_bready;
        force `LITE_BD_M_AXI_ARVALID = host.m_axi_arvalid;
        force `LITE_BD_M_AXI_ARADDR  = host.m_axi_araddr;
        force `LITE_BD_M_AXI_ARLEN   = host.m_axi_arlen;
        force `LITE_BD_M_AXI_ARSIZE  = host.m_axi_arsize;
        force `LITE_BD_M_AXI_ARBURST = host.m_axi_arburst;
        force `LITE_BD_M_AXI_ARPROT  = host.m_axi_arprot;
        force `LITE_BD_M_AXI_ARID    = host.m_axi_arid;
        force `LITE_BD_M_AXI_ARLOCK  = host.m_axi_arlock;
        force `LITE_BD_M_AXI_ARCACHE = host.m_axi_arcache;
        force `LITE_BD_M_AXI_RREADY  = host.m_axi_rready;

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
        $display("[%0t] MODULE_TB: forced host BFM -> xdma_0 M_AXI", $time);
    end

    integer total_pass, total_fail;
    int tb_inst_count;
    reg [127:0] expected [0:GOLDEN_DEPTH-1];

    function automatic string make_path(input string base, input string fname);
        begin
            if (fname.len() > 0 && fname.getc(0) == 8'h2f)
                make_path = fname;
            else
                make_path = {base, "/", fname};
        end
    endfunction

    function automatic string run_path(input string fname);
        begin
            run_path = make_path(run_dir, fname);
        end
    endfunction

    task automatic obuf_read_word128(input [23:0] obuf_byte_off, output [127:0] word128);
        reg [63:0] addr;
        reg [255:0] rdat;
        begin
            addr = E2E_OBUF_BASE + obuf_byte_off;
            repeat (OBUF_RD_WAIT) @(posedge aclk);
            host.axi_read256({addr[63:5], 5'b0}, rdat);
            word128 = addr[4] ? rdat[255:128] : rdat[127:0];
        end
    endtask

    task automatic compare_expected(
        input string check_name,
        input string expected_fname,
        input [23:0] dst_obuf,
        input int unsigned check_words,
        input int unsigned is_fp32
    );
        integer i, lane, logged, lane_fail;
        reg [127:0] got, exp;
        reg [31:0] g32, e32;
        real gf, ef, diff, tol;
        string expected_path;
        begin
            expected_path = run_path(expected_fname);
            for (i = 0; i < GOLDEN_DEPTH; i = i + 1)
                expected[i] = 128'hx;
            $readmemh(expected_path, expected);
            $display("[%0t] MODULE_TB: check %s expected=%s dst=0x%06h words=%0d fp32=%0d",
                     $time, check_name, expected_path, dst_obuf, check_words, is_fp32);
            logged = 0;
            for (i = 0; i < check_words; i++) begin
                obuf_read_word128(dst_obuf + i * 16, got);
                exp = expected[i];
                if (is_fp32 == 0) begin
                    if (got === exp) begin
                        total_pass++;
                    end else begin
                        total_fail++;
                        if (logged < FAIL_LOG_FIRST_N) begin
                            $display("MISMATCH %s word%0d got=0x%032h exp=0x%032h", check_name, i, got, exp);
                            logged++;
                        end
                    end
                end else begin
                    lane_fail = 0;
                    for (lane = 0; lane < 4; lane++) begin
                        g32 = got[lane*32 +: 32];
                        e32 = exp[lane*32 +: 32];
                        gf = $bitstoshortreal(g32);
                        ef = $bitstoshortreal(e32);
                        diff = (gf > ef) ? (gf - ef) : (ef - gf);
                        tol = 1.0e-2 * ((ef > 0 ? ef : -ef) + 1.0);
                        if (g32 !== e32 && diff > tol)
                            lane_fail++;
                    end
                    if (lane_fail == 0) begin
                        total_pass++;
                    end else begin
                        total_fail++;
                        if (logged < FAIL_LOG_FIRST_N) begin
                            $display("FP MISMATCH %s word%0d got=0x%032h exp=0x%032h", check_name, i, got, exp);
                            logged++;
                        end
                    end
                end
            end
        end
    endtask

    task automatic load_inst_bram(input string inst_fname);
        begin
            // AXI 写 INST_BRAM 在 BD 仿真中 B-channel 可能不返回（见 tb_lite_bd_e2e.sv），
            // 必须用层次化 backdoor；suite 多 case 也需每轮重载。
            $readmemh(inst_fname, dut.lite_i.inst_bram.inst.mem);
            $display("[%0t] MODULE_TB: INST_BRAM backdoor load from %s", $time, inst_fname);
        end
    endtask

    task automatic run_preloads(input string preload_fname);
        integer fd, rc, n;
        string mem_fname, mem_path;
        reg [63:0] base_addr;
        begin
            fd = $fopen(preload_fname, "r");
            if (fd == 0) begin
                $display("FATAL: cannot open preload list %s", preload_fname);
                $finish(1);
            end
            n = 0;
            while (!$feof(fd)) begin
                mem_fname = "";
                base_addr = 64'h0;
                rc = $fscanf(fd, "%s %h\n", mem_fname, base_addr);
                if (rc == 2) begin
                    mem_path = run_path(mem_fname);
                    $display("[%0t] MODULE_TB: preload[%0d] %s -> 0x%016h", $time, n, mem_path, base_addr);
                    host.load_memh128(mem_path, base_addr);
                    n++;
                    if (n >= MAX_PRELOADS) begin
                        $display("FATAL: too many preload entries");
                        $finish(1);
                    end
                end
            end
            $fclose(fd);
            $display("[%0t] MODULE_TB: loaded %0d preload entries", $time, n);
        end
    endtask

    task automatic run_checks(input string checks_fname);
        integer fd, rc, n;
        string check_name, expected_fname;
        reg [23:0] dst_obuf;
        int unsigned check_words, is_fp32;
        begin
            fd = $fopen(checks_fname, "r");
            if (fd == 0) begin
                $display("FATAL: cannot open checks list %s", checks_fname);
                $finish(1);
            end
            n = 0;
            while (!$feof(fd)) begin
                check_name = "";
                expected_fname = "";
                dst_obuf = 24'h0;
                check_words = 0;
                is_fp32 = 0;
                rc = $fscanf(fd, "%s %s %h %d %d\n", check_name, expected_fname, dst_obuf, check_words, is_fp32);
                if (rc == 5) begin
                    compare_expected(check_name, expected_fname, dst_obuf, check_words, is_fp32);
                    n++;
                    if (n >= MAX_CHECKS) begin
                        $display("FATAL: too many check entries");
                        $finish(1);
                    end
                end
            end
            $fclose(fd);
            $display("[%0t] MODULE_TB: completed %0d check entries", $time, n);
        end
    endtask

    task automatic count_inst_words(input string inst_fname, output int inst_count);
        int i;
        reg [31:0] inst_mem [0:MAX_INST_WORDS-1];
        begin
            for (i = 0; i < MAX_INST_WORDS; i = i + 1)
                inst_mem[i] = 32'hx;
            $readmemh(inst_fname, inst_mem);
            inst_count = 0;
            for (i = 0; i < MAX_INST_WORDS; i++) begin
                if (inst_mem[i][31:28] == 4'hF) begin
                    inst_count = i + 1;
                    break;
                end
            end
            if (inst_count == 0) begin
                $display("FATAL: no OP_END found in %s", inst_fname);
                $finish(1);
            end
        end
    endtask

    task automatic start_decoder_and_wait(input int inst_count);
        begin
            tb_inst_count = inst_count;
            force `LITE_BD_VPU_INST_COUNT = tb_inst_count;
            force `LITE_BD_DECODER_START  = 1'b0;
            repeat (4) @(posedge aclk);
            $display("[%0t] Starting Decoder direct (inst_count=%0d)", $time, inst_count);
            force `LITE_BD_DECODER_START = 1'b1;
            @(posedge aclk);
            force `LITE_BD_DECODER_START = 1'b0;
            repeat (2) @(posedge aclk);
            release `LITE_BD_DECODER_START;

            begin : wait_decoder_done_hier
                integer dw;
                dw = 0;
                while (dw < 50_000_000) begin
                    @(posedge aclk);
                    dw++;
                    if (`LITE_BD_DECODER_DONE === 1'b1) begin
                        $display("[%0t] Decoder done (hierarchy) at %0d cycles", $time, dw);
                        $display("[%0t] DIAG: vpu_start=%0b unit=%0d vpu_ready=%0b dec_opcode=0x%0h body0=0x%08h",
                                 $time,
                                 dut.lite_i.inst_decoder_vpu_start,
                                 dut.lite_i.inst_decoder_vpu_unit_choose,
                                 dut.lite_i.vpu_0_ready,
                                 dut.lite_i.inst_decoder.inst.inst_decoder_sv.current_opcode,
                                 dut.lite_i.inst_decoder.inst.inst_decoder_sv.body_buffer[0]);
                        disable wait_decoder_done_hier;
                    end
                end
                if (dw >= 50_000_000) begin
                    $display("FATAL: decoder timeout");
                    $finish(1);
                end
            end
            repeat (64) @(posedge aclk);
        end
    endtask

    task automatic run_one_case(input string case_dir, input int case_idx);
        int inst_count;
        string inst_path, preload_path, checks_path, manifest_path;
        begin
            run_dir = case_dir;
            inst_path = run_path("inst.hex");
            preload_path = run_path("preload.txt");
            checks_path = run_path("checks.txt");
            manifest_path = run_path("manifest.txt");

            $display("============================================================");
            $display("  MODULE_TB CASE[%0d] run_dir=%s", case_idx, run_dir);
            $display("  manifest=%s", manifest_path);
            $display("============================================================");

            run_preloads(preload_path);
            count_inst_words(inst_path, inst_count);
            load_inst_bram(inst_path);
            start_decoder_and_wait(inst_count);
            run_checks(checks_path);
        end
    endtask

    task automatic run_suite(input string suite_fname);
        integer fd, rc, n;
        string case_dir, case_path;
        begin
            fd = $fopen(suite_fname, "r");
            if (fd == 0) begin
                $display("FATAL: cannot open suite file %s", suite_fname);
                $finish(1);
            end
            n = 0;
            while (!$feof(fd)) begin
                case_dir = "";
                rc = $fscanf(fd, "%s\n", case_dir);
                if (rc == 1) begin
                    case_path = make_path(suite_base_dir, case_dir);
                    run_one_case(case_path, n);
                    n++;
                    if (n >= MAX_SUITE_CASES) begin
                        $display("FATAL: too many suite cases");
                        $finish(1);
                    end
                end
            end
            $fclose(fd);
            $display("[%0t] MODULE_TB: completed suite %s with %0d cases", $time, suite_fname, n);
        end
    endtask

    initial begin
        int rst_wait;
        string suite_file;
        bit suite_mode;

        pci_rxn = 8'h0;
        pci_rxp = 8'h0;
        cpu_reset = 1'b1;
        total_pass = 0;
        total_fail = 0;
        run_dir = ".";
        if (!$value$plusargs("RUN_DIR=%s", run_dir))
            run_dir = ".";
        suite_base_dir = run_dir;
        suite_file = run_path("suite.txt");
        suite_mode = $value$plusargs("SUITE_FILE=%s", suite_file);

        wait (sim_axi_ready === 1'b1);
        @(posedge aclk);
        repeat (50) @(posedge aclk);
        cpu_reset = 1'b0;
        repeat (50) @(posedge aclk);

        rst_wait = 0;
        while (!aresetn && rst_wait < 5000) begin
            @(posedge aclk);
            rst_wait++;
        end
        if (!aresetn)
            force dut.lite_i.xdma_0_axi_aresetn = 1'b1;
        repeat (20) @(posedge aclk);

        $display("[%0t] MODULE_TB: bypass HBM init", $time);
        // module_tb does not access HBM; lite_hbm_stub.sv replaces the full HBM PHY model.
        // Avoid waiting for or forcing HBM clkwiz/proc_sys_reset signals, which can trigger
        // zero-time event storms in the vendor simulation models.
        repeat (64) @(posedge aclk);
        $display("[%0t] MODULE_TB: fabric ready", $time);

        if (suite_mode) begin
            $display("============================================================");
            $display("  tb_lite_bd_module SUITE suite_file=%s", suite_file);
            $display("  suite_base_dir=%s", suite_base_dir);
            $display("============================================================");
            run_suite(suite_file);
        end else begin
            run_one_case(run_dir, 0);
        end

        $display("============================================================");
        $display("  MODULE RESULTS: %0d PASS, %0d FAIL", total_pass, total_fail);
        if (total_fail == 0) $display("  MODULE CHECK PASSED");
        else                 $display("  MODULE CHECK FAILED");
        $display("============================================================");
        if (total_fail != 0) $finish(1);
        $finish;
    end

    initial begin : global_timeout
        longint unsigned c;
        wait (sim_axi_ready === 1'b1);
        for (c = 0; c < SIM_TIMEOUT_CYCLES; c++)
            @(posedge tb_aclk);
        $display("FATAL: global timeout");
        $finish(1);
    end

endmodule
