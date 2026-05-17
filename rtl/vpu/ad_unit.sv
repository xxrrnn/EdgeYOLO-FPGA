`timescale 1ns/1ps

module ad_unit #(
    parameter ADDR_WIDTH =      32,
    parameter GB_BANDWIDTH =    256,
    parameter GB_ADDR_WIDTH =   16,
    parameter FP_CORE_NUM =     256,
    parameter FP_WIDTH    =     32

)(
    input   wire                     clk,
    input   wire                     rst_n,
    input   wire                     ad_unit_start,
    output  wire                     ad_unit_ready,
                
    input   wire[ADDR_WIDTH - 1:0]   ad_src_addr,
    input   wire[ADDR_WIDTH - 1:0]   ad_src2_addr,
    input   wire[ADDR_WIDTH - 1:0]   ad_src_c,
    input   wire[ADDR_WIDTH - 1:0]   ad_src_h,
    input   wire[ADDR_WIDTH - 1:0]   ad_src_w,
    input   wire[ADDR_WIDTH - 1:0]   ad_dst_addr,

    output logic [GB_ADDR_WIDTH-1:0]    gb_addrb, 
    output logic [GB_BANDWIDTH-1:0]     gb_dinb,  
    output logic [GB_BANDWIDTH/8-1:0]   gb_web,   
    output logic                        gb_enb,    
    input  wire [GB_BANDWIDTH-1:0]      gb_doutb
);

    localparam  ad_single_compute_blocks      = (FP_CORE_NUM * FP_WIDTH / GB_BANDWIDTH) ;
    localparam  ad_single_compute_save_blocks = (FP_CORE_NUM * FP_WIDTH / GB_BANDWIDTH);


    typedef enum logic [5:0] {
        IDLE,
        AD_UPDATE,
        AD_LOAD_X,
        AD_WAIT_X,
        AD_LOAD_X_2,
        AD_WAIT_X_2,
        AD_COMPUTE,
        AD_COMPUTE_WAIT,
        AD_SAVE
    } state_t;
    (* fsm_encoding = "auto" *) state_t c_state, n_state;
    
    assign ad_unit_ready  = (c_state == IDLE);

    // ad signals
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              ad_fp_in_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              ad_fp_in2_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              ad_out_reg;
    wire     [FP_CORE_NUM * FP_WIDTH - 1 : 0]             fp_a_tdata;
    wire     [FP_CORE_NUM * FP_WIDTH - 1 : 0]             fp_b_tdata;
    wire     [FP_CORE_NUM * FP_WIDTH - 1 : 0]             res;
    
    // Latched input parameters
    reg     [ADDR_WIDTH - 1 : 0]                          ad_src_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          ad_src2_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          ad_dst_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          ad_src_c_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          ad_src_h_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          ad_src_w_reg;

    /* QA ADDR GENERATE*/
    /*

    1. ad_x_load_block_cnt:  
        ad_single_compute_blocks
        +1

        
    2. ad_x_load_cnt:
        (ad_src_w * ad_src_h * ad_src_c * FP_WIDTH / GB_BANDWIDTH ) - ad_single_compute_blocks
        + ad_single_compute_blocks

    */
    wire [ADDR_WIDTH - 1 : 0]                       ad_x_load_addr;
    wire [ADDR_WIDTH - 1 : 0]                       ad_x2_load_addr;
    wire [ADDR_WIDTH - 1 : 0]                       ad_x_total_blocks;
    assign      ad_x_total_blocks               = (ad_src_c_reg * ad_src_h_reg * ad_src_w_reg * FP_WIDTH + GB_BANDWIDTH - 1) / GB_BANDWIDTH;

    

    logic [ADDR_WIDTH - 1 : 0]                       ad_save_addr, ad_save_cnt, n_ad_save_cnt;
    logic [ADDR_WIDTH - 1 : 0]                       ad_x_load_block_cnt,  n_ad_x_load_block_cnt;
    logic [ADDR_WIDTH - 1 : 0]                       ad_x_load_cnt,  n_ad_x_load_cnt;

    
    assign  ad_x_load_block_done                    = (ad_x_load_block_cnt == ad_single_compute_blocks - 1);
    assign  ad_x_load_done                          = (ad_x_load_cnt == (ad_x_total_blocks - ad_single_compute_blocks));
    assign  ad_save_done                            = (ad_save_cnt       == (ad_single_compute_save_blocks - 1));

    assign  ad_done                                 =  ad_x_load_done & ad_x_load_block_done & ad_save_done;

    always @* begin
        n_ad_x_load_block_cnt       =     ad_x_load_block_cnt;
        n_ad_x_load_cnt             =     ad_x_load_cnt;
        if(ad_done) begin
            n_ad_x_load_block_cnt       = 0;
            n_ad_x_load_cnt             = 0;
        end else if(ad_x_load_done) begin
            n_ad_x_load_cnt             =     0;
            n_ad_x_load_block_cnt       =     0;
        end else if(ad_x_load_block_done) begin
            n_ad_x_load_cnt             =     ad_x_load_cnt + ad_single_compute_blocks;
            n_ad_x_load_block_cnt       =     0;
        end else begin
            n_ad_x_load_block_cnt       =     ad_x_load_block_cnt;
            n_ad_x_load_cnt             =     ad_x_load_cnt;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ad_x_load_block_cnt    <= '0;
            ad_x_load_cnt        <= '0;
        end else if (c_state == IDLE && ad_unit_start) begin
            // Reset counters when starting a new operation
            ad_x_load_block_cnt    <= '0;
            ad_x_load_cnt         <= '0;
        end else if (c_state == AD_UPDATE) begin
            ad_x_load_block_cnt    <= n_ad_x_load_block_cnt;
            ad_x_load_cnt         <= n_ad_x_load_cnt;
        end
    end


    assign ad_x_load_addr    = (ad_src_addr_reg >> 5)   + ad_x_load_block_cnt + ad_x_load_cnt;
    assign ad_x2_load_addr   = (ad_src2_addr_reg >> 5)  + ad_x_load_block_cnt + ad_x_load_cnt;
    assign ad_save_addr      = (ad_dst_addr_reg >> 5)   + ad_save_cnt + ad_x_load_cnt / ad_single_compute_blocks * ad_single_compute_save_blocks;


    /*  X LOAD   */
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ad_fp_in_reg <= '0;
            ad_fp_in2_reg <= '0;
            ad_save_cnt <= '0;
        end else begin
            case (c_state)
                IDLE: begin
                    // 重置 ad_save_cnt，为下一次运算准备
                    ad_save_cnt <= '0;
                end
                AD_WAIT_X: begin
                    // 修复：当 FP_CORE_NUM*FP_WIDTH <= GB_BANDWIDTH 时，直接赋值
                    if (FP_CORE_NUM * FP_WIDTH > GB_BANDWIDTH)
                        ad_fp_in_reg <= {gb_doutb, ad_fp_in_reg[FP_CORE_NUM * FP_WIDTH - 1 : GB_BANDWIDTH]};
                    else
                        ad_fp_in_reg <= gb_doutb[FP_CORE_NUM * FP_WIDTH - 1 : 0];
                end
                AD_WAIT_X_2: begin
                    // 修复：当 FP_CORE_NUM*FP_WIDTH <= GB_BANDWIDTH 时，直接赋值
                    if (FP_CORE_NUM * FP_WIDTH > GB_BANDWIDTH)
                        ad_fp_in2_reg <= {gb_doutb, ad_fp_in2_reg[FP_CORE_NUM * FP_WIDTH - 1 : GB_BANDWIDTH]};
                    else
                        ad_fp_in2_reg <= gb_doutb[FP_CORE_NUM * FP_WIDTH - 1 : 0];
                end
                AD_UPDATE: begin
                    // 在 AD_UPDATE 状态重置 ad_save_cnt，为本次迭代准备
                    ad_save_cnt <= '0;
                end
                AD_SAVE: begin
                    ad_save_cnt <= ad_save_cnt + 1;
                end
            endcase
        end
    end
    wire fp_res_tvalid;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ad_out_reg <= '0;
        end else begin
            ad_out_reg <= fp_res_tvalid ? res : ad_out_reg;
        end
    end

    always_comb begin
        gb_addrb = '0;
        gb_enb   = '0;
        gb_web   = '0;
        gb_dinb  = '0;
        if(c_state == AD_LOAD_X ) begin
            gb_addrb = ad_x_load_addr;
            gb_enb   = 1'b1;
            gb_web   = '0;
            gb_dinb  = '0;
        end else if(c_state == AD_LOAD_X_2 ) begin
            gb_addrb = ad_x2_load_addr;
            gb_enb   = 1'b1;
            gb_web   = '0;
            gb_dinb  = '0;
        end else if(c_state == AD_SAVE) begin
            gb_addrb = ad_save_addr;
            gb_enb   = 1'b1;
            gb_web   = {(GB_BANDWIDTH / 8){1'b1}};
            gb_dinb  = ad_out_reg[ad_save_cnt*GB_BANDWIDTH +: GB_BANDWIDTH];
        end
    end

    assign fp_array_tvalid  = (c_state == AD_COMPUTE)? 1'b1 : 1'b0;
    assign fp_a_tdata       = (c_state == AD_COMPUTE)? ad_fp_in_reg: '0;
    assign fp_b_tdata       = (c_state == AD_COMPUTE)? ad_fp_in2_reg : '0;


    
    // 实例化 fp16_add_array
    fp_add_array #(
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_WIDTH(FP_WIDTH)
    ) fp_add_array_inst (
        .clk(clk),
        .fp_array_tvalid(fp_array_tvalid),
        .a_tdata(fp_a_tdata),
        .b_tdata(fp_b_tdata),
        .res(res),
        .res_tvalid(fp_res_tvalid)
    );




    // Latch input parameters when transitioning out of IDLE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ad_src_addr_reg  <= '0;
            ad_src2_addr_reg <= '0;
            ad_dst_addr_reg  <= '0;
            ad_src_c_reg     <= '0;
            ad_src_h_reg     <= '0;
            ad_src_w_reg     <= '0;
        end else if (ad_unit_start && ad_unit_ready) begin
            // Latch all input parameters when start is asserted and module is ready
            ad_src_addr_reg  <= ad_src_addr;
            ad_src2_addr_reg <= ad_src2_addr;
            ad_dst_addr_reg  <= ad_dst_addr;
            ad_src_c_reg     <= ad_src_c;
            ad_src_h_reg     <= ad_src_h;
            ad_src_w_reg     <= ad_src_w;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            c_state <= IDLE;   // 复位时清零
        end else begin
            c_state <= n_state; // 正常运行时更新
        end
    end

    always@(*) begin
        n_state = c_state;
        unique case(c_state)
            IDLE: begin
                if(ad_unit_start) begin
                    n_state = AD_LOAD_X;
                end
            end
            AD_UPDATE       : n_state  = AD_LOAD_X;
            AD_LOAD_X       : n_state  = AD_WAIT_X;
            AD_WAIT_X       : n_state  = AD_LOAD_X_2;
            AD_LOAD_X_2     : n_state  = AD_WAIT_X_2;
            AD_WAIT_X_2     : n_state  = ad_x_load_block_done ? AD_COMPUTE : AD_UPDATE;
            AD_COMPUTE      : n_state  = AD_COMPUTE_WAIT;
            AD_COMPUTE_WAIT : n_state  = fp_res_tvalid ? AD_SAVE : AD_COMPUTE_WAIT;
            AD_SAVE        : begin
                if(ad_done) begin
                    n_state = IDLE;
                end else begin
                    n_state = ad_save_done? AD_UPDATE: AD_SAVE;
                end
            end
            default: n_state = IDLE;
            
        endcase

    end


endmodule
