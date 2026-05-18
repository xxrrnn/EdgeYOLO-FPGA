`timescale 1ns/1ps

module dqa_unit #(
    parameter ADDR_WIDTH = 32,
    parameter GB_BANDWIDTH = 256,
    parameter GB_ADDR_WIDTH = 16,
    parameter C_INT_WIDTH_IN = 32,
    parameter FP_CORE_NUM = 8,
    parameter FP_TRAN_NUM = 8,
    parameter FP_WIDTH    = 32,
    parameter WB_BANDWIDTH = 256,
    parameter WB_ADDR_WIDTH = 32,
    parameter MAX_CHANNEL_NUM = 64

)(
    input   wire                                clk,
    input   wire                                rst_n,
    input   wire                                dqa_unit_start,
    output  wire                                dqa_unit_ready,

    input   wire[ADDR_WIDTH - 1:0]              dqa_src_addr,
    input   wire[ADDR_WIDTH - 1:0]              dqa_src_c,
    input   wire[ADDR_WIDTH - 1:0]              dqa_src_h,
    input   wire[ADDR_WIDTH - 1:0]              dqa_src_w,
    input   wire[ADDR_WIDTH - 1:0]              dqa_scale_addr,
    input   wire[ADDR_WIDTH - 1:0]              dqa_bias_addr,
    input   wire[ADDR_WIDTH - 1:0]              dqa_dst_addr,

    input   wire                                fp_array_tready,
    output  reg                                 fp_array_tvalid,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_a_tdata, 
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_b_tdata,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_c_tdata,
    input   wire [FP_CORE_NUM*FP_WIDTH-1:0]     fp_res,
    input   wire                                fp_res_tvalid,

    output  logic [GB_ADDR_WIDTH-1:0]           gb_addrb, 
    output  logic [GB_BANDWIDTH-1:0]            gb_dinb,  
    output  logic [GB_BANDWIDTH/8-1:0]          gb_web,   
    output  logic                               gb_enb,    
    input   wire [GB_BANDWIDTH-1:0]             gb_doutb,

    output  reg [WB_ADDR_WIDTH-1:0]             wb_addrb,
    output  reg [WB_BANDWIDTH-1:0]              wb_dinb,
    output  reg [WB_BANDWIDTH/8-1:0]            wb_web,
    output  reg                                 wb_enb,
    input   wire [WB_BANDWIDTH-1:0]             wb_doutb
);
    typedef enum logic [5:0] {
        IDLE,
        DQA_UPDATE,
        DQA_LOAD_SCALE,
        DQA_WAIT_SCALE,
        DQA_LOAD_BIAS,
        DQA_WAIT_BIAS,
        DQA_LAOD_ADDR_1,
        DQA_LAOD_ADDR_2,
        DQA_LAOD_ADDR_3,
        DQA_LAOD_ADDR_4,
        DQA_LOAD_X,
        DQA_WAIT_X,
        DQA_FP,
        DQA_FP_WAIT,
        DQA_COMPUTE,
        DQA_COMPUTE_WAIT,
        DQA_SAVE_ADDR_1,
        DQA_SAVE_ADDR_2,
        DQA_SAVE
    } state_t;
    (* fsm_encoding = "auto" *) state_t c_state, n_state;
    
    assign dqa_unit_ready  = (c_state == IDLE);

    // dqa signals
    reg     [MAX_CHANNEL_NUM * FP_WIDTH - 1 : 0]            dqa_scale_reg;
    reg     [MAX_CHANNEL_NUM * FP_WIDTH - 1 : 0]            dqa_bias_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_full_scale_wire;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_full_bias_wire;
    reg     [FP_CORE_NUM * C_INT_WIDTH_IN - 1 : 0]          dqa_int_in_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_fp_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_out_reg;

    // Latched input parameters
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_src_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_dst_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_scale_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_bias_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_src_c_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_src_h_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_src_w_reg;
    // wire    [ADDR_WIDTH - 1 : 0]                            dqa_w_parallel  = FP_CORE_NUM / dqa_src_c;

    /* DQA ADDR GENERATE*/
    /*
    1. dqa_scale_load_cnt: 
        (dqa_src_c * FP_WIDTH / WB_BANDWIDTH) - 1
        而后根据w_para拼接到dqa_scale_reg长度

    2. dqa_x_load_block_cnt:  
        (FP_CORE_NUM * C_INT_WIDTH_IN / 8) >> 5 - 1
        +1
    3 dqa_x_load_c_cnt: 

    2. dqa_x_load_w_cnt:  
        dqa_src_w - 1
        + 1
    2. dqa_x_load_h_cnt: 
        dqa_src_h - 1
        + 1
    */
    localparam  MAX_CHANNEL_LENGTH = MAX_CHANNEL_NUM * FP_WIDTH;
    localparam  FP_CORE_LENGTH = FP_CORE_NUM* FP_WIDTH;
    logic [ADDR_WIDTH - 1 : 0]                      dqa_x_load_addr_add, n_dqa_x_load_addr_add;
    // wire [ADDR_WIDTH - 1 : 0]                       DQA_SINGLE_COMPUTE_BYTES,DQA_SINGLE_COMPUTE_BLOCKS ;
    // wire [ADDR_WIDTH - 1 : 0]                       DQA_SINGLE_COMPUTE_SAVE_BLOCKS ;
    // localparam DQA_SINGLE_COMPUTE_BYTES        = (FP_CORE_NUM * C_INT_WIDTH_IN >> 3);
    localparam DQA_SINGLE_COMPUTE_BLOCKS        = (FP_CORE_NUM * C_INT_WIDTH_IN >> 3) >> 5;
    localparam DQA_SINGLE_COMPUTE_SAVE_BLOCKS   = ((FP_CORE_NUM << $clog2(FP_WIDTH)) >> 3) >> 5;
    wire[ADDR_WIDTH - 1 : 0]   dqa_w_load_stride ;
    wire[ADDR_WIDTH - 1 : 0]   dqa_w_save_stride;
    logic [ADDR_WIDTH - 1 : 0]                       dqa_h_load_stride;
    logic [ADDR_WIDTH - 1 : 0]                       dqa_h_save_stride;

    // Precomputed strides (registered to break combinational multiply)
    reg [ADDR_WIDTH - 1 : 0] dqa_w_load_stride_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_w_save_stride_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_h_load_stride_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_h_save_stride_reg;

    assign dqa_w_load_stride = dqa_w_load_stride_reg;
    assign dqa_w_save_stride = dqa_w_save_stride_reg;
    assign dqa_h_load_stride = dqa_h_load_stride_reg;
    assign dqa_h_save_stride = dqa_h_save_stride_reg;


    reg [ADDR_WIDTH - 1 : 0]                       dqa_save_addr, dqa_save_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_scale_load_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_bias_load_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_load_block_cnt,  n_dqa_x_load_block_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_load_c_cnt,      n_dqa_x_load_c_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_load_w_cnt,      n_dqa_x_load_w_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_load_h_cnt,      n_dqa_x_load_h_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_tran_cnt;

    wire                                             dqa_scale_load_done;
    wire                                             dqa_bias_load_done;
    wire                                             dqa_save_done;
    wire                                             dqa_x_load_block_done;
    wire                                             dqa_x_load_c_done;
    wire                                             dqa_x_load_w_done;
    wire                                             dqa_x_load_h_done;
    wire                                             dqa_x_tran_done;
    wire                                             dqa_done;
    localparam TRAN_NUM = (FP_CORE_NUM / FP_TRAN_NUM);
    assign  dqa_scale_load_done                      = (dqa_scale_load_cnt   == ((dqa_src_c_reg << $clog2(FP_WIDTH)) >> $clog2(WB_BANDWIDTH)) - 1);
    assign  dqa_bias_load_done                       = (dqa_bias_load_cnt    == ((dqa_src_c_reg << $clog2(FP_WIDTH)) >> $clog2(WB_BANDWIDTH)) - 1);
    assign  dqa_save_done                            = (dqa_save_cnt         == (DQA_SINGLE_COMPUTE_SAVE_BLOCKS - 1));
    assign  dqa_x_load_block_done                    = (dqa_x_load_block_cnt == DQA_SINGLE_COMPUTE_BLOCKS - 1);
    assign  dqa_x_load_c_done                        = (dqa_x_load_c_cnt     == ((dqa_src_c_reg >> $clog2(FP_CORE_NUM)) - 1));
    assign  dqa_x_load_w_done                        = (dqa_x_load_w_cnt     == (dqa_src_w_reg - 1));
    assign  dqa_x_load_h_done                        = (dqa_x_load_h_cnt     == (dqa_src_h_reg - 1));
    assign  dqa_x_tran_done                          = (dqa_x_tran_cnt       == TRAN_NUM- 1);

    assign  dqa_done                                 = dqa_x_load_block_done && dqa_x_load_c_done && dqa_x_load_w_done &&dqa_x_load_h_done;

    always @* begin
        n_dqa_x_load_block_cnt           = dqa_x_load_block_cnt;
        n_dqa_x_load_c_cnt               = dqa_x_load_c_cnt;
        n_dqa_x_load_w_cnt               = dqa_x_load_w_cnt;
        n_dqa_x_load_h_cnt               = dqa_x_load_h_cnt;
        n_dqa_x_load_addr_add            = dqa_x_load_addr_add;
        if(dqa_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_w_cnt           = 0;
            n_dqa_x_load_h_cnt           = 0;
            n_dqa_x_load_addr_add            = 0;
        end else if(dqa_x_load_c_done && dqa_x_load_block_done && dqa_x_load_w_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_w_cnt           = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt + 1;
            n_dqa_x_load_addr_add           = dqa_x_load_addr_add + 1;
        end else if(dqa_x_load_c_done && dqa_x_load_block_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt + 1;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
            n_dqa_x_load_addr_add           = dqa_x_load_addr_add + 1;
        end else if(dqa_x_load_block_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = dqa_x_load_c_cnt + 1;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt ;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
            n_dqa_x_load_addr_add           = dqa_x_load_addr_add + 1;
        end else begin
            n_dqa_x_load_block_cnt       = dqa_x_load_block_cnt + 1;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
            n_dqa_x_load_c_cnt           = dqa_x_load_c_cnt ;
            n_dqa_x_load_addr_add            = dqa_x_load_addr_add + 1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dqa_x_load_block_cnt    <= '0;
            dqa_x_load_w_cnt        <= '0;
            dqa_x_load_h_cnt        <= '0;
            dqa_x_load_c_cnt        <= '0;
            dqa_x_load_addr_add     <= '0;
        end else if (c_state == DQA_UPDATE) begin
            dqa_x_load_block_cnt    <= n_dqa_x_load_block_cnt;
            dqa_x_load_c_cnt        <= n_dqa_x_load_c_cnt;
            dqa_x_load_w_cnt        <= n_dqa_x_load_w_cnt;
            dqa_x_load_h_cnt        <= n_dqa_x_load_h_cnt;
            dqa_x_load_addr_add         <= n_dqa_x_load_addr_add;
        end else if(c_state == IDLE) begin
            dqa_x_load_block_cnt    <= '0;
            dqa_x_load_w_cnt        <= '0;
            dqa_x_load_h_cnt        <= '0;
            dqa_x_load_c_cnt        <= '0;
            dqa_x_load_addr_add     <= '0;
        end
    end
    
    // assign dqa_x_load_addr    = (dqa_src_addr >> 5) + dqa_x_load_block_cnt + dqa_x_load_c_cnt * DQA_SINGLE_COMPUTE_BLOCKS + dqa_x_load_w_cnt *dqa_w_load_stride  + dqa_x_load_h_cnt * dqa_h_load_stride;
    // assign dqa_save_addr      = (dqa_dst_addr >> 5) + dqa_save_cnt + dqa_x_load_c_cnt * DQA_SINGLE_COMPUTE_SAVE_BLOCKS + dqa_x_load_w_cnt * dqa_w_save_stride + dqa_x_load_h_cnt * dqa_h_save_stride;

    // always_ff @( posedge clk or negedge rst_n ) begin
    //     if(!rst_n) begin
    //         dqa_x_load_addr <= '0;
    //     end else begin
    //         case(c_state)
    //         DQA_LAOD_ADDR_1: begin
    //             dqa_x_load_addr <= (dqa_src_addr >> 5) + dqa_x_load_block_cnt;
    //             dqa_x_load_addr_1 <= dqa_x_load_c_cnt << $clog2(DQA_SINGLE_COMPUTE_BLOCKS);
    //             dqa_x_load_addr_2 <= dqa_x_load_w_cnt * dqa_w_load_stride;
    //             dqa_x_load_addr_3 <= dqa_x_load_h_cnt * dqa_h_load_stride;
    //         end
    //         DQA_LAOD_ADDR_2:begin
    //             dqa_x_load_addr <= dqa_x_load_addr + dqa_x_load_addr_1;
    //         end
    //         DQA_LAOD_ADDR_3:begin
    //             dqa_x_load_addr <= dqa_x_load_addr + dqa_x_load_addr_2;
    //         end
    //         DQA_LAOD_ADDR_4: begin
    //             dqa_x_load_addr <= dqa_x_load_addr + dqa_x_load_addr_3;
    //         end

    //         endcase
    //     end
    // end
    


    assign wb_addrb = (c_state == DQA_LOAD_SCALE) ? (dqa_scale_addr_reg  >> 5) + dqa_scale_load_cnt :(c_state == DQA_LOAD_BIAS) ?  (dqa_bias_addr_reg  >> 5) + dqa_bias_load_cnt :'0;
    assign wb_enb   = ((c_state == DQA_LOAD_SCALE) || (c_state == DQA_LOAD_BIAS)) ? 1'b1 :1'b0;
    assign wb_web   = 1'b0;
    assign wb_dinb  = '0;

    always_ff @( posedge clk or negedge rst_n ) begin
        if(!rst_n) begin
            dqa_bias_load_cnt  <= '0;
            dqa_scale_load_cnt <= '0;
            dqa_scale_reg      <= '0;
            dqa_bias_reg      <= '0;
        end
        else begin
            if(c_state == DQA_WAIT_SCALE) begin
                dqa_scale_load_cnt <= dqa_scale_load_cnt + 1'b1;
                if (MAX_CHANNEL_LENGTH > WB_BANDWIDTH)
                    dqa_scale_reg <= {wb_doutb, dqa_scale_reg[MAX_CHANNEL_LENGTH - 1 : WB_BANDWIDTH]};
                else
                    dqa_scale_reg <= wb_doutb[MAX_CHANNEL_LENGTH - 1 : 0];
            end else if(c_state == DQA_WAIT_BIAS) begin
                dqa_bias_load_cnt  <= dqa_bias_load_cnt  + 1'b1;
                if (MAX_CHANNEL_LENGTH > WB_BANDWIDTH)
                    dqa_bias_reg  <= {wb_doutb, dqa_bias_reg[MAX_CHANNEL_LENGTH - 1 : WB_BANDWIDTH]};
                else
                    dqa_bias_reg  <= wb_doutb[MAX_CHANNEL_LENGTH - 1 : 0];
            end else if(c_state == IDLE) begin
                dqa_scale_load_cnt <= '0;
                dqa_bias_load_cnt  <= '0;
            end
        end
            
    end

    /*  X LOAD   */
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dqa_int_in_reg <= '0;
            dqa_save_cnt <= '0;
            dqa_save_addr <= '0;
        end else begin
            case (c_state)
                DQA_WAIT_X: begin
                    if (FP_CORE_NUM * C_INT_WIDTH_IN > GB_BANDWIDTH)
                        dqa_int_in_reg <= {gb_doutb, dqa_int_in_reg[FP_CORE_NUM * C_INT_WIDTH_IN - 1 : GB_BANDWIDTH]};
                    else
                        dqa_int_in_reg <= gb_doutb[FP_CORE_NUM * C_INT_WIDTH_IN - 1 : 0];
                end
                DQA_SAVE: begin
                    dqa_save_cnt <= dqa_save_cnt + 1;
                end
                DQA_SAVE_ADDR_1: begin
                    dqa_save_cnt <= dqa_save_cnt;
                    dqa_save_addr <= (dqa_dst_addr_reg >> 5) + dqa_x_load_addr_add;
                end 
                DQA_SAVE_ADDR_2: begin
                    dqa_save_cnt <= dqa_save_cnt;
                    dqa_save_addr <= dqa_save_addr - dqa_x_load_block_cnt + dqa_save_cnt;
                end
                IDLE: dqa_save_cnt <= '0;
                default: begin
                    dqa_save_cnt <= '0;
                end
            endcase
        end
    end
    always_comb begin
        gb_addrb = '0;
        gb_enb   = '0;
        gb_web   = '0;
        gb_dinb  = '0;
        if(c_state == DQA_LOAD_X ) begin
            gb_addrb = (dqa_src_addr_reg >> 5) + dqa_x_load_addr_add;
            gb_enb   = 1'b1;
            gb_web   = '0;
            gb_dinb  = '0;
        end else if(c_state == DQA_SAVE) begin
            gb_addrb = dqa_save_addr;
            gb_enb   = 1'b1;
            gb_web   = {(GB_BANDWIDTH / 8){1'b1}};
            gb_dinb  = dqa_out_reg[dqa_save_cnt*GB_BANDWIDTH +: GB_BANDWIDTH];
        end
    end

    /* FP2INT ARRAY*/
    localparam   FP_TRAN_LENGTH_IN =  FP_TRAN_NUM * C_INT_WIDTH_IN;
    localparam   FP_TRAN_LENGTH_FP = FP_TRAN_NUM*FP_WIDTH;
    logic  s_axis_tvalid, m_axis_result_tvalid;
    
    wire  [FP_TRAN_NUM*C_INT_WIDTH_IN-1:0]     s_axis_tdata;
    wire  [FP_TRAN_LENGTH_FP-1:0]         m_axis_result_tdata;
    assign s_axis_tvalid = (c_state == DQA_FP); 
    assign s_axis_tdata = dqa_int_in_reg[dqa_x_tran_cnt << $clog2(FP_TRAN_LENGTH_IN) +:FP_TRAN_LENGTH_IN];

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dqa_x_tran_cnt  <= '0;
            dqa_fp_reg <= '0;
            dqa_out_reg <= '0;
        end else begin
            if(c_state == DQA_FP_WAIT && m_axis_result_tvalid) begin
                dqa_x_tran_cnt  <= dqa_x_tran_done ? '0: dqa_x_tran_cnt + 1'b1;
                dqa_fp_reg[dqa_x_tran_cnt << $clog2(FP_TRAN_LENGTH_FP) +: FP_TRAN_LENGTH_FP] <= m_axis_result_tdata;
            end else if(fp_res_tvalid) begin
                dqa_out_reg <= fp_res;
            end else if(c_state == IDLE)begin
                dqa_x_tran_cnt  <= '0;
                dqa_fp_reg <= '0;
                dqa_out_reg <= '0;
            end
        end 
    end


    generate
        if (FP_WIDTH == 16) begin : GEN_FP16
            int32_2_fp16_array #(
                .FP_TRAN_NUM(FP_TRAN_NUM)
            ) int32_2_fp16_array_inst (
                .clk(clk),
                .s_axis_tvalid(s_axis_tvalid),
                .s_axis_tdata(s_axis_tdata),
                .m_axis_result_tvalid(m_axis_result_tvalid),
                .m_axis_result_tdata(m_axis_result_tdata)
            );
        end else begin : GEN_FP32
            int32_2_fp32_array #(
                .FP_TRAN_NUM(FP_TRAN_NUM)
            ) int32_2_fp32_array_inst (
                .clk(clk),
                .s_axis_a_tvalid(s_axis_tvalid),
                .s_axis_a_tdata(s_axis_tdata),
                .m_axis_result_tvalid(m_axis_result_tvalid),
                .m_axis_result_tdata(m_axis_result_tdata)
            );
        end
    endgenerate


    assign dqa_full_scale_wire = dqa_scale_reg[MAX_CHANNEL_LENGTH - (dqa_x_load_c_cnt << $clog2(FP_CORE_LENGTH))  - 1-: FP_CORE_LENGTH];
    assign dqa_full_bias_wire = dqa_bias_reg[MAX_CHANNEL_LENGTH - (dqa_x_load_c_cnt << $clog2(FP_CORE_LENGTH)) - 1 -: FP_CORE_LENGTH];


    assign fp_array_tvalid  = (c_state == DQA_COMPUTE)? 1'b1 : 1'b0;
    assign fp_a_tdata       = (c_state == DQA_COMPUTE)? dqa_fp_reg : '0;
    assign fp_b_tdata       = (c_state == DQA_COMPUTE)? dqa_full_scale_wire : '0;
    assign fp_c_tdata       = (c_state == DQA_COMPUTE)? dqa_full_bias_wire : '0;



    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            c_state <= IDLE;   // 复位时清零
        end else begin
            c_state <= n_state; // 正常运行时更新
        end
    end

    // Latch input parameters when start is asserted
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dqa_src_addr_reg   <= '0;
            dqa_dst_addr_reg   <= '0;
            dqa_scale_addr_reg <= '0;
            dqa_bias_addr_reg  <= '0;
            dqa_src_c_reg      <= '0;
            dqa_src_h_reg      <= '0;
            dqa_src_w_reg      <= '0;
            dqa_w_load_stride_reg <= '0;
            dqa_w_save_stride_reg <= '0;
            dqa_h_load_stride_reg <= '0;
            dqa_h_save_stride_reg <= '0;
        end else if (dqa_unit_start && dqa_unit_ready) begin
            dqa_src_addr_reg   <= dqa_src_addr;
            dqa_dst_addr_reg   <= dqa_dst_addr;
            dqa_scale_addr_reg <= dqa_scale_addr;
            dqa_bias_addr_reg  <= dqa_bias_addr;
            dqa_src_c_reg      <= dqa_src_c;
            dqa_src_h_reg      <= dqa_src_h;
            dqa_src_w_reg      <= dqa_src_w;
            // Precompute strides using shifts (C_INT_WIDTH_IN and FP_WIDTH are powers of 2)
            dqa_w_load_stride_reg <= (dqa_src_c << $clog2(C_INT_WIDTH_IN)) >> (3 + 5);
            dqa_w_save_stride_reg <= (dqa_src_c << $clog2(FP_WIDTH)) >> (3 + 5);
            dqa_h_load_stride_reg <= (dqa_src_w * dqa_src_c) << ($clog2(C_INT_WIDTH_IN) - 3 - 5);
            dqa_h_save_stride_reg <= (dqa_src_w * dqa_src_c) << ($clog2(FP_WIDTH) - 3 - 5);
        end
    end

    always@(*) begin
        n_state = c_state;
        unique case(c_state)
            IDLE: begin
                if(dqa_unit_start) begin
                    n_state = DQA_LOAD_SCALE;
                end
            end
            DQA_LOAD_SCALE: n_state = DQA_WAIT_SCALE;
            DQA_WAIT_SCALE: n_state = dqa_scale_load_done ? DQA_LOAD_BIAS: DQA_LOAD_SCALE;
            DQA_LOAD_BIAS : n_state = DQA_WAIT_BIAS;
            DQA_WAIT_BIAS : n_state = dqa_bias_load_done  ? DQA_LAOD_ADDR_1: DQA_LOAD_BIAS;
            DQA_UPDATE      : n_state = DQA_LAOD_ADDR_1;
            DQA_LAOD_ADDR_1 : n_state = DQA_LAOD_ADDR_2;
            DQA_LAOD_ADDR_2 : n_state = DQA_LAOD_ADDR_3;
            DQA_LAOD_ADDR_3 : n_state = DQA_LAOD_ADDR_4;
            DQA_LAOD_ADDR_4 : n_state = DQA_LOAD_X;
            DQA_LOAD_X      : n_state = DQA_WAIT_X;
            DQA_WAIT_X      : n_state = dqa_x_load_block_done ? DQA_FP : DQA_UPDATE;
            DQA_FP          : n_state = DQA_FP_WAIT;
            DQA_FP_WAIT     : begin
                if(m_axis_result_tvalid) begin
                    n_state = dqa_x_tran_done ?  DQA_COMPUTE : DQA_FP;
                end else begin
                    n_state = DQA_FP_WAIT;
                end
            end 
            DQA_COMPUTE     : n_state = fp_array_tready? DQA_COMPUTE_WAIT :DQA_COMPUTE;
            DQA_COMPUTE_WAIT        : n_state = fp_res_tvalid ? DQA_SAVE_ADDR_1 : DQA_COMPUTE_WAIT;
            DQA_SAVE_ADDR_1: n_state = DQA_SAVE_ADDR_2;
            DQA_SAVE_ADDR_2: n_state = DQA_SAVE;
            DQA_SAVE        : begin
                if(dqa_done && dqa_save_done) begin
                    n_state = IDLE;
                end else begin
                    n_state = dqa_save_done? DQA_UPDATE: DQA_SAVE_ADDR_1;
                end
            end
            default: n_state = IDLE;
            
        endcase

    end


endmodule
