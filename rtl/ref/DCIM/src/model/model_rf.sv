module model_rf #(
    parameter int WIDTH = 128,
    parameter int DEPTH = 128
)(
    input  logic                        clk,
    input  logic                        cen,
    input  logic                        gwen,  // 全局写使能
    input  logic [WIDTH-1: 0]           wen,   // 位掩码
    input  logic [WIDTH-1: 0]           d,     // 输入数据
    input  logic [$clog2(DEPTH)-1: 0]   a,     // 地址
    output logic [WIDTH-1: 0]           q      // 输出数据
);

    logic [WIDTH-1: 0] r_mem [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            r_mem[i] = '0;
        end
    end

    always_ff @(posedge clk) begin
        if (~cen) begin
            if (~gwen) begin
               	r_mem[a] <= (~wen & d) | (wen & r_mem[a]);
            end else begin
                q <= r_mem[a];
            end
        end
    end

endmodule
