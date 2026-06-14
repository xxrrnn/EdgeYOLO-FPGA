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

    // chip-v3 XPM: VPU_BUF 和 tile_obuf 为单一连续 XPM 阵列，无需 bank decode
    localparam int VPU_BUF_AW       = `VPU_BUF_ADDR_WIDTH;     // 19 (8MB)
    localparam int TILE_OBUF_AW     = `DCIM_TILE_OBUF_ADDR_WIDTH;  // 14

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
    string preload_mode;

    function automatic bit addr_in_range(input [63:0] addr, input [63:0] base, input [63:0] size);
        begin
            addr_in_range = (addr >= base) && (addr < (base + size));
        end
    endfunction

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

    task automatic backdoor_read_obuf_word(input int unsigned word_addr, output [127:0] word128);
        begin
            word128 = dut.lite_i.vpu_0.inst.u_vpu_buf.u_uram.mem[word_addr];
        end
    endtask

    // chip-v3: checks.txt dst bit23 set → 读 tile_obuf
    // expected.hex 格式: for px, for tile(0..3), for word[0..WPT-1]
    // DCIM硬件: 每个 tile 地址空间独立，px N 的数据写在 addr = px*WPT + intra_w
    //   WPT = DCIM_CH_OUT/8 = 8
    localparam int DCIM_WORDS_PER_TILE_PX = (`DCIM_CH_OUT / 8);  // INT8: 64ch/tile ÷ 4ch/word = 8 (32-bit acc)
    localparam int DCIM_NUM_TILES_LC      = `DCIM_NUM_TILES;      // 4
    localparam int DCIM_OUT_STRIDE        = DCIM_NUM_TILES_LC * DCIM_WORDS_PER_TILE_PX; // 32
    localparam logic [23:0] TILE_OBUF_CHK_SENTINEL = 24'h80_0000; // bit23 = sentinel flag

    // 当前 check 使用的 wpt（words per tile per px），由 run_checks 写入，obuf_read_word128 读取
    int unsigned cur_wpt = 0;

    task automatic obuf_read_word128(input [23:0] obuf_byte_off, output [127:0] word128);
        int unsigned word_addr, tile_word_addr;
        int wpt, stride, tile_idx, px, intra_w;
        reg [63:0] addr;
        reg [255:0] rdat;
        begin
            if (preload_mode == "backdoor") begin
                if (obuf_byte_off[23]) begin
                    // tile_obuf 路径：expected.hex 按 [px][tile][intra_w] 排列
                    // 每个 tile 地址空间独立：物理 tile_word_addr = px * WPT + intra_w
                    wpt    = (cur_wpt > 0) ? int'(cur_wpt) : DCIM_WORDS_PER_TILE_PX;
                    stride = DCIM_NUM_TILES_LC * wpt;
                    word_addr    = int'((obuf_byte_off & 24'h7F_FFFF) >> 4);
                    px           = int'(word_addr) / stride;
                    tile_idx     = (int'(word_addr) % stride) / wpt;
                    intra_w      = int'(word_addr) % wpt;
                    tile_word_addr = px * wpt + intra_w;
                    backdoor_read_tile_obuf_word(tile_idx, tile_word_addr, word128);
                end else begin
                    // vpu_buf 路径
                    word_addr = int'(obuf_byte_off >> 4);
                    backdoor_read_obuf_word(word_addr, word128);
                end
            end else begin
                addr = E2E_OBUF_BASE + obuf_byte_off;
                repeat (OBUF_RD_WAIT) @(posedge aclk);
                host.axi_read256({addr[63:5], 5'b0}, rdat);
                word128 = addr[4] ? rdat[255:128] : rdat[127:0];
            end
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

    task automatic backdoor_write_ibuf_word(input int tile_idx, input int unsigned word_addr, input [127:0] word128);
        begin
            case (tile_idx)
                0: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_ibuf.u_uram.mem[word_addr] = word128;
                1: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[1].u_tile_ibuf.u_uram.mem[word_addr] = word128;
                2: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[2].u_tile_ibuf.u_uram.mem[word_addr] = word128;
                3: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[3].u_tile_ibuf.u_uram.mem[word_addr] = word128;
                4: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[4].u_tile_ibuf.u_uram.mem[word_addr] = word128;
                5: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[5].u_tile_ibuf.u_uram.mem[word_addr] = word128;
                6: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[6].u_tile_ibuf.u_uram.mem[word_addr] = word128;
                7: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[7].u_tile_ibuf.u_uram.mem[word_addr] = word128;
                default: begin
                    $display("FATAL: tile_ibuf backdoor tile=%0d out of range", tile_idx);
                    $finish(1);
                end
            endcase
        end
    endtask

    task automatic backdoor_write_obuf_word(input int unsigned word_addr, input [127:0] word128);
        begin
            dut.lite_i.vpu_0.inst.u_vpu_buf.u_uram.mem[word_addr] = word128;
        end
    endtask

    task automatic backdoor_write_tile_obuf_word(input int tile_idx, input int unsigned word_addr, input [127:0] word128);
        begin
            case (tile_idx)
                0: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.u_uram.mem[word_addr] = word128;
                1: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[1].u_tile_obuf.u_uram.mem[word_addr] = word128;
                2: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[2].u_tile_obuf.u_uram.mem[word_addr] = word128;
                3: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[3].u_tile_obuf.u_uram.mem[word_addr] = word128;
                4: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[4].u_tile_obuf.u_uram.mem[word_addr] = word128;
                5: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[5].u_tile_obuf.u_uram.mem[word_addr] = word128;
                6: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[6].u_tile_obuf.u_uram.mem[word_addr] = word128;
                7: dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[7].u_tile_obuf.u_uram.mem[word_addr] = word128;
                default: begin
                    $display("FATAL: tile_obuf backdoor tile=%0d out of range", tile_idx);
                    $finish(1);
                end
            endcase
        end
    endtask

    task automatic backdoor_read_tile_obuf_word(input int tile_idx, input int unsigned word_addr, output [127:0] word128);
        begin
            case (tile_idx)
                0: word128 = dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.u_uram.mem[word_addr];
                1: word128 = dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[1].u_tile_obuf.u_uram.mem[word_addr];
                2: word128 = dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[2].u_tile_obuf.u_uram.mem[word_addr];
                3: word128 = dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[3].u_tile_obuf.u_uram.mem[word_addr];
                4: word128 = dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[4].u_tile_obuf.u_uram.mem[word_addr];
                5: word128 = dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[5].u_tile_obuf.u_uram.mem[word_addr];
                6: word128 = dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[6].u_tile_obuf.u_uram.mem[word_addr];
                7: word128 = dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[7].u_tile_obuf.u_uram.mem[word_addr];
                 default: begin
                    $display("FATAL: tile_obuf backdoor read tile=%0d out of range", tile_idx);
                    $finish(1);
                end
            endcase
        end
    endtask

    task automatic backdoor_load_memh128(input string fname, input [63:0] base_addr);
        integer i, nwords, max_words;
        int unsigned word_addr;
        reg [127:0] mem [0:GOLDEN_DEPTH-1];
        begin
            max_words = GOLDEN_DEPTH;
            for (i = 0; i < max_words; i = i + 1)
                mem[i] = 128'hx;
            $display("[%0t] MODULE_TB: backdoor begin load %s -> 0x%016h", $time, fname, base_addr);
            $readmemh(fname, mem, 0, max_words - 1);
            nwords = 0;
            for (i = 0; i < max_words; i = i + 1) begin
                if (mem[i] !== 128'hx)
                    nwords = i + 1;
                else if (i > 0 && nwords > 0)
                    i = max_words;
            end

            if (addr_in_range(base_addr, E2E_IBUF_TILE0_BASE, E2E_IBUF_TILE_SIZE)) begin
                word_addr = (base_addr - E2E_IBUF_TILE0_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_ibuf_word(0, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_IBUF_TILE1_BASE, E2E_IBUF_TILE_SIZE)) begin
                word_addr = (base_addr - E2E_IBUF_TILE1_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_ibuf_word(1, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_IBUF_TILE2_BASE, E2E_IBUF_TILE_SIZE)) begin
                word_addr = (base_addr - E2E_IBUF_TILE2_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_ibuf_word(2, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_IBUF_TILE3_BASE, E2E_IBUF_TILE_SIZE)) begin
                word_addr = (base_addr - E2E_IBUF_TILE3_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_ibuf_word(3, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_IBUF_TILE4_BASE, E2E_IBUF_TILE_SIZE)) begin
                word_addr = (base_addr - E2E_IBUF_TILE4_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_ibuf_word(4, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_IBUF_TILE5_BASE, E2E_IBUF_TILE_SIZE)) begin
                word_addr = (base_addr - E2E_IBUF_TILE5_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_ibuf_word(5, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_IBUF_TILE6_BASE, E2E_IBUF_TILE_SIZE)) begin
                word_addr = (base_addr - E2E_IBUF_TILE6_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_ibuf_word(6, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_IBUF_TILE7_BASE, E2E_IBUF_TILE_SIZE)) begin
                word_addr = (base_addr - E2E_IBUF_TILE7_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_ibuf_word(7, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_IBUF_BASE, E2E_IBUF_SIZE)) begin
                // Broadcast: write ALL tiles with same data
                word_addr = (base_addr - E2E_IBUF_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1) begin : ibuf_bcast
                    integer t;
                    for (t = 0; t < E2E_NUM_TILES; t = t + 1)
                        backdoor_write_ibuf_word(t, word_addr + i, mem[i]);
                end
            end else if (addr_in_range(base_addr, E2E_VPU_BUF_BASE, E2E_VPU_BUF_SIZE)) begin
                word_addr = (base_addr - E2E_VPU_BUF_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_obuf_word(word_addr + i, mem[i]);
`ifdef SIMULATION
                $display("[%0t] DBG: VPU_BUF preload word_addr=0x%0h nwords=%0d mem[0]=0x%0h",
                         $time, word_addr, nwords,
                         dut.lite_i.vpu_0.inst.u_vpu_buf.u_uram.mem[0]);
`endif
            end else if (addr_in_range(base_addr, E2E_TILE_OBUF0_BASE, E2E_TILE_OBUF_SIZE)) begin
                word_addr = (base_addr - E2E_TILE_OBUF0_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_tile_obuf_word(0, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_TILE_OBUF1_BASE, E2E_TILE_OBUF_SIZE)) begin
                word_addr = (base_addr - E2E_TILE_OBUF1_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_tile_obuf_word(1, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_TILE_OBUF2_BASE, E2E_TILE_OBUF_SIZE)) begin
                word_addr = (base_addr - E2E_TILE_OBUF2_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_tile_obuf_word(2, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_TILE_OBUF3_BASE, E2E_TILE_OBUF_SIZE)) begin
                word_addr = (base_addr - E2E_TILE_OBUF3_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_tile_obuf_word(3, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_TILE_OBUF4_BASE, E2E_TILE_OBUF_SIZE)) begin
                word_addr = (base_addr - E2E_TILE_OBUF4_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_tile_obuf_word(4, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_TILE_OBUF5_BASE, E2E_TILE_OBUF_SIZE)) begin
                word_addr = (base_addr - E2E_TILE_OBUF5_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_tile_obuf_word(5, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_TILE_OBUF6_BASE, E2E_TILE_OBUF_SIZE)) begin
                word_addr = (base_addr - E2E_TILE_OBUF6_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_tile_obuf_word(6, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_TILE_OBUF7_BASE, E2E_TILE_OBUF_SIZE)) begin
                word_addr = (base_addr - E2E_TILE_OBUF7_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    backdoor_write_tile_obuf_word(7, word_addr + i, mem[i]);
            end else if (addr_in_range(base_addr, E2E_WB_BASE, E2E_WB_SIZE)) begin
                word_addr = (base_addr - E2E_WB_BASE) >> 4;
                for (i = 0; i < nwords; i = i + 1)
                    dut.lite_i.vpu_0.inst.u_global_vpu.wb_bram.BRAM[word_addr + i] = mem[i];
            end else begin
                $display("FATAL: unsupported backdoor preload address 0x%016h for %s", base_addr, fname);
                $finish(1);
            end
            $display("[%0t] MODULE_TB: backdoor done load %s, %0d x128b words", $time, fname, nwords);
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
                    $display("[%0t] MODULE_TB: preload[%0d] mode=%s %s -> 0x%016h", $time, n, preload_mode, mem_path, base_addr);
                    if (preload_mode == "axi")
                        host.load_memh128(mem_path, base_addr);
                    else
                        backdoor_load_memh128(mem_path, base_addr);
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
        int unsigned check_words, is_fp32, wpt;
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
                wpt = 0;
                rc = $fscanf(fd, "%s %s %h %d %d %d\n", check_name, expected_fname, dst_obuf, check_words, is_fp32, wpt);
                if (rc >= 5) begin
                    cur_wpt = wpt;  // 设置当前 wpt（0 表示使用 INT8 默认值）
                    if (dst_obuf[23]) begin
                        $display("[%0t] DEBUG tile_obuf[0] mem: [0]=%h [1]=%h [4]=%h [7]=%h [8]=%h",
                            $time,
                            dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.u_uram.mem[0],
                            dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.u_uram.mem[1],
                            dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.u_uram.mem[4],
                            dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.u_uram.mem[7],
                            dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.u_uram.mem[8]);
                    end else begin
                        // VPU_BUF 路径：dump dst word 附近
                        begin : _vpu_dbg
                            int _w, _scan;
                            int _nonzero_w;
                            _w = int'(dst_obuf >> 4);
                            // scan first 4096 words for non-zero
                            _nonzero_w = -1;
                            for (_scan = 0; _scan < 4096; _scan++) begin
                                if (dut.lite_i.vpu_0.inst.u_vpu_buf.u_uram.mem[_scan] !== 0) begin
                                    if (_nonzero_w == -1) _nonzero_w = _scan;
                                end
                            end
                            $display("[%0t] DEBUG VPU_BUF mem[0]=%h mem[%0d]=%h first_nonzero_w=%0d",
                                $time,
                                dut.lite_i.vpu_0.inst.u_vpu_buf.u_uram.mem[0],
                                _w, dut.lite_i.vpu_0.inst.u_vpu_buf.u_uram.mem[_w],
                                _nonzero_w);
                        end
                    end
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
        if (!$value$plusargs("PRELOAD_MODE=%s", preload_mode))
            preload_mode = "backdoor";
        if (preload_mode != "backdoor" && preload_mode != "axi") begin
            $display("FATAL: invalid PRELOAD_MODE=%s (use backdoor or axi)", preload_mode);
            $finish(1);
        end
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
            $display("  preload_mode=%s", preload_mode);
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

    // Debug: Monitor DCIM tile[0] obuf_wr_valid
    always @(posedge dut.lite_i.dcim_array_0.inst.clk) begin
        if (dut.lite_i.dcim_array_0.inst.u_dcim_array.tile_obuf_wr_valid[0]) begin
            $display("[%0t] DCIM_ARRAY tile_obuf_wr_valid[0] fired: addr=%0h",
                $time,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.tile_obuf_wr_addr[0 +: 14]);
        end
        if (dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.mem_enb &&
            |dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.web) begin
            $display("[%0t] TILE_OBUF[0] PortB WRITE: addr=%0h dinb[31:0]=%08h",
                $time,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.addrb,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile_obuf.dinb[31:0]);
        end
    end

    // Debug: Monitor DCIM start signal
    always @(posedge dut.lite_i.dcim_array_0.inst.clk) begin
        if (dut.lite_i.dcim_array_0.inst.u_dcim_array.start) begin
            $display("[%0t] DCIM_ARRAY START fired, mode=%0h acc_depth=%0d tile_mask=%0h out_base[0]=%0h",
                $time,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.mode,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.acc_depth,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.tile_mask,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.out_base_addrs[0 +: 14]);
        end
        if (dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile.start_pulse) begin
            $display("[%0t] DCIM_TILE[0] start_pulse, out_base=%0h state=%0d save_state=%0d",
                $time,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile.out_base_addr_reg,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile.state,
                dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile.save_state);
        end
        // Monitor DCIM_Tile state changes
        if (dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile.state ==
            dut.lite_i.dcim_array_0.inst.u_dcim_array.gen_tiles[0].u_tile.ST_DONE) begin
            $display("[%0t] DCIM_TILE[0] ST_DONE reached", $time);
        end
    end

endmodule
