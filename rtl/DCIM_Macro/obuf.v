
//  Xilinx UltraRAM True Dual Port Mode - Byte write with Multi-Bank Architecture
//  ============================================================================
//  优化版本 v6（250MHz）：写侧 reg3 + 读侧 addr 预寄存 + URAM 读 + mem_rstage + NBPIPE
//
//  关键优化：
//  1. 多 Bank 并行（NUM_BANKS=4）：缩短每 bank URAM 级联深度
//  2. 三级输入寄存器（写路径）：reg1/reg2/reg3（per-bank DONT_TOUCH）
//  3. 读侧单拍 mem[addra]→memreg（与 ibuf 同 URAM 模板；时序靠 chip_timing.xdc MCP）
//  4. mem_rstage + NBPIPE 输出流水（DONT_TOUCH）
//  5. 输出流水线：bank 选择 pipeline 与 chip_defines 中 BANK_MUX_PIPE 一致
//  ============================================================================
//
//  时序契约（重要）：
//  - 写延迟：从 wea/dina/addra/mem_ena 输入到末端 URAM 实际写入完成
//      = 3 拍 (IN_REG1 + IN_REG2 + IN_REG3) + URAM 内部 cascade 传播
//    写为 fire-and-forget，外部无需感知。
//  - 读延迟：DCIM_OBUF_BANK_MUX_PIPE = NBPIPE + IN_REG_STAGES + POST_URAM_PIPE
//    obuf_bank：URAM_RD_STAGES(2)=addr 预寄存 + URAM 读 + mem_rstage/NBPIPE。
//    VPU 通过 douta_valid 握手，无需硬编码等待。
//  参数统一见 rtl/chip/chip_defines.vh
//  ============================================================================

`include "chip_defines.vh"

module obuf (
    input clk,
    // Port A (External AXI interface)
    input [`DCIM_BUF_NUM_COL-1:0] wea,
    input mem_ena,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dina,
    input [`DCIM_OBUF_ADDR_WIDTH-1:0] addra,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] douta,
    output wire             douta_valid,  // 读数据有效脉冲（与 douta 同拍）
    // Port B (Internal Tile write interface)
    input [`DCIM_BUF_NUM_COL-1:0] web,
    input mem_enb,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dinb,
    input [`DCIM_OBUF_ADDR_WIDTH-1:0] addrb,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] doutb
);

// ============================================================================
// 第 1 级输入寄存器（中心，1 份）
// 作用：吸收上游 routing 与 SLR 跨越延迟
// ============================================================================
(* shreg_extract = "no", max_fanout = 2 *) reg [`DCIM_BUF_NUM_COL-1:0] wea_reg;
(* shreg_extract = "no" *) reg               mem_ena_reg;
(* shreg_extract = "no", max_fanout = 2 *) reg [`DCIM_BUF_DATA_WIDTH-1:0]  dina_reg;
(* shreg_extract = "no" *) reg [`DCIM_OBUF_ADDR_WIDTH-1:0]  addra_reg;

