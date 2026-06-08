// ============================================================================
// model_rf_bram - RAM 模型（DCIM sramWrap 内部权重/中间缓存）
// ============================================================================
// 使用分布式 RAM (LUTRAM)：
//   - 与 ppCache FDRE 同属 SLICE 资源，Placer 可紧邻放置
//   - 消除 BRAM 列与 SLICE 区域之间的时钟 skew 和长走线
//   - 同步读写，1 周期读延迟（与 BRAM 模式行为完全一致）
//   - 资源代价：~256 LUT/Tile（4 Tile 共 1024 LUT，总 LUT 增加 0.12%）
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

    // ========================================================================
    // RAM 声明 - 分布式 RAM (LUTRAM)，与 ppCache 同属 SLICE 资源
    // ========================================================================
    (* ram_style = "distributed" *)
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    // ========================================================================
    // 同步读写逻辑 - 与原 BRAM 模式行为完全一致（1 周期读延迟）
    // ========================================================================
    always @(posedge clk) begin
        if (~cen) begin  // 片选有效
            if (~gwen) begin
                mem[a] <= d;
            end
            q <= mem[a];
        end
    end

endmodule
