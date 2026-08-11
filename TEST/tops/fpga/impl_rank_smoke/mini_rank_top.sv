module mini_rank_top (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         valid_i,
    input  logic [63:0]  a_i,
    input  logic [63:0]  b_i,
    output logic         valid_o,
    output logic [33:0]  sum_o
);
    logic [31:0] product_q [0:3];
    logic [32:0] pair_q [0:1];
    logic [2:0]  valid_q;
    integer lane;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            valid_q <= '0;
            valid_o <= 1'b0;
            sum_o <= '0;
            for (lane = 0; lane < 4; lane = lane + 1)
                product_q[lane] <= '0;
            pair_q[0] <= '0;
            pair_q[1] <= '0;
        end else begin
            valid_q <= {valid_q[1:0], valid_i};
            for (lane = 0; lane < 4; lane = lane + 1)
                product_q[lane] <= a_i[lane*16 +: 16] * b_i[lane*16 +: 16];
            pair_q[0] <= {1'b0, product_q[0]} + {1'b0, product_q[1]};
            pair_q[1] <= {1'b0, product_q[2]} + {1'b0, product_q[3]};
            sum_o <= {1'b0, pair_q[0]} + {1'b0, pair_q[1]};
            valid_o <= valid_q[2];
        end
    end
endmodule