(* shreg_extract = "no", max_fanout = 2 *) reg [`DCIM_BUF_NUM_COL-1:0] web_reg;
(* shreg_extract = "no" *) reg               mem_enb_reg;
(* shreg_extract = "no", max_fanout = 2 *) reg [`DCIM_BUF_DATA_WIDTH-1:0]  dinb_reg;
(* shreg_extract = "no" *) reg [`DCIM_OBUF_ADDR_WIDTH-1:0]  addrb_reg;

always @(posedge clk) begin
    wea_reg     <= wea;
    mem_ena_reg <= mem_ena;
    dina_reg    <= dina;
    addra_reg   <= addra;

    web_reg     <= web;
    mem_enb_reg <= mem_enb;
    dinb_reg    <= dinb;
    addrb_reg   <= addrb;
end

// NOTE: wea_reg/web_reg must start at 0 on power-on to avoid phantom writes.
// obuf_bank's write operations are gated by mem_ena AND wea. If wea_reg is X,
// it could trigger writes. Declare initial values:
initial begin
    wea_reg     = 0;
    mem_ena_reg = 0;
    web_reg     = 0;
    mem_enb_reg = 0;
end

// 第 1 级的 bank 选择（用 reg 后的 addr 算）
wire [`DCIM_OBUF_BANK_BITS-1:0]    bank_sel_a_q1 = addra_reg[`DCIM_OBUF_ADDR_WIDTH-1 -: `DCIM_OBUF_BANK_BITS];
wire [`DCIM_OBUF_BANK_BITS-1:0]    bank_sel_b_q1 = addrb_reg[`DCIM_OBUF_ADDR_WIDTH-1 -: `DCIM_OBUF_BANK_BITS];
wire [`DCIM_OBUF_BANK_ADDR_WIDTH-1:0]  bank_addr_a_q1 = addra_reg[`DCIM_OBUF_BANK_ADDR_WIDTH-1:0];
wire [`DCIM_OBUF_BANK_ADDR_WIDTH-1:0]  bank_addr_b_q1 = addrb_reg[`DCIM_OBUF_BANK_ADDR_WIDTH-1:0];

// ============================================================================
// 多 Bank 存储阵列（每 bank 内嵌第 2 级输入寄存器）
// ============================================================================
wire [`DCIM_BUF_DATA_WIDTH-1:0] bank_douta [0:`DCIM_OBUF_NUM_BANKS-1];
wire [`DCIM_BUF_DATA_WIDTH-1:0] bank_doutb [0:`DCIM_OBUF_NUM_BANKS-1];

genvar bank;
generate
    for (bank = 0; bank < `DCIM_OBUF_NUM_BANKS; bank = bank + 1) begin : gen_banks
        // 第 1 级 bank 命中信号（参与第 2 级的 mem_ena 计算）
        wire bank_hit_a_q1 = mem_ena_reg && (bank_sel_a_q1 == bank);
        wire bank_hit_b_q1 = mem_enb_reg && (bank_sel_b_q1 == bank);

        // 第 2 级 per-bank 输入寄存器（综合后会被放在该 bank URAM cascade 附近）
        // DONT_TOUCH: 每个 bank 的 reg2 值虽然与其他 bank 相同（均来自 wea_reg），
        // 但必须保留独立的物理寄存器——Vivado 否则会把四个 bank 合并成一个物理 FF，
        // 放在 SLR0 附近，导致 bank[2]/bank[3] 的 URAM cascade 需要 2+ SLR 穿越。
        // DONT_TOUCH 确保每个 bank 的 reg2 被 placer 放在本 bank 的 URAM 旁边。
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_NUM_COL-1:0]      wea_reg2;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg                    mem_ena_reg2;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0]       dina_reg2;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_OBUF_BANK_ADDR_WIDTH-1:0]  addra_reg2;

        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_NUM_COL-1:0]      web_reg2;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg                    mem_enb_reg2;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0]       dinb_reg2;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_OBUF_BANK_ADDR_WIDTH-1:0]  addrb_reg2;

        initial begin
            wea_reg2 = 0; mem_ena_reg2 = 0;
            web_reg2 = 0; mem_enb_reg2 = 0;
        end
        always @(posedge clk) begin
            wea_reg2     <= wea_reg;
            dina_reg2    <= dina_reg;
            addra_reg2   <= bank_addr_a_q1;
            mem_ena_reg2 <= bank_hit_a_q1;

            web_reg2     <= web_reg;
            dinb_reg2    <= dinb_reg;
            addrb_reg2   <= bank_addr_b_q1;
            mem_enb_reg2 <= bank_hit_b_q1;
        end

        // 第 3 级 per-bank 输入寄存器（紧贴 URAM，DONT_TOUCH）
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_NUM_COL-1:0]      wea_reg3;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg                    mem_ena_reg3;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0]       dina_reg3;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_OBUF_BANK_ADDR_WIDTH-1:0]  addra_reg3;

        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_NUM_COL-1:0]      web_reg3;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg                    mem_enb_reg3;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0]       dinb_reg3;
        (* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_OBUF_BANK_ADDR_WIDTH-1:0]  addrb_reg3;

        initial begin
            wea_reg3 = 0; mem_ena_reg3 = 0;
            web_reg3 = 0; mem_enb_reg3 = 0;
        end
        always @(posedge clk) begin
            wea_reg3     <= wea_reg2;
            dina_reg3    <= dina_reg2;
            addra_reg3   <= addra_reg2;
            mem_ena_reg3 <= mem_ena_reg2;

            web_reg3     <= web_reg2;
            dinb_reg3    <= dinb_reg2;
            addrb_reg3   <= addrb_reg2;
            mem_enb_reg3 <= mem_enb_reg2;
        end

        obuf_bank u_bank (
            .clk(clk),
            .wea(wea_reg3),
            .mem_ena(mem_ena_reg3),
            .dina(dina_reg3),
            .addra(addra_reg3),
            .douta(bank_douta[bank]),
            .web(web_reg3),
            .mem_enb(mem_enb_reg3),
            .dinb(dinb_reg3),
            .addrb(addrb_reg3),
            .doutb(bank_doutb[bank])
        );
    end
