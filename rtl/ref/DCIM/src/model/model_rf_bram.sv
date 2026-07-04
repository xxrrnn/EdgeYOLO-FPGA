// ============================================================================
// model_rf_bram - RAM 模型（DCIM sramWrap 内部权重/中间缓存）
// ============================================================================
// 使用 Block RAM (RAMB36E2)：
//   - 高密度、低 LUT 开销
//   - 同步读写，1 周期读延迟
//   - 时序路径由 memory.v 中的 pipeline 寄存器保护
// ============================================================================

module model_rf_bram #(
    parameter int WIDTH = 128,
    parameter int DEPTH = 128
)(
    input  logic                        clk,
    input  logic                        cen,    // 片选（低有效）
    input  logic                        gwen,   // 全局写使能（低有效）
    input  logic [WIDTH-1:0]            wen,    // 位掩码（低有效）- 保留接口但忽略
    input  logic [WIDTH-1:0]            d,      // 写数据
    input  logic [$clog2(DEPTH)-1:0]    a,      // 地址
    output logic [WIDTH-1:0]            q       // 读数据
);

    (* ram_style = "block" *)
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (~cen) begin
            if (~gwen) begin
                mem[a] <= d;
            end
            q <= mem[a];
        end
    end

endmodule
