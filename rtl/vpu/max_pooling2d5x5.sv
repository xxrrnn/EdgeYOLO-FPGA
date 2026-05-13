`timescale 1ns / 1ps
//==============================================================================
// max_pooling2d5x5：对展平的 25 组 GB 宽度输入做分层比较，输出每组（每 lane）
//                  的最大值；掩码 mp_valid_mask 指示每组是否参与比较。
// 时序：mp_act_valid 拉高后内部状态机完成 SEL/CMP 流水线，mp_res_valid 指示
//       输出有效。rst_n 异步复位。
// 参数：FP_WIDTH 须整除 GB_BANDWIDTH（通道并行数 = GB_BANDWIDTH/FP_WIDTH）。
// 用法：由 mp_unit 例化；不复位时需保证输入与掩码与数据源一致。
//==============================================================================
module max_pooling2d5x5 #(
    parameter int FP_WIDTH     = 32,    // bits per channel (must divide GB_BANDWIDTH)
    parameter int GB_BANDWIDTH = 256
) (
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic                           mp_act_valid,
    input  logic [GB_BANDWIDTH*25 - 1 : 0] mp_act_buf,     // 展平的 25 组输入
    input  logic [25 - 1 : 0]              mp_valid_mask,  // 每组一个有效位
    output logic                           mp_res_valid,
    output logic [GB_BANDWIDTH - 1 : 0]    mp_res          // 输出一组（GB_BANDWIDTH-bit）
);

    // -----------------------------
    // 参数检查
    // -----------------------------
    initial begin
        if (FP_WIDTH <= 0) begin
            $fatal("FP_WIDTH must be > 0");
        end
        if (GB_BANDWIDTH <= 0) begin
            $fatal("GB_BANDWIDTH must be > 0");
        end
        if ((GB_BANDWIDTH % FP_WIDTH) != 0) begin
            $fatal("FP_WIDTH (%0d) must divide GB_BANDWIDTH (%0d) exactly", FP_WIDTH, GB_BANDWIDTH);
        end
    end

    localparam int NUM_LANES   = GB_BANDWIDTH / FP_WIDTH; // 每组的通道数
    localparam int NUM_GROUPS  = 5;                       // 25 = 5×5（分层）
    localparam int GROUP_SIZE  = 5;

    // 最小值（若为 IEEE754 浮点请替换为 -inf）
    localparam signed [FP_WIDTH-1:0] MINV = {1'b1, {FP_WIDTH-1{1'b0}}};

    // -----------------------------
    // 状态机：三拍一组（SEL1 → SEL2 → CMP）
    // -----------------------------
    typedef enum logic [2:0] { S_IDLE, S_SEL1, S_SEL2, S_CMP, S_DONE } state_t;
    state_t c_state, n_state;

    // snapshot：整帧开始时一次性采样
    logic [GB_BANDWIDTH*25 - 1 : 0] mp_act_buf_reg;
    logic [25 - 1 : 0]              valid_mask_reg;

    // 组计数 k ∈ [0..24]
    logic [$clog2(25)-1:0]          act_cnt;

    // 一热选择（减少 act_cnt 扇出/复杂选择）
    logic [24:0]                    act_1hot_d, act_1hot_q1; // q1 为对齐用

    // 当前组的 mask 流水
    logic                           mask_bit_q1; // 与 SEL1 同拍
    logic                           mask_bit_q2; // 与 v 对齐给 CMP 使用

    // 分层与或中间寄存（二维：lane × group）
    logic signed [FP_WIDTH-1:0]     sel_lvl0_q [0:NUM_LANES-1][0:NUM_GROUPS-1];

    // 每 lane 当前值寄存器（由分层与或选择后写入）
    logic signed [FP_WIDTH-1:0]     v     [0:NUM_LANES-1];

    // 每 lane 最大值寄存器
    logic signed [FP_WIDTH-1:0]     maxv  [0:NUM_LANES-1];

    // 输出有效
    logic                           mp_res_valid_reg;
    assign mp_res_valid = mp_res_valid_reg;

    // -----------------------------
    // 状态寄存
    // -----------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) c_state <= S_IDLE;
        else        c_state <= n_state;
    end

    // 下一状态
    always_comb begin
        n_state = c_state;
        unique case (c_state)
            S_IDLE : n_state = mp_act_valid ? S_SEL1 : S_IDLE;
            S_SEL1 : n_state = S_SEL2;                        // 层1 与或并寄存
            S_SEL2 : n_state = S_CMP;                         // 层2 与或，写 v
            S_CMP  : n_state = (act_cnt == 25-1) ? S_DONE : S_SEL1; // 比较后换下一组
            S_DONE : n_state = S_IDLE;
            default: n_state = S_IDLE;
        endcase
    end

    // -----------------------------
    // 帧开始时的 snapshot
    // -----------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mp_act_buf_reg <= '0;
            valid_mask_reg <= '0;
        end else if (c_state==S_IDLE && mp_act_valid) begin
            mp_act_buf_reg <= mp_act_buf;
            valid_mask_reg <= mp_valid_mask;
        end
    end

    // -----------------------------
    // 一热解码（组合：当拍的选择）
    // -----------------------------
    always_comb begin
        act_1hot_d = '0;
        act_1hot_d[act_cnt] = 1'b1;
    end

    // -----------------------------
    // 主时序与数据通路
    // -----------------------------
    integer i, g;

    // 初始化与公共寄存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_cnt          <= '0;
            mp_res_valid_reg <= 1'b0;
            mp_res           <= '0;
            act_1hot_q1      <= '0;
            mask_bit_q1      <= 1'b0;
            mask_bit_q2      <= 1'b0;
            for (i=0; i<NUM_LANES; i++) begin
                maxv[i] <= MINV;
                v[i]    <= '0;
                for (g=0; g<NUM_GROUPS; g++) begin
                    sel_lvl0_q[i][g] <= '0;
                end
            end
        end else begin
            mp_res_valid_reg <= 1'b0; // 默认拉低

            unique case (c_state)
                S_IDLE: begin
                    act_cnt     <= '0;
                    act_1hot_q1 <= '0;
                    mask_bit_q1 <= 1'b0;
                    mask_bit_q2 <= 1'b0;
                    for (i=0; i<NUM_LANES; i++) begin
                        maxv[i] <= MINV;
                        v[i]    <= '0;
                        for (g=0; g<NUM_GROUPS; g++) begin
                            sel_lvl0_q[i][g] <= '0;
                        end
                    end
                end

                // ---- SEL1：用“当拍”的 act_1hot_d 计算层1与或，并寄存到 sel_lvl0_q ----
                S_SEL1: begin
                    // 对齐保存（后续拍参考，不参与本拍组合）
                    act_1hot_q1 <= act_1hot_d;
                    mask_bit_q1 <= valid_mask_reg[act_cnt];

                    for (int lane=0; lane<NUM_LANES; ++lane) begin
                        for (int grp=0; grp<NUM_GROUPS; ++grp) begin
                            logic signed [FP_WIDTH-1:0] d0, d1, d2, d3, d4;
                            d0 = $signed(mp_act_buf_reg[(5*grp+0)*GB_BANDWIDTH + lane*FP_WIDTH +: FP_WIDTH]);
                            d1 = $signed(mp_act_buf_reg[(5*grp+1)*GB_BANDWIDTH + lane*FP_WIDTH +: FP_WIDTH]);
                            d2 = $signed(mp_act_buf_reg[(5*grp+2)*GB_BANDWIDTH + lane*FP_WIDTH +: FP_WIDTH]);
                            d3 = $signed(mp_act_buf_reg[(5*grp+3)*GB_BANDWIDTH + lane*FP_WIDTH +: FP_WIDTH]);
                            d4 = $signed(mp_act_buf_reg[(5*grp+4)*GB_BANDWIDTH + lane*FP_WIDTH +: FP_WIDTH]);

                            // 注意：这里使用 act_1hot_d（当拍 one-hot），避免相位错
                            sel_lvl0_q[lane][grp] <=
                                  ({FP_WIDTH{act_1hot_d[5*grp+0]}} & d0)
                                | ({FP_WIDTH{act_1hot_d[5*grp+1]}} & d1)
                                | ({FP_WIDTH{act_1hot_d[5*grp+2]}} & d2)
                                | ({FP_WIDTH{act_1hot_d[5*grp+3]}} & d3)
                                | ({FP_WIDTH{act_1hot_d[5*grp+4]}} & d4);
                        end
                    end
                end

                // ---- SEL2：层2与或得到 sel_sum（按 lane 汇总 5 组）→ 写 v；mask 同步到 q2 ----
                S_SEL2: begin
                    for (int lane=0; lane<NUM_LANES; ++lane) begin
                        logic signed [FP_WIDTH-1:0] sel_sum;
                        sel_sum = sel_lvl0_q[lane][0] | sel_lvl0_q[lane][1] | sel_lvl0_q[lane][2]
                                | sel_lvl0_q[lane][3] | sel_lvl0_q[lane][4];
                        v[lane] <= mask_bit_q1 ? sel_sum : MINV;
                    end
                    mask_bit_q2 <= mask_bit_q1; // 与 v 对齐到 CMP
                end

                // ---- CMP：用 v 与 maxv 比较；未到末组则 act_cnt++ ----
                S_CMP: begin
                    if (mask_bit_q2) begin
                        for (int lane=0; lane<NUM_LANES; ++lane) begin
                            if (v[lane] > maxv[lane]) maxv[lane] <= v[lane];
                            else                      maxv[lane] <= maxv[lane];
                        end
                    end
                    // 递增组计数（最后一组比较完将转 S_DONE）
                    if (act_cnt != 25-1) act_cnt <= act_cnt + 1'b1;
                end

                // ---- DONE：输出结果一拍 ----
                S_DONE: begin
                    for (int lane=0; lane<NUM_LANES; ++lane) begin
                        mp_res[lane*FP_WIDTH +: FP_WIDTH] <= maxv[lane];
                    end
                    mp_res_valid_reg <= 1'b1;
                end

                default: ;
            endcase
        end
    end

    // -----------------------------
    // 输出已在 S_DONE 中寄存
    // -----------------------------

endmodule
