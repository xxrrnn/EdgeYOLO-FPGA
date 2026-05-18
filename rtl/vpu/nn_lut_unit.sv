`timescale 1ns / 1ps
module nn_lut_unit#(
    parameter ADDR_WIDTH = 32,
    parameter INTERVAL_NUM = 16,
    parameter BREAK_WIDTH = 32,
    parameter WEIGHT_WIDTH = 32,
    parameter BIAS_WIDTH = 32,
    parameter FP_WIDTH = 32,
    parameter FP_CORE_NUM = 32,
    parameter WB_BANDWIDTH = 256,
    parameter RAM_DEPTH_WB = 1024,
    parameter GB_BANDWIDTH = 256,
    parameter GB_ADDR_WIDTH = 256

)(
    input wire clk,
    input wire rst_n,
    input wire nn_unit_start,

    output wire nn_unit_ready,

    /* config part*/
    input wire [ADDR_WIDTH-1:0]         nn_addr_break, 
	input wire [ADDR_WIDTH-1:0]         nn_addr_s,
	input wire [ADDR_WIDTH-1:0]         nn_addr_t,  
    input   wire[ADDR_WIDTH - 1:0]      nn_src_addr,
    input   wire[ADDR_WIDTH - 1:0]      nn_src_h,
    input   wire[ADDR_WIDTH - 1:0]      nn_src_w,
    input   wire[ADDR_WIDTH - 1:0]      nn_src_c,
    input   wire[ADDR_WIDTH - 1:0]      nn_dst_addr,

    /* fp array part*/
    input   wire                              fp_array_tready,
    output  reg                               fp_array_tvalid,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]    fp_a_tdata, 
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]    fp_b_tdata,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]    fp_c_tdata,
    input   wire [FP_CORE_NUM*FP_WIDTH-1:0]   fp_res,
    input   wire                              fp_res_tvalid,

    /* mem part*/
    //  gb
    output reg [GB_ADDR_WIDTH-1:0]      gb_addrb,
    output reg [GB_BANDWIDTH-1:0]       gb_dinb, 
    output reg [GB_BANDWIDTH/8-1:0]     gb_web,  
    output reg                          gb_enb,    
    input wire [GB_BANDWIDTH-1:0]       gb_doutb,

    output reg [$clog2(RAM_DEPTH_WB)-1:0]   wb_addrb,
    output reg [WB_BANDWIDTH-1:0]       wb_dinb,
    output reg [WB_BANDWIDTH/8-1:0]     wb_web,
    output reg                          wb_enb,
    input wire [WB_BANDWIDTH-1:0]       wb_doutb
);
    
    
    integer i;
    localparam NEURON_NUM=INTERVAL_NUM-1;  
    localparam B_DATALENGTH = NEURON_NUM * BREAK_WIDTH;  
    localparam S_DATALENGTH = INTERVAL_NUM * WEIGHT_WIDTH;
    localparam T_DATALENGTH = INTERVAL_NUM * BIAS_WIDTH;  
    localparam B_BEATS = (B_DATALENGTH + WB_BANDWIDTH - 1) / WB_BANDWIDTH; 
    localparam S_BEATS = (S_DATALENGTH + WB_BANDWIDTH - 1) / WB_BANDWIDTH;
    localparam T_BEATS = (T_DATALENGTH + WB_BANDWIDTH - 1) / WB_BANDWIDTH; 

    localparam GB_DATALENGTH_R = FP_CORE_NUM*FP_WIDTH;                                //R->read  W;write
    localparam GB_DATALENGTH_W = FP_CORE_NUM*FP_WIDTH;                               //total bit length write back to globalbuffer
//counters for read/write globalbuffer
    localparam integer R_BEATS=(GB_DATALENGTH_R+GB_BANDWIDTH-1)/GB_BANDWIDTH;
    localparam integer W_BEATS=(GB_DATALENGTH_W+GB_BANDWIDTH-1)/GB_BANDWIDTH;

    localparam WB_ADDR_WIDTH = $clog2(RAM_DEPTH_WB);
    localparam FP_WIDTH_SHIFT = $clog2(FP_WIDTH);
    localparam GB_BW_SHIFT = $clog2(GB_BANDWIDTH);

    // Precomputed: total X beats (registered, not combinational)
    reg [ADDR_WIDTH - 1 : 0] x_beats_reg;
    reg [2*ADDR_WIDTH - 1 : 0] precompute_ch_nn;

    // 当前状态与下一状态寄存器
    typedef enum logic [5:0] {
        IDLE,          
        NN_UPDATE,
        NN_LOAD_B,     
        NN_WAIT_B,   
        NN_LOAD_S,     
        NN_WAIT_S,    
        NN_LOAD_T,     
        NN_WAIT_T,    
        NN_LOAD_X,     
        NN_WAIT_X,   
        NN_CMP_START,  
        NN_CMP_WAIT,   
        NN_MAC_START,  
        NN_MAC_WAIT,   
        NN_SAVE        
    } state_t;

    // 声明状态寄存器
    (* fsm_encoding = "auto" *)state_t c_state, n_state;

    assign nn_unit_ready = c_state == IDLE;
    // addr generate part
    wire [GB_ADDR_WIDTH-1:0]                 nn_src_addr_block;
    wire [GB_ADDR_WIDTH-1:0]                 nn_src_save_addr_block;
    assign nn_src_addr_block = nn_src_addr >> 5;   
    assign nn_src_save_addr_block = nn_dst_addr >> 5;   

    wire [WB_ADDR_WIDTH-1:0]               nn_addr_break_block;
    wire [WB_ADDR_WIDTH-1:0]               nn_addr_s_block;
    wire [WB_ADDR_WIDTH-1:0]               nn_addr_t_block; 

    assign     nn_addr_break_block  = nn_addr_break >> 5;
    assign     nn_addr_s_block      = nn_addr_s >> 5;
    assign     nn_addr_t_block      = nn_addr_t >> 5;


    reg [W_BEATS-1:0]       nn_w_cnt;   //write counter
    reg [R_BEATS-1:0]       nn_r_cnt;   //read counter
    reg [B_BEATS-1:0]       nn_b_cnt;  // b read counter
    reg [S_BEATS-1:0]       nn_s_cnt;  // s read counter
    reg [T_BEATS-1:0]       nn_t_cnt;  // t read counter

    wire b_load_done = (nn_b_cnt == B_BEATS - 1);
    wire s_load_done = (nn_s_cnt == S_BEATS - 1); 
    wire t_load_done = (nn_t_cnt == T_BEATS - 1); 
    wire x_load_done=(nn_r_cnt==R_BEATS-1); 
    wire save_done=(nn_w_cnt==W_BEATS); 


    reg [FP_CORE_NUM*FP_WIDTH-1:0]          x_regs;               //x loaded
    reg [NEURON_NUM*BREAK_WIDTH-1:0]        breakpoint_regs;  //breakpoint loaded
    reg [INTERVAL_NUM*WEIGHT_WIDTH-1:0]     s_regs;       //weigth s loaded 
    reg [INTERVAL_NUM*WEIGHT_WIDTH-1:0]     t_regs;       //bias t loaded
    // FP ARRAY PART
    reg [FP_WIDTH*FP_CORE_NUM-1:0]  silu_out_total;


    // COMP SIGNAL
    wire cmp_in_valid = (c_state == NN_CMP_START);
    wire [FP_CORE_NUM-1:0][NEURON_NUM-1:0]      cmp_res_valid;
    wire [FP_CORE_NUM-1:0][NEURON_NUM-1:0][7:0] cmp_res;
    wire [FP_CORE_NUM-1:0][NEURON_NUM-1:0]      leq_res;
    reg   [FP_CORE_NUM-1:0][ADDR_WIDTH-1:0]     index;
    wire  [FP_CORE_NUM-1:0]                     core_valid;
    wire                                        cmp_all_valid; 
    assign cmp_all_valid = &core_valid;

    reg [FP_CORE_NUM-1:0][FP_WIDTH-1:0] s_true_reg;
    reg [FP_CORE_NUM-1:0][FP_WIDTH-1:0] t_true_reg;



    reg [ADDR_WIDTH - 1 : 0]  x_loads, next_x_loads;
    assign next_x_loads = x_loads + 1;
    wire all_done = (x_loads == x_beats_reg);

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x_loads <= '0;
            precompute_ch_nn <= '0;
            x_beats_reg <= '0;
        end else begin
            if(c_state == IDLE && nn_unit_start) begin
                x_loads <= '0;
                precompute_ch_nn <= nn_src_c * nn_src_h;
            end else if (c_state == NN_LOAD_B && x_beats_reg == '0) begin
                // Stage 2: compute x_beats from ch * w
                automatic logic [2*ADDR_WIDTH-1:0] total_bits;
                total_bits = (precompute_ch_nn * nn_src_w) << FP_WIDTH_SHIFT;
                x_beats_reg <= (total_bits[ADDR_WIDTH-1:0] >> $clog2(GB_DATALENGTH_R * 8)) - 1;
            end else if(c_state == NN_UPDATE) begin
                x_loads <= next_x_loads;
            end
        end
    end



    // ================== COMPARATOR START =======================//
//    genvar core_i, cmp_i;
//    generate
//        for (core_i = 0; core_i < FP_CORE_NUM; core_i = core_i + 1) begin: CORE_ARRAY
//            for (cmp_i = 0; cmp_i < NEURON_NUM; cmp_i = cmp_i + 1) begin: CMP_LEQ_ARRAY

//                fp32_compare_leq fp_leq_inst (
//                    .aclk(clk), 
//                    .s_axis_a_tvalid(cmp_in_valid), 
//                    .s_axis_a_tdata(x_regs[core_i*FP_WIDTH +:FP_WIDTH]), 
//                    .s_axis_b_tvalid(cmp_in_valid), 
//                    .s_axis_b_tdata(breakpoint_regs[cmp_i*FP_WIDTH +: FP_WIDTH]), 
//                    .m_axis_result_tvalid(cmp_res_valid[core_i][cmp_i]),  // output wire
//                    .m_axis_result_tdata(cmp_res[core_i][cmp_i])          // output wire [7 : 0]
//                );

//                assign leq_res[core_i][cmp_i] = cmp_res[core_i][cmp_i][0] | cmp_res[core_i][cmp_i][1];
//                assign core_valid[core_i] = &cmp_res_valid[core_i];
//                integer i;
//                reg first;
//                always @(*) begin
//                    index[core_i] = NEURON_NUM;  // 默认值
//                    first = 0;
//                    for (i = 0; i < NEURON_NUM; i = i + 1) begin
//                        if (leq_res[core_i][i] & (~first)) begin
//                            index[core_i] = i[ADDR_WIDTH-1:0];
//                            first = 1'b1;
//                        end
//                    end
//                end
//            end
//        end
//    endgenerate

genvar core_i, cmp_i;
generate
    for (core_i = 0; core_i < FP_CORE_NUM; core_i = core_i + 1) begin: CORE_ARRAY
        for (cmp_i = 0; cmp_i < NEURON_NUM; cmp_i = cmp_i + 1) begin: CMP_LEQ_ARRAY

            // ¸ù¾Ý FP_WIDTH Ñ¡Ôñ±È½Ïµ¥Ôª
            if (FP_WIDTH == 32) begin: FP32_LEQ
                fp32_compare_leq fp_leq_inst (
                    .aclk(clk), 
                    .s_axis_a_tvalid(cmp_in_valid), 
                    .s_axis_a_tdata(x_regs[core_i*FP_WIDTH +:FP_WIDTH]), 
                    .s_axis_b_tvalid(cmp_in_valid), 
                    .s_axis_b_tdata(breakpoint_regs[cmp_i*FP_WIDTH +: FP_WIDTH]), 
                    .m_axis_result_tvalid(cmp_res_valid[core_i][cmp_i]),  // output wire
                    .m_axis_result_tdata(cmp_res[core_i][cmp_i])          // output wire [7 : 0]
                );
            end else if (FP_WIDTH == 16) begin: FP16_LEQ
                fp16_compare_leq fp_leq_inst (
                    .aclk(clk), 
                    .s_axis_a_tvalid(cmp_in_valid), 
                    .s_axis_a_tdata(x_regs[core_i*FP_WIDTH +:FP_WIDTH]), 
                    .s_axis_b_tvalid(cmp_in_valid), 
                    .s_axis_b_tdata(breakpoint_regs[cmp_i*FP_WIDTH +: FP_WIDTH]), 
                    .m_axis_result_tvalid(cmp_res_valid[core_i][cmp_i]),  // output wire
                    .m_axis_result_tdata(cmp_res[core_i][cmp_i])          // output wire [7 : 0]
                );
            end

            // ¼ÆËã±È½Ï½á¹û
            assign leq_res[core_i][cmp_i] = cmp_res[core_i][cmp_i][0] | cmp_res[core_i][cmp_i][1];
            assign core_valid[core_i] = &cmp_res_valid[core_i];

            integer i;
            reg first;
            always @(*) begin
                index[core_i] = NEURON_NUM;  // ³õÊ¼»¯
                first = 0;
                for (i = 0; i < NEURON_NUM; i = i + 1) begin
                    if (leq_res[core_i][i] & (~first)) begin
                        index[core_i] = i[ADDR_WIDTH-1:0];
                        first = 1'b1;
                    end
                end
            end
        end
    end
endgenerate




    generate
        for (core_i = 0; core_i < FP_CORE_NUM; core_i = core_i + 1) begin: TRUE_REG_ARRAY
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    s_true_reg[core_i] <= 16'd0;
                    t_true_reg[core_i] <= 16'd0;
                end 
                else if (cmp_all_valid) begin
                    s_true_reg[core_i] <= s_regs[core_i*NEURON_NUM*FP_WIDTH + index[core_i]*FP_WIDTH +: FP_WIDTH];
                    t_true_reg[core_i] <= t_regs[core_i*NEURON_NUM*FP_WIDTH + index[core_i]*FP_WIDTH +: FP_WIDTH];
                end
            end
        end
    endgenerate





    // ================== COMPARATOR END =======================//

    always_comb begin
        gb_enb = 1'b0;
        gb_dinb = {GB_BANDWIDTH{1'b0}};
        gb_web = 0;
        case (c_state)
            //---------------------------------
            IDLE: begin
                gb_enb = 1'b0;
                gb_addrb = 0;
                gb_dinb = {GB_BANDWIDTH{1'b0}};
                gb_web = 0;
            end

            //---------------------------------
            NN_LOAD_X: begin
                gb_addrb = nn_src_addr_block + nn_r_cnt + (x_loads << $clog2(R_BEATS));
                gb_enb = 1'b1;
            end
            NN_WAIT_X: begin
                gb_addrb = 0;
                gb_enb = 0;
            end

            //---------------------------------
            NN_SAVE: begin
                if (!save_done) begin
                    gb_web = {(GB_BANDWIDTH / 8){1'b1}};
                    gb_enb = 1'b1;
                    gb_dinb = silu_out_total[nn_w_cnt*GB_BANDWIDTH +: GB_BANDWIDTH];          
                    gb_addrb = nn_src_save_addr_block + nn_w_cnt + (x_loads << $clog2(W_BEATS));
                end else begin
                    gb_web = 1'b0;
                    gb_enb = 1'b0;
                    gb_dinb = {GB_BANDWIDTH{1'b0}};
                    gb_addrb = {GB_ADDR_WIDTH{1'b0}};
                end
            end

            //---------------------------------
            default: begin
                gb_enb = 0;
                gb_web = 0;
                gb_dinb = {GB_BANDWIDTH{1'b0}};
                gb_addrb = {GB_ADDR_WIDTH{1'b0}};
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nn_w_cnt <= 0;  
            nn_r_cnt <= 0;
            x_regs <= '0;
        end else begin
            case(c_state)
            NN_WAIT_X: begin
                    if (GB_DATALENGTH_R > GB_BANDWIDTH) begin
                        if ((nn_r_cnt + 1) * GB_BANDWIDTH <= GB_DATALENGTH_R) begin
                            x_regs <= {gb_doutb, x_regs[GB_DATALENGTH_R-1:GB_BANDWIDTH]};
                        end else begin
                            x_regs <= {gb_doutb, x_regs[GB_DATALENGTH_R-1:GB_DATALENGTH_R-(R_BEATS-1)*GB_BANDWIDTH]};
                        end
                    end else begin
                        x_regs <= gb_doutb;
                    end
                    nn_r_cnt <= nn_r_cnt + 1;
                end

            NN_SAVE: begin
                nn_w_cnt <= save_done?0 :  nn_w_cnt + 1;
            end
            endcase
        end
    end

    //logic for nnlut param load
        always_comb begin
            wb_enb = 0;
            wb_addrb = 0; 
            wb_dinb = {WB_BANDWIDTH{1'b0}};
            case (c_state)
                // -------------------------- read breakpoint--------------------------
                NN_LOAD_B: begin
                    wb_addrb = nn_addr_break_block + nn_b_cnt;
                    wb_enb = 1'b1;
                end
                NN_WAIT_B: begin
                    wb_enb = 0;
                    wb_addrb = 0; 
                end
                // -------------------------- read s£¨weight£© --------------------------
                NN_LOAD_S: begin
                    wb_addrb = nn_addr_s_block + nn_s_cnt;
                    wb_enb = 1'b1;
                end
                NN_WAIT_S: begin
                    wb_enb = 1'b0;
                end

                // -------------------------- read t£¨bias£© --------------------------
                NN_LOAD_T: begin
                    wb_addrb = nn_addr_t_block + nn_t_cnt;
                    wb_enb = 1'b1;
                end
                NN_WAIT_T:begin
                    wb_enb = 1'b0;
                end
                default: begin
                    wb_enb = 1'b0;
                end
            endcase
        end
        assign  wb_web = '0;


        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                nn_b_cnt <= 0;
                nn_s_cnt <= 0;
                nn_t_cnt <= 0;
            end else begin
                case (c_state)
                    // -------------------------- read breakpoint--------------------------
                    NN_LOAD_B: begin
                        nn_s_cnt <= 0;
                        nn_t_cnt <= 0;
                    end
                    NN_WAIT_B: begin
                        if (B_DATALENGTH > WB_BANDWIDTH) begin
                            if((nn_b_cnt+1)*WB_BANDWIDTH<=B_DATALENGTH)begin
                                breakpoint_regs<={wb_doutb,breakpoint_regs[B_DATALENGTH-1:WB_BANDWIDTH]};
                            end else begin
                                breakpoint_regs<={wb_doutb,breakpoint_regs[B_DATALENGTH-1:B_DATALENGTH-(B_BEATS-1)*WB_BANDWIDTH]};
                            end
                        end else begin
                            breakpoint_regs <= wb_doutb;
                        end
                        nn_b_cnt <= nn_b_cnt + 1;
                    end

                    // -------------------------- read s£¨weight£© --------------------------
                    NN_LOAD_S: begin
                        nn_b_cnt <= 0;
                        nn_t_cnt <= 0;
                    end
                    NN_WAIT_S: begin
                        if (S_DATALENGTH > WB_BANDWIDTH) begin
                            if((nn_s_cnt+1)*WB_BANDWIDTH<=B_DATALENGTH)begin
                                s_regs<={wb_doutb,s_regs[S_DATALENGTH-1:WB_BANDWIDTH]};
                            end else begin
                                s_regs<={wb_doutb,s_regs[S_DATALENGTH-1:S_DATALENGTH-(S_BEATS-1)*WB_BANDWIDTH]};
                            end
                        end else begin
                            s_regs <= wb_doutb;
                        end
                        nn_s_cnt <= nn_s_cnt + 1;
                    end

                    // -------------------------- read t£¨bias£© --------------------------
                    NN_LOAD_T: begin
                        nn_b_cnt <= 0;
                        nn_s_cnt <= 0;
                    end
                    NN_WAIT_T: begin
                        // if (wb_validb && wb_readyb) begin
                        if (T_DATALENGTH > WB_BANDWIDTH) begin
                            t_regs <= {wb_doutb, t_regs[T_DATALENGTH - 1 : WB_BANDWIDTH]};
                        end else begin
                            t_regs <= wb_doutb;
                        end
                        nn_t_cnt <= nn_t_cnt + 1;
                    end
                    default: begin
                        nn_b_cnt <= 0;
                        nn_s_cnt <= 0;
                        nn_t_cnt <= 0;
                    end
                endcase
            end
        end

        always_comb begin
            fp_array_tvalid = '0;
            fp_a_tdata = '0;
            fp_b_tdata = '0;
            fp_c_tdata = '0;
            if(c_state == NN_MAC_START) begin
                fp_array_tvalid = 1'b1;
                fp_a_tdata = x_regs;
                for(int i = 0; i < FP_CORE_NUM; i = i + 1) begin
                    fp_b_tdata[i * FP_WIDTH + FP_WIDTH] = s_true_reg[i];
                    fp_c_tdata[i * FP_WIDTH + FP_WIDTH] = t_true_reg[i];
                end
            end else begin
                fp_array_tvalid = '0;
                fp_a_tdata = '0;
                fp_b_tdata = '0;
                fp_c_tdata = '0;
            end
        end

        always_ff @(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                silu_out_total <= '0;
            end else begin
                 if(fp_res_tvalid) begin
                    silu_out_total <= fp_res;
                end
            end
        end

    // ======================= STATE MACHINE =======================

    // 同步状态寄存器更新
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            c_state <= IDLE;
        else
            c_state <= n_state;
    end


    // 组合逻辑：下一状态控制
    always_comb begin
        n_state = c_state;
        unique case (c_state)
            IDLE: n_state = nn_unit_start? NN_LOAD_B : IDLE;
            NN_LOAD_B:  n_state=NN_WAIT_B;
            NN_WAIT_B:begin
                if(b_load_done)n_state=NN_LOAD_S;
                else n_state=NN_LOAD_B;
            end
            NN_LOAD_S:n_state=NN_WAIT_S; 
            NN_WAIT_S:begin
                if(s_load_done)n_state=NN_LOAD_T;
                else n_state=NN_LOAD_S;
            end
            NN_LOAD_T:begin
                n_state=NN_WAIT_T;
            end
            NN_WAIT_T:begin
                if(t_load_done)n_state=NN_LOAD_X;
                else n_state=NN_LOAD_T;
            end
            NN_LOAD_X:begin
                n_state=NN_WAIT_X;
            end
            NN_WAIT_X:begin
                if(x_load_done)
                    n_state=NN_CMP_START;  
                else
                    n_state=NN_LOAD_X; 
            end
            NN_CMP_START: n_state    = NN_CMP_WAIT;
            NN_CMP_WAIT:  n_state    = cmp_all_valid ? NN_MAC_START : NN_CMP_WAIT;
            NN_MAC_START:    n_state = fp_array_tready ? NN_MAC_WAIT : NN_MAC_START;
            NN_MAC_WAIT:    n_state = fp_res_tvalid ? NN_SAVE : NN_MAC_WAIT;
            NN_SAVE:begin
                if(all_done) begin
                    n_state = IDLE;
                end else begin
                    n_state = save_done? NN_UPDATE:NN_SAVE;
                end
            end 
            NN_UPDATE: n_state = NN_LOAD_X;
            default:      n_state = IDLE;
        endcase
    end


endmodule
