`timescale 1ns/1ps
//==============================================================================
// dqa_unit：反量化（dequant）：从 WB 加载 scale/bias，从 GB 读整型输入，经
//          fp_mac_array 恢复浮点后写回 GB。
// 启动：dqa_unit_start；空闲时 dqa_unit_ready=1。
// 配置：dqa_src_*、dqa_scale_addr、dqa_bias_addr、dqa_dst_addr；C_INT_WIDTH_IN
//      为整型输入位宽；与 FP 阵列、WB 深度匹配。
//==============================================================================
module dqa_unit #(
    parameter ADDR_WIDTH = 32,
    parameter GB_BANDWIDTH = 256,
    parameter GB_ADDR_WIDTH = 16,
    parameter C_INT_WIDTH_IN = 32,
    parameter FP_CORE_NUM = 32,
    parameter FP_TRAN_NUM = 32,
    parameter FP_WIDTH    = 0,  // For example, if using FP16
    parameter WB_BANDWIDTH = 256,
    parameter WB_ADDR_WIDTH = 32,
    parameter MAX_CHANNEL_NUM = 1024

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
        DQA_LOAD_X,
        DQA_WAIT_X,
        DQA_FP,
        DQA_FP_WAIT,
        DQA_COMPUTE,
        DQA_COMPUTE_WAIT,
        DQA_SAVE
    } state_t;
    (* fsm_encoding = "one_hot" *) state_t c_state, n_state;
    
    assign dqa_unit_ready  = (c_state == IDLE);

    // dqa signals
    reg     [MAX_CHANNEL_NUM * FP_WIDTH - 1 : 0]            dqa_scale_reg;
    reg     [MAX_CHANNEL_NUM * FP_WIDTH - 1 : 0]            dqa_bias_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_full_scale_wire;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_full_bias_wire;
    reg     [FP_CORE_NUM * C_INT_WIDTH_IN - 1 : 0]          dqa_int_in_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_fp_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_out_reg;
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
    logic [ADDR_WIDTH - 1 : 0]                      dqa_x_load_addr;
    wire [ADDR_WIDTH - 1 : 0]                       dqa_single_compute_bytes,dqa_single_compute_blocks ;
    wire [ADDR_WIDTH - 1 : 0]                       dqa_single_compute_save_blocks ;
    assign dqa_single_compute_bytes        = (FP_CORE_NUM * C_INT_WIDTH_IN / 8);
    assign dqa_single_compute_blocks        = (FP_CORE_NUM * C_INT_WIDTH_IN / 8) >> 5;
    assign dqa_single_compute_save_blocks   = (FP_CORE_NUM * FP_WIDTH / 8) >> 5;
    wire[ADDR_WIDTH - 1 : 0]   dqa_w_load_stride ;
    assign dqa_w_load_stride = (dqa_src_c * C_INT_WIDTH_IN / 8) >> 5;
    wire[ADDR_WIDTH - 1 : 0]   dqa_w_save_stride;
    assign dqa_w_save_stride = (dqa_src_c * FP_WIDTH / 8) >> 5;
    logic [ADDR_WIDTH - 1 : 0]                       dqa_h_load_stride;
    logic [ADDR_WIDTH - 1 : 0]                       dqa_h_save_stride;
    assign dqa_h_load_stride = (dqa_src_w * dqa_src_c * C_INT_WIDTH_IN / 8) >> 5;
    assign dqa_h_save_stride = (dqa_src_w * dqa_src_c * FP_WIDTH / 8) >> 5;


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
    assign  dqa_scale_load_done                      = (dqa_scale_load_cnt   == (dqa_src_c * FP_WIDTH / WB_BANDWIDTH) - 1);
    assign  dqa_bias_load_done                       = (dqa_bias_load_cnt    == (dqa_src_c * FP_WIDTH / WB_BANDWIDTH) - 1);
    assign  dqa_save_done                            = (dqa_save_cnt         == (dqa_single_compute_save_blocks - 1));
    assign  dqa_x_load_block_done                    = (dqa_x_load_block_cnt == dqa_single_compute_blocks - 1);
    assign  dqa_x_load_c_done                        = (dqa_x_load_c_cnt     == ((dqa_src_c >> $clog2(FP_CORE_NUM)) - 1));
    assign  dqa_x_load_w_done                        = (dqa_x_load_w_cnt     == (dqa_src_w - 1));
    assign  dqa_x_load_h_done                        = (dqa_x_load_h_cnt     == (dqa_src_h - 1));
    assign  dqa_x_tran_done                          = (dqa_x_tran_cnt       == (FP_CORE_NUM / FP_TRAN_NUM)- 1);

    assign  dqa_done                                 = dqa_x_load_block_done && dqa_x_load_c_done && dqa_x_load_w_done &&dqa_x_load_h_done;

    always @* begin
        n_dqa_x_load_block_cnt           = dqa_x_load_block_cnt;
        n_dqa_x_load_c_cnt               = dqa_x_load_c_cnt;
        n_dqa_x_load_w_cnt               = dqa_x_load_w_cnt;
        n_dqa_x_load_h_cnt               = dqa_x_load_h_cnt;
        if(dqa_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_w_cnt           = 0;
            n_dqa_x_load_h_cnt           = 0;
        end else if(dqa_x_load_c_done && dqa_x_load_block_done && dqa_x_load_w_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_w_cnt           = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt + 1;
        end else if(dqa_x_load_c_done && dqa_x_load_block_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt + 1;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
        end else if(dqa_x_load_block_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = dqa_x_load_c_cnt + 1;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt ;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
        end else begin
            n_dqa_x_load_block_cnt       = dqa_x_load_block_cnt + 1;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
            n_dqa_x_load_c_cnt           = dqa_x_load_c_cnt ;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dqa_x_load_block_cnt    <= '0;
            dqa_x_load_w_cnt        <= '0;
            dqa_x_load_h_cnt        <= '0;
            dqa_x_load_c_cnt        <= '0;
        end else if (c_state == DQA_UPDATE) begin
            dqa_x_load_block_cnt    <= n_dqa_x_load_block_cnt;
            dqa_x_load_c_cnt        <= n_dqa_x_load_c_cnt;
            dqa_x_load_w_cnt        <= n_dqa_x_load_w_cnt;
            dqa_x_load_h_cnt        <= n_dqa_x_load_h_cnt;
        end else if(c_state == IDLE) begin
            dqa_x_load_block_cnt    <= '0;
            dqa_x_load_w_cnt        <= '0;
            dqa_x_load_h_cnt        <= '0;
            dqa_x_load_c_cnt        <= '0;
        end
    end
    
    assign dqa_x_load_addr    = (dqa_src_addr >> 5) + dqa_x_load_block_cnt + dqa_x_load_c_cnt * dqa_single_compute_blocks + dqa_x_load_w_cnt *dqa_w_load_stride  + dqa_x_load_h_cnt * dqa_h_load_stride;
    assign dqa_save_addr      = (dqa_dst_addr >> 5) + dqa_save_cnt + dqa_x_load_c_cnt * dqa_single_compute_save_blocks + dqa_x_load_w_cnt * dqa_w_save_stride + dqa_x_load_h_cnt * dqa_h_save_stride;


    assign wb_addrb = (c_state == DQA_LOAD_SCALE) ? (dqa_scale_addr  >> 5) + dqa_scale_load_cnt :(c_state == DQA_LOAD_BIAS) ?  (dqa_bias_addr  >> 5) + dqa_bias_load_cnt :'0;
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
                dqa_scale_reg <= {wb_doutb, dqa_scale_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 : WB_BANDWIDTH]};
            end else if(c_state == DQA_WAIT_BIAS) begin
                dqa_bias_load_cnt  <= dqa_bias_load_cnt  + 1'b1;
                dqa_bias_reg  <= {wb_doutb, dqa_bias_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 : WB_BANDWIDTH]};
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
        end else begin
            case (c_state)
                DQA_WAIT_X: begin
                    dqa_int_in_reg <= {gb_doutb, dqa_int_in_reg[FP_CORE_NUM * C_INT_WIDTH_IN  - 1 : GB_BANDWIDTH]};
                end
                DQA_SAVE: begin
                    dqa_save_cnt <= dqa_save_cnt + 1;
                end
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
            gb_addrb = dqa_x_load_addr;
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
    logic  s_axis_tvalid, m_axis_result_tvalid;
    
    wire  [FP_TRAN_NUM*C_INT_WIDTH_IN-1:0]     s_axis_tdata;
    wire  [FP_TRAN_NUM*FP_WIDTH-1:0]         m_axis_result_tdata;
    assign  s_axis_tvalid = (c_state == DQA_FP); 
    assign s_axis_tdata = dqa_int_in_reg[dqa_x_tran_cnt * FP_TRAN_NUM * C_INT_WIDTH_IN +: FP_TRAN_NUM * C_INT_WIDTH_IN];

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dqa_x_tran_cnt  <= '0;
            dqa_fp_reg <= '0;
            dqa_out_reg <= '0;
        end else begin
            if(c_state == DQA_FP_WAIT && m_axis_result_tvalid) begin
                dqa_x_tran_cnt  <= dqa_x_tran_done ? '0: dqa_x_tran_cnt + 1'b1;
                dqa_fp_reg[dqa_x_tran_cnt * FP_TRAN_NUM * FP_WIDTH +: FP_TRAN_NUM * FP_WIDTH] <= m_axis_result_tdata;
            end else if(fp_res_tvalid) begin
                dqa_out_reg <= fp_res;
            end else if(c_state == IDLE)begin
                dqa_x_tran_cnt  <= '0;
                dqa_fp_reg <= '0;
                dqa_out_reg <= '0;
            end
        end 
    end

    //  always_ff@(posedge clk or negedge rst_n) begin
    //     if(!rst_n) begin
    //         dqa_fp_reg <= '0;
    //         dqa_out_reg <= '0;
    //     end else if(fp_res_tvalid) begin
    //         dqa_out_reg <= fp_res;
    //     end else if(m_axis_result_tvalid) begin
    //         dqa_fp_reg <= m_axis_result_tdata;
    //     end
    // end

    // INT32 → FP32 转换（FP_WIDTH 固定为 32）
    int32_2_fp32_array #(
        .FP_TRAN_NUM(FP_TRAN_NUM)
    ) int32_2_fp32_array_inst (
        .clk(clk),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tdata(s_axis_tdata),
        .m_axis_result_tvalid(m_axis_result_tvalid),
        .m_axis_result_tdata(m_axis_result_tdata)
    );

    /* FP ARRAY */
    // always_comb begin
    //     dqa_full_scale_wire = '0;
    //     case (dqa_w_parallel)
    //         32'd16: dqa_full_scale_wire = {16{dqa_scale_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 16)  * FP_WIDTH]}};
    //         32'd8 : dqa_full_scale_wire = {8 {dqa_scale_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 8) * FP_WIDTH]}};
    //         32'd4 : dqa_full_scale_wire = {4 {dqa_scale_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 4) * FP_WIDTH]}};
    //         32'd2 : dqa_full_scale_wire = {2 {dqa_scale_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 2) * FP_WIDTH]}};
    //         32'd1 : dqa_full_scale_wire = {1 {dqa_scale_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 1) * FP_WIDTH]}};
    //         default: dqa_full_scale_wire = '0;
    //     endcase
    // end
    

    // always_comb begin
    //     dqa_full_bias_wire = '0;
    //     case (dqa_w_parallel)
    //         32'd16: dqa_full_bias_wire = {16{dqa_bias_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 16)  * FP_WIDTH]}};
    //         32'd8 : dqa_full_bias_wire = {8 {dqa_bias_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 8) * FP_WIDTH]}};
    //         32'd4 : dqa_full_bias_wire = {4 {dqa_bias_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 4) * FP_WIDTH]}};
    //         32'd2 : dqa_full_bias_wire = {2 {dqa_bias_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 2) * FP_WIDTH]}};
    //         32'd1 : dqa_full_bias_wire = {1 {dqa_bias_reg[MAX_CHANNEL_NUM * FP_WIDTH - 1 -: (FP_CORE_NUM / 1) * FP_WIDTH]}};
    //         default: dqa_full_bias_wire = '0;
    //     endcase
    // end
    assign dqa_full_scale_wire = dqa_scale_reg[MAX_CHANNEL_NUM * FP_WIDTH - dqa_x_load_c_cnt * FP_CORE_NUM* FP_WIDTH  - 1-: FP_CORE_NUM* FP_WIDTH];
    assign dqa_full_bias_wire = dqa_bias_reg[MAX_CHANNEL_NUM * FP_WIDTH - dqa_x_load_c_cnt * FP_CORE_NUM* FP_WIDTH - 1 -: FP_CORE_NUM* FP_WIDTH];


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
            DQA_WAIT_BIAS : n_state = dqa_bias_load_done  ? DQA_LOAD_X: DQA_LOAD_BIAS;
            DQA_UPDATE      : n_state = DQA_LOAD_X;
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
            DQA_COMPUTE_WAIT        : n_state = fp_res_tvalid ? DQA_SAVE : DQA_COMPUTE_WAIT;
            DQA_SAVE        : begin
                if(dqa_done && dqa_save_done) begin
                    n_state = IDLE;
                end else begin
                    n_state = dqa_save_done? DQA_UPDATE: DQA_SAVE;
                end
            end
            default: n_state = IDLE;
            
        endcase

    end


endmodule