endgenerate

// ============================================================================
// Bank 选择流水线（相比 v2 多 1 拍，匹配新增的 reg3）
// 读路径总延迟（端到端）：
(* shreg_extract = "no", max_fanout = 32 *) reg [`DCIM_OBUF_BANK_BITS-1:0] bank_sel_a_pipe [0:`DCIM_OBUF_BANK_MUX_PIPE-1];
(* shreg_extract = "no", max_fanout = 32 *) reg [`DCIM_OBUF_BANK_BITS-1:0] bank_sel_b_pipe [0:`DCIM_OBUF_BANK_MUX_PIPE-1];

// bank_sel / read_en 与 per-bank reg3 对齐（reg1 就启动会导致 CDMA 读早 1~2 拍 → concat 整体错位）
reg [`DCIM_OBUF_BANK_BITS-1:0] bank_sel_a_align [0:`DCIM_OBUF_IN_REG_STAGES-1];
reg [`DCIM_OBUF_BANK_BITS-1:0] bank_sel_b_align [0:`DCIM_OBUF_IN_REG_STAGES-1];
reg port_a_rd_align [0:`DCIM_OBUF_IN_REG_STAGES-1];
reg port_b_rd_align [0:`DCIM_OBUF_IN_REG_STAGES-1];

integer i;
always @(posedge clk) begin
    bank_sel_a_align[0] <= bank_sel_a_q1;
    bank_sel_b_align[0] <= bank_sel_b_q1;
    port_a_rd_align[0]   <= mem_ena_reg && ~|wea_reg;
    port_b_rd_align[0]   <= mem_enb_reg && ~|web_reg;
    for (i = 1; i < `DCIM_OBUF_IN_REG_STAGES; i = i + 1) begin
        bank_sel_a_align[i] <= bank_sel_a_align[i-1];
        bank_sel_b_align[i] <= bank_sel_b_align[i-1];
        port_a_rd_align[i]   <= port_a_rd_align[i-1];
        port_b_rd_align[i]   <= port_b_rd_align[i-1];
    end
end

always @(posedge clk) begin
    bank_sel_a_pipe[0] <= bank_sel_a_align[`DCIM_OBUF_IN_REG_STAGES-1];
    bank_sel_b_pipe[0] <= bank_sel_b_align[`DCIM_OBUF_IN_REG_STAGES-1];
    for (i = 1; i < `DCIM_OBUF_BANK_MUX_PIPE; i = i + 1) begin
        bank_sel_a_pipe[i] <= bank_sel_a_pipe[i-1];
        bank_sel_b_pipe[i] <= bank_sel_b_pipe[i-1];
    end
end

