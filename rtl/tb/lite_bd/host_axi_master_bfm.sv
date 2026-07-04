`timescale 1ns / 1ns
// AXI4 full master BFM (64b addr, 256b data) for force-driving xdma_0/M_AXI in lite BD sim.
//
// Key design decisions for hardware-consistent BD sim:
//   - m_axi_bready and m_axi_rready are PERMANENTLY asserted in a background always block.
//     This prevents the SmartConnect (axi_mem_smc) from stalling when a write BVALID
//     arrives while the task-level code is not watching: if m_axi_bready ever goes low
//     after an outstanding write, the SMC blocks further read transactions until bready
//     is re-asserted. Permanent bready avoids this deadlock.
//   - axi_write256: issues AW + W simultaneously (for Xilinx BRAM ctrl compatibility),
//     then waits for BVALID with a generous timeout. The permanent bready ensures the SMC
//     routes BVALID back promptly.
//   - axi_read256: waits for RVALID with a generous timeout. After fixing the bready
//     deadlock, RVALID should return normally through the SMC chain.
//   - AXI_TIMEOUT_CYCLES: set to 500000 (~2ms @ 250MHz). Enough for BRAM/URAM read
//     latency through two SmartConnect stages.

module host_axi_master_bfm #(
    parameter int ADDR_W  = 64,
    parameter int DATA_W  = 256,
    parameter int ID_W    = 4
)(
    input  wire aclk,
    input  wire aresetn,

    output reg  [ADDR_W-1:0]         m_axi_awaddr,
    output reg  [7:0]                m_axi_awlen,
    output reg  [2:0]                m_axi_awsize,
    output reg  [1:0]                m_axi_awburst,
    output reg  [2:0]                m_axi_awprot,
    output reg  [ID_W-1:0]           m_axi_awid,
    output reg                       m_axi_awlock,
    output reg  [3:0]                m_axi_awcache,
    output reg                       m_axi_awvalid,
    input  wire                      m_axi_awready,

    output reg  [DATA_W-1:0]         m_axi_wdata,
    output reg  [DATA_W/8-1:0]       m_axi_wstrb,
    output reg                       m_axi_wlast,
    output reg                       m_axi_wvalid,
    input  wire                      m_axi_wready,

    input  wire [ID_W-1:0]           m_axi_bid,
    input  wire [1:0]                m_axi_bresp,
    input  wire                      m_axi_bvalid,
    output wire                      m_axi_bready,

    output reg  [ADDR_W-1:0]         m_axi_araddr,
    output reg  [7:0]                m_axi_arlen,
    output reg  [2:0]                m_axi_arsize,
    output reg  [1:0]                m_axi_arburst,
    output reg  [2:0]                m_axi_arprot,
    output reg  [ID_W-1:0]           m_axi_arid,
    output reg                       m_axi_arlock,
    output reg  [3:0]                m_axi_arcache,
    output reg                       m_axi_arvalid,
    input  wire                      m_axi_arready,

    input  wire [DATA_W-1:0]         m_axi_rdata,
    input  wire [ID_W-1:0]           m_axi_rid,
    input  wire [1:0]                m_axi_rresp,
    input  wire                      m_axi_rlast,
    input  wire                      m_axi_rvalid,
    output wire                      m_axi_rready
);

    // bready and rready are permanently and combinationally asserted so the
    // SmartConnect never stalls on pending B/R responses. Using assign (not
    // clocked reg) avoids NBA-update timing issues where bvalid arrives before
    // bready has been clocked in.
    assign m_axi_bready = 1'b1;
    assign m_axi_rready = 1'b1;

    localparam int STRB_W = DATA_W / 8;
    localparam int SIZE_256 = 3'd5;

    // Generous timeout: through two SmartConnect stages + BRAM/URAM latency.
    // After fixing the permanent-bready deadlock, BVALID/RVALID should arrive
    // within a few hundred cycles under normal conditions.
    localparam int AXI_TIMEOUT_CYCLES = 500000;

    // -----------------------------------------------------------------------
    // Static signal initialization
    // -----------------------------------------------------------------------
    initial begin
        m_axi_awvalid <= 0; m_axi_wvalid  <= 0;
        m_axi_arvalid <= 0;
        m_axi_awaddr  <= 0; m_axi_awlen   <= 0; m_axi_awsize  <= SIZE_256;
        m_axi_awburst <= 2'b01; m_axi_awprot <= 0;
        m_axi_awid    <= 0; m_axi_awlock  <= 0; m_axi_awcache <= 4'b0011;
        m_axi_wdata   <= 0; m_axi_wstrb   <= 0; m_axi_wlast   <= 0;
        m_axi_araddr  <= 0; m_axi_arlen   <= 0; m_axi_arsize  <= SIZE_256;
        m_axi_arburst <= 2'b01; m_axi_arprot  <= 0;
        m_axi_arid    <= 0; m_axi_arlock  <= 0; m_axi_arcache <= 4'b0011;
        // bready/rready are permanently driven by assign statements above
    end

    // -----------------------------------------------------------------------
    // Timeout helper: wait for condition, log and continue on timeout.
    // Used inside tasks for AWREADY, WREADY, BVALID, ARREADY, RVALID.
    // -----------------------------------------------------------------------
    `define HOST_BFM_WAIT_OR_TIMEOUT(LABEL, ADDR_EXPR, BEAT_EXPR, COND_EXPR) \
        begin \
            integer __bfm_t; \
            __bfm_t = 0; \
            while (!(COND_EXPR)) begin \
                @(posedge aclk); \
                __bfm_t++; \
                if (__bfm_t == 100) \
                    $display("[%0t] DBG: waiting %s addr=0x%016h awrdy=%0b wrdy=%0b bvld=%0b arvld=%0b rvld=%0b", \
                             $time, LABEL, ADDR_EXPR, m_axi_awready, m_axi_wready, m_axi_bvalid, m_axi_arvalid, m_axi_rvalid); \
                if (__bfm_t >= AXI_TIMEOUT_CYCLES) begin \
                    $display("WARN: HOST_BFM TIMEOUT %s addr=0x%016h beat=%0d after %0d cycles", \
                             LABEL, ADDR_EXPR, BEAT_EXPR, __bfm_t); \
                    break; \
                end \
            end \
        end

    // -----------------------------------------------------------------------
    task wait_reset;
        begin
            while (!aresetn) @(posedge aclk);
            repeat (4) @(posedge aclk);
        end
    endtask

    // -----------------------------------------------------------------------
    // axi_write256_masked: single-beat write with explicit strobe/size.
    // Use partial wstrb for narrow stores (e.g. INST_BRAM 32-bit AXI-Lite);
    // full strobe is only for true 256-bit line writes (OBUF/IBUF preload).
    // -----------------------------------------------------------------------
    task axi_write256_masked(
        input [ADDR_W-1:0]         addr,
        input [DATA_W-1:0]         data,
        input [STRB_W-1:0]         strb,
        input [2:0]                size
    );
        begin
            @(posedge aclk);
            m_axi_awaddr  <= addr;
            m_axi_awlen   <= 8'd0;
            m_axi_awsize  <= size;
            m_axi_awburst <= 2'b01;
            m_axi_awvalid <= 1'b1;

            m_axi_wdata   <= data;
            m_axi_wstrb   <= strb;
            m_axi_wlast   <= 1'b1;
            m_axi_wvalid  <= 1'b1;

            fork
                begin
                    `HOST_BFM_WAIT_OR_TIMEOUT("AWVALID&&AWREADY", addr, 0, (m_axi_awvalid && m_axi_awready))
                    m_axi_awvalid <= 1'b0;
                end
                begin
                    `HOST_BFM_WAIT_OR_TIMEOUT("WVALID&&WREADY", addr, 0, (m_axi_wvalid && m_axi_wready))
                    m_axi_wvalid  <= 1'b0;
                    m_axi_wlast   <= 1'b0;
                end
            join

            `HOST_BFM_WAIT_OR_TIMEOUT("BVALID&&BREADY", addr, 0, (m_axi_bvalid && m_axi_bready))
            if (m_axi_bresp != 2'b00)
                $display("HOST_BFM: WRITE BRESP=%0d @ %h", m_axi_bresp, addr);
            @(posedge aclk);
        end
    endtask

    task axi_write256(input [ADDR_W-1:0] addr, input [DATA_W-1:0] data);
        axi_write256_masked(addr, data, {STRB_W{1'b1}}, SIZE_256);
    endtask

    // 32-bit store into a 256-bit-aligned line (INST_BRAM / VPU regs).
    task axi_write32(input [ADDR_W-1:0] byte_addr, input [31:0] data);
        reg [DATA_W-1:0] beat;
        reg [STRB_W-1:0] strb;
        int unsigned lane;
        begin
            lane = byte_addr[4:0];
            beat = 0;
            strb = 0;
            beat[lane*8 +: 32] = data;
            strb[lane +: 4]    = 4'hF;
            axi_write256_masked({byte_addr[ADDR_W-1:5], 5'b0}, beat, strb, 3'd2);
        end
    endtask

    // -----------------------------------------------------------------------
    // axi_read256: issue AR, wait for RVALID. With permanent rready and no
    // pending-bvalid stall, RVALID arrives promptly through the SMC chain.
    // -----------------------------------------------------------------------
    task axi_read256(input [ADDR_W-1:0] addr, output [DATA_W-1:0] data);
        begin
            data = {DATA_W{1'bx}};
            @(posedge aclk);
            m_axi_araddr  <= addr;
            m_axi_arlen   <= 8'd0;
            m_axi_arsize  <= SIZE_256;
            m_axi_arburst <= 2'b01;
            m_axi_arvalid <= 1'b1;
            `HOST_BFM_WAIT_OR_TIMEOUT("ARVALID&&ARREADY", addr, 0, (m_axi_arvalid && m_axi_arready))
            m_axi_arvalid <= 1'b0;
            `HOST_BFM_WAIT_OR_TIMEOUT("RVALID&&RREADY", addr, 0, (m_axi_rvalid && m_axi_rready))
            data = m_axi_rdata;
            if (m_axi_rresp != 2'b00)
                $display("HOST_BFM: READ RRESP=%0d @ %h", m_axi_rresp, addr);
            @(posedge aclk);
        end
    endtask

    // -----------------------------------------------------------------------
    // load_memh128: load a hex file and write all words over AXI.
    // -----------------------------------------------------------------------
    task load_memh128(input string fname, input [ADDR_W-1:0] base_addr);
        integer i, nwords, beats, bi, max_words;
        reg [127:0] mem [0:262143];
        reg [DATA_W-1:0] beat;
        begin
            max_words = 262144;
            for (i = 0; i < max_words; i = i + 1) mem[i] = 128'hx;
            $display("[%0t] HOST_BFM: begin load %s -> 0x%016h", $time, fname, base_addr);
            $readmemh(fname, mem, 0, max_words - 1);
            nwords = 0;
            for (i = 0; i < max_words; i = i + 1)
                if (mem[i] !== 128'hx) nwords = i + 1;
                else if (i > 0 && nwords > 0) i = max_words;
            beats = (nwords * 16 + 31) / 32;
            $display("[%0t] HOST_BFM: %s has %0d x128b words (%0d AXI beats)", $time, fname, nwords, beats);
            for (bi = 0; bi < beats; bi = bi + 1) begin
                beat = 0;
                if (bi*2   < nwords) beat[127:0]   = mem[bi*2];
                if (bi*2+1 < nwords) beat[255:128] = mem[bi*2+1];
                if ((bi % 256) == 0)
                    $display("[%0t] HOST_BFM: loading %s beat %0d/%0d addr=0x%016h",
                             $time, fname, bi, beats, base_addr + bi*32);
                axi_write256(base_addr + bi*32, beat);
            end
            $display("[%0t] HOST_BFM: done load %s, %0d x128b words -> 0x%016h",
                     $time, fname, nwords, base_addr);
        end
    endtask

endmodule