// ============================================================================
// 输出多路选择器
// ============================================================================
// read_en_pipe：跟踪 Port A 读使能，流水到输出，产生 douta_valid
(* shreg_extract = "no" *) reg read_en_pipe_a [0:`DCIM_OBUF_BANK_MUX_PIPE];
always @(posedge clk) begin
    read_en_pipe_a[0] <= port_a_rd_align[`DCIM_OBUF_IN_REG_STAGES-1];
    for (i = 0; i < `DCIM_OBUF_BANK_MUX_PIPE; i = i + 1)
        read_en_pipe_a[i+1] <= read_en_pipe_a[i];
end
integer read_en_init_j;
initial begin
    for (read_en_init_j = 0; read_en_init_j <= `DCIM_OBUF_BANK_MUX_PIPE; read_en_init_j = read_en_init_j + 1)
        read_en_pipe_a[read_en_init_j] = 1'b0;
    for (read_en_init_j = 0; read_en_init_j < `DCIM_OBUF_BANK_MUX_PIPE; read_en_init_j = read_en_init_j + 1) begin
        bank_sel_a_pipe[read_en_init_j] = {`DCIM_OBUF_BANK_BITS{1'b0}};
        bank_sel_b_pipe[read_en_init_j] = {`DCIM_OBUF_BANK_BITS{1'b0}};
    end
    for (read_en_init_j = 0; read_en_init_j <= `DCIM_OBUF_IN_REG_STAGES; read_en_init_j = read_en_init_j + 1) begin
        bank_sel_a_align[read_en_init_j] = {`DCIM_OBUF_BANK_BITS{1'b0}};
        bank_sel_b_align[read_en_init_j] = {`DCIM_OBUF_BANK_BITS{1'b0}};
        port_a_rd_align[read_en_init_j]   = 1'b0;
        port_b_rd_align[read_en_init_j]   = 1'b0;
    end
end
assign douta_valid = read_en_pipe_a[`DCIM_OBUF_BANK_MUX_PIPE];

initial douta = {`DCIM_BUF_DATA_WIDTH{1'b0}};
always @(posedge clk) begin
    douta <= bank_douta[bank_sel_a_pipe[`DCIM_OBUF_BANK_MUX_PIPE-1]];
    doutb <= bank_doutb[bank_sel_b_pipe[`DCIM_OBUF_BANK_MUX_PIPE-1]];
end

endmodule


// ============================================================================
// obuf_bank - 单个 Bank 的 URAM 存储模块
// ============================================================================
module obuf_bank (
    input clk,
    input [`DCIM_BUF_NUM_COL-1:0] wea,
    input mem_ena,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dina,
    input [`DCIM_OBUF_BANK_ADDR_WIDTH-1:0] addra,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] douta,
    input [`DCIM_BUF_NUM_COL-1:0] web,
    input mem_enb,
    input [`DCIM_BUF_DATA_WIDTH-1:0] dinb,
    input [`DCIM_OBUF_BANK_ADDR_WIDTH-1:0] addrb,
    output reg [`DCIM_BUF_DATA_WIDTH-1:0] doutb
);

(* ram_style = "ultra" *)
reg [`DCIM_BUF_DATA_WIDTH-1:0] mem [(1<<`DCIM_OBUF_BANK_ADDR_WIDTH)-1:0];

// Initialize mem to 0 to avoid X propagation in simulation.
// On actual FPGA, URAM is initialized to 0 by configuration bitstream.
integer mem_init_i;
initial begin
    for (mem_init_i = 0; mem_init_i < (1<<`DCIM_OBUF_BANK_ADDR_WIDTH); mem_init_i = mem_init_i + 1)
        mem[mem_init_i] = {`DCIM_BUF_DATA_WIDTH{1'b0}};
end

// Port A/B 读：与 ibuf 相同单地址模板 memrega<=mem[addra]（勿读写各用不同 addr，Synth 8-2914）
reg [`DCIM_BUF_DATA_WIDTH-1:0] memrega;
(* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] mem_rstage_rega;
(* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] mem_pipe_rega [`DCIM_OBUF_NBPIPE-1:0];
reg mem_en_pipe_rega [`DCIM_OBUF_BANK_RD_EN_DEPTH:0];

reg [`DCIM_BUF_DATA_WIDTH-1:0] memregb;
(* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] mem_rstage_regb;
(* shreg_extract = "no", DONT_TOUCH = "yes" *) reg [`DCIM_BUF_DATA_WIDTH-1:0] mem_pipe_regb [`DCIM_OBUF_NBPIPE-1:0];
reg mem_en_pipe_regb [`DCIM_OBUF_BANK_RD_EN_DEPTH:0];

integer i;

// Port A 写操作
always @(posedge clk) begin
    if (mem_ena) begin
        for (i = 0; i < `DCIM_BUF_NUM_COL; i = i + 1) begin
            if (wea[i])
                mem[addra][i*`DCIM_BUF_COL_WIDTH +: `DCIM_BUF_COL_WIDTH] <= dina[i*`DCIM_BUF_COL_WIDTH +: `DCIM_BUF_COL_WIDTH];
        end
    end
end

// Port A 读操作
always @(posedge clk) begin
    if (mem_ena && ~|wea)
        memrega <= mem[addra];
end

always @(posedge clk) begin
    mem_en_pipe_rega[0] <= mem_ena && ~|wea;
    for (i = 0; i < `DCIM_OBUF_BANK_RD_EN_DEPTH; i = i + 1)
        mem_en_pipe_rega[i+1] <= mem_en_pipe_rega[i];
end

always @(posedge clk) begin
    if (mem_en_pipe_rega[0])
        mem_rstage_rega <= memrega;
end

always @(posedge clk) begin
    if (mem_en_pipe_rega[1])
        mem_pipe_rega[0] <= mem_rstage_rega;
end

always @(posedge clk) begin
    for (i = 0; i < `DCIM_OBUF_NBPIPE-1; i = i + 1) begin
        if (mem_en_pipe_rega[i+2])
            mem_pipe_rega[i+1] <= mem_pipe_rega[i];
    end
end

    integer mem_pipe_init_i;
    initial begin
        memrega = {`DCIM_BUF_DATA_WIDTH{1'b0}};
        mem_rstage_rega = {`DCIM_BUF_DATA_WIDTH{1'b0}};
        memregb = {`DCIM_BUF_DATA_WIDTH{1'b0}};
        mem_rstage_regb = {`DCIM_BUF_DATA_WIDTH{1'b0}};
        for (mem_pipe_init_i = 0; mem_pipe_init_i < `DCIM_OBUF_NBPIPE; mem_pipe_init_i = mem_pipe_init_i + 1) begin
            mem_pipe_rega[mem_pipe_init_i] = {`DCIM_BUF_DATA_WIDTH{1'b0}};
            mem_pipe_regb[mem_pipe_init_i] = {`DCIM_BUF_DATA_WIDTH{1'b0}};
        end
        for (mem_pipe_init_i = 0; mem_pipe_init_i <= `DCIM_OBUF_BANK_RD_EN_DEPTH; mem_pipe_init_i = mem_pipe_init_i + 1) begin
            mem_en_pipe_rega[mem_pipe_init_i] = 1'b0;
            mem_en_pipe_regb[mem_pipe_init_i] = 1'b0;
        end
    end
always @(posedge clk) begin
    if (mem_en_pipe_rega[`DCIM_OBUF_BANK_RD_EN_DEPTH])
        douta <= mem_pipe_rega[`DCIM_OBUF_NBPIPE-1];
end

// Port B 写操作
always @(posedge clk) begin
    if (mem_enb) begin
        for (i = 0; i < `DCIM_BUF_NUM_COL; i = i + 1) begin
            if (web[i])
                mem[addrb][i*`DCIM_BUF_COL_WIDTH +: `DCIM_BUF_COL_WIDTH] <= dinb[i*`DCIM_BUF_COL_WIDTH +: `DCIM_BUF_COL_WIDTH];
        end
    end
end

// Port B 读操作
always @(posedge clk) begin
    if (mem_enb && ~|web)
        memregb <= mem[addrb];
end

always @(posedge clk) begin
    mem_en_pipe_regb[0] <= mem_enb && ~|web;
    for (i = 0; i < `DCIM_OBUF_BANK_RD_EN_DEPTH; i = i + 1)
        mem_en_pipe_regb[i+1] <= mem_en_pipe_regb[i];
end

always @(posedge clk) begin
    if (mem_en_pipe_regb[0])
        mem_rstage_regb <= memregb;
end

always @(posedge clk) begin
    if (mem_en_pipe_regb[1])
        mem_pipe_regb[0] <= mem_rstage_regb;
end

always @(posedge clk) begin
    for (i = 0; i < `DCIM_OBUF_NBPIPE-1; i = i + 1) begin
        if (mem_en_pipe_regb[i+2])
            mem_pipe_regb[i+1] <= mem_pipe_regb[i];
    end
end

always @(posedge clk) begin
    if (mem_en_pipe_regb[`DCIM_OBUF_BANK_RD_EN_DEPTH])
        doutb <= mem_pipe_regb[`DCIM_OBUF_NBPIPE-1];
end

endmodule
