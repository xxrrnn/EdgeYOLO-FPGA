`timescale 1ns/1ps

module qa_unit #(
    parameter ADDR_WIDTH =      32,
    parameter GB_BANDWIDTH =    256,
    parameter GB_ADDR_WIDTH =   16,
    parameter WB_BANDWIDTH =    256,
    parameter WB_ADDR_WIDTH =   512,

    parameter FP_CORE_NUM =     32,
    parameter FP_TRAN_NUM =     8,
    parameter FP_WIDTH    =     0,  // For example, if using FP16
    parameter Q_INT_WIDTH_OUT =   8,

    parameter MAX_CHANNEL_NUM = 1024

)(
    input   wire                     clk,
    input   wire                     rst_n,
    input   wire                     qa_unit_start,
    output  wire                     qa_unit_ready,
                
    input   wire[ADDR_WIDTH - 1:0]   qa_src_addr,
    input   wire[ADDR_WIDTH - 1:0]   qa_src_c,
    input   wire[ADDR_WIDTH - 1:0]   qa_src_h,
    input   wire[ADDR_WIDTH - 1:0]   qa_src_w,
    input   wire[ADDR_WIDTH - 1:0]   qa_scale_addr,
    input   wire[ADDR_WIDTH - 1:0]   qa_dst_addr,

    output  reg                                 fp_array_tvalid,
    input   wire                                 fp_array_tready,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_a_tdata, 
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_b_tdata,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_c_tdata,
    input   wire [FP_CORE_NUM*FP_WIDTH-1:0]     fp_res,
    input   wire                                fp_res_tvalid,

    output logic [GB_ADDR_WIDTH-1:0]    gb_addrb, 
    output logic [GB_BANDWIDTH-1:0]     gb_dinb,  
    output logic [GB_BANDWIDTH/8-1:0]   gb_web,   
    output logic                        gb_enb,    
    input  wire [GB_BANDWIDTH-1:0]      gb_doutb,

    output reg [WB_ADDR_WIDTH-1:0]      wb_addrb,
    output reg [WB_BANDWIDTH-1:0]       wb_dinb,
    output reg [WB_BANDWIDTH/8-1:0]     wb_web,
    output reg                          wb_enb,
    input wire [WB_BANDWIDTH-1:0]       wb_doutb
);

    localparam  qa_single_compute_blocks      = (FP_CORE_NUM * FP_WIDTH / GB_BANDWIDTH) ;
    localparam  qa_single_compute_save_blocks = (FP_CORE_NUM * Q_INT_WIDTH_OUT / GB_BANDWIDTH);


    typedef enum logic [5:0] {
        IDLE,
        QA_LOAD_SCALE,
        QA_WAIT_SCALE,
        QA_UPDATE,
        QA_LOAD_X,
        QA_WAIT_X,
        QA_COMPUTE,
        QA_COMPUTE_WAIT,
        QA_INT,
        QA_INT_WAIT,
        QA_SAVE
    } state_t;
    state_t c_state, n_state;
    
    assign qa_unit_ready  = (c_state == IDLE);

    // dqa signals
    reg     [FP_WIDTH - 1 : 0]                            qa_scale_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              qa_fp_in_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              qa_out_q_reg;
    reg     [FP_CORE_NUM * Q_INT_WIDTH_OUT - 1 : 0]       qa_out_int_reg;
    /* QA ADDR GENERATE*/
    /*

    1. qa_x_load_block_cnt:  
        qa_single_compute_blocks
        +1

        
    2. qa_x_load_cnt:
        (qa_src_w * qa_src_h * qa_src_c * FP_WIDTH / GB_BANDWIDTH ) - qa_single_compute_blocks
        + qa_single_compute_blocks

    */
    wire [ADDR_WIDTH - 1 : 0]                       qa_x_load_addr;
    reg  [ADDR_WIDTH - 1 : 0]                       qa_x_total_blocks_reg;
    wire [ADDR_WIDTH - 1 : 0]                       qa_x_total_blocks;
    assign      qa_x_total_blocks             = qa_x_total_blocks_reg;

    

    logic [ADDR_WIDTH - 1 : 0]                       qa_save_addr, qa_save_cnt, n_qa_save_cnt;
    logic [ADDR_WIDTH - 1 : 0]                       qa_x_load_block_cnt,  n_qa_x_load_block_cnt;
    logic [ADDR_WIDTH - 1 : 0]                       qa_x_load_cnt,  n_qa_x_load_cnt;
    reg   [ADDR_WIDTH - 1 : 0]                       qa_x_tran_cnt,  n_x_tran_cnt;
    wire  qa_x_load_block_done, qa_save_done, qa_x_load_done, qa_done, qa_x_tran_done;
    
    assign  qa_x_load_block_done                    = (qa_x_load_block_cnt == qa_single_compute_blocks - 1);
    assign  qa_save_done                            = (qa_save_cnt       == (qa_single_compute_save_blocks - 1));
    assign  qa_x_load_done                          = (qa_x_load_cnt == (qa_x_total_blocks - qa_single_compute_blocks));
    assign  qa_x_tran_done                          = (qa_x_tran_cnt == (FP_CORE_NUM / FP_TRAN_NUM)- 1);
    assign  qa_done                                 =  qa_x_load_done & qa_x_load_block_done & qa_save_done;

    always @* begin
        n_qa_x_load_block_cnt       =     qa_x_load_block_cnt;
        n_qa_x_load_cnt             =     qa_x_load_cnt;
        if(qa_done) begin
            n_qa_x_load_block_cnt       = 0;
            n_qa_x_load_cnt             = 0;
        end else if(qa_x_load_done) begin
            n_qa_x_load_cnt             =     0;
            n_qa_x_load_block_cnt       =     0;
        end else if(qa_x_load_block_done) begin
            n_qa_x_load_cnt             =     qa_x_load_cnt + qa_single_compute_blocks;
            n_qa_x_load_block_cnt       =     0;
        end else begin
            n_qa_x_load_block_cnt       =     qa_x_load_block_cnt;
            n_qa_x_load_cnt             =     qa_x_load_cnt;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            qa_x_load_block_cnt    <= '0;
            qa_x_load_cnt        <= '0;
            qa_x_total_blocks_reg  <= '0;
        end else if (c_state == QA_LOAD_SCALE) begin
            // 在开始计算时计算总块数
            qa_x_total_blocks_reg  <= (qa_src_w * qa_src_h * qa_src_c * FP_WIDTH) / GB_BANDWIDTH;
        end else if (c_state == QA_UPDATE) begin
            qa_x_load_block_cnt    <= n_qa_x_load_block_cnt;
            qa_x_load_cnt         <= n_qa_x_load_cnt;
        end
    end


    assign qa_x_load_addr    = (qa_src_addr >> 5) + qa_x_load_block_cnt + qa_x_load_cnt;
    assign qa_save_addr      = (qa_dst_addr >> 5) + qa_save_cnt + qa_x_load_cnt / qa_single_compute_blocks * qa_single_compute_save_blocks;

    wire [ADDR_WIDTH - 1 : 0]            qa_scale_block_addr, qa_scale_block_index;
    assign qa_scale_block_addr           = (qa_scale_addr >> 5);
    assign qa_scale_block_index          = qa_scale_addr[4:0];
    assign wb_addrb = (c_state == QA_LOAD_SCALE) ? (qa_scale_addr >> 5) :'0;
    assign wb_enb   = (c_state == QA_LOAD_SCALE) ? 1'b1 :1'b0;
    assign wb_web   = 1'b0;
    assign wb_dinb  = '0;

    always_ff @( posedge clk or negedge rst_n ) begin
        if(!rst_n) begin
            qa_scale_reg      <= '0;
        end
        else begin
            if(c_state == QA_WAIT_SCALE) begin
                qa_scale_reg <= wb_doutb[(qa_scale_block_index + 1) * FP_WIDTH -: FP_WIDTH];
            end
        end
    end

    /*  X LOAD   */
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            qa_fp_in_reg <= '0;
            qa_save_cnt <= '0;
        end else begin
            case (c_state)
                QA_WAIT_X: begin
                    // 修复：当 FP_CORE_NUM*FP_WIDTH <= GB_BANDWIDTH 时，直接赋值
                    // 当 FP_CORE_NUM*FP_WIDTH > GB_BANDWIDTH 时，拼接并右移
                    if (FP_CORE_NUM * FP_WIDTH > GB_BANDWIDTH)
                        qa_fp_in_reg <= {gb_doutb, qa_fp_in_reg[FP_CORE_NUM * FP_WIDTH - 1 : GB_BANDWIDTH]};
                    else
                        qa_fp_in_reg <= gb_doutb[FP_CORE_NUM * FP_WIDTH - 1 : 0];
                end
                QA_SAVE: begin
                    qa_save_cnt <= qa_save_cnt + 1;
                end
                default: begin
                    qa_save_cnt <= '0;
                end
            endcase
        end
    end

    always_comb begin
        gb_addrb = '0;
        gb_enb   = '0;
        gb_web   = '0;
        gb_dinb  = '0;
        if(c_state == QA_LOAD_X ) begin
            gb_addrb = qa_x_load_addr;
            gb_enb   = 1'b1;
            gb_web   = '0;
            gb_dinb  = '0;
        end else if(c_state == QA_SAVE) begin
            gb_addrb = qa_save_addr;
            gb_enb   = 1'b1;
            gb_web   = {(GB_BANDWIDTH / 8){1'b1}};
            gb_dinb  = qa_out_int_reg[qa_save_cnt*GB_BANDWIDTH +: GB_BANDWIDTH];
        end
    end

    assign fp_array_tvalid  = (c_state == QA_COMPUTE)? 1'b1 : 1'b0;
    assign fp_a_tdata       = (c_state == QA_COMPUTE)? qa_fp_in_reg: '0;
    assign fp_b_tdata       = (c_state == QA_COMPUTE)? {FP_CORE_NUM{qa_scale_reg}} : '0;
    assign fp_c_tdata       =  '0;


    /* FP2INT ARRAY*/
    logic  s_axis_tvalid, m_axis_int_tvalid;
    
    wire [FP_TRAN_NUM*FP_WIDTH-1:0]     s_axis_tdata;
    wire [FP_TRAN_NUM*Q_INT_WIDTH_OUT-1:0]         m_axis_int_tdata;
    assign  s_axis_tvalid = (c_state == QA_INT); 
    assign  s_axis_tdata  = qa_fp_in_reg[qa_x_tran_cnt * FP_TRAN_NUM * FP_WIDTH +: FP_TRAN_NUM * FP_WIDTH];

    fp16_2_int8_array # (
    .FP_TRAN_NUM(FP_TRAN_NUM)
    )fp16_2_int8_array_inst(
        .clk(clk),
        .s_axis_a_tvalid(s_axis_tvalid),
        .s_axis_a_tdata(s_axis_tdata),
        .m_axis_result_tdata(m_axis_int_tdata),
        .m_axis_result_tvalid(m_axis_int_tvalid)
    );

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            qa_x_tran_cnt<= '0;
            qa_out_q_reg <= '0;
            qa_out_int_reg <= '0;
        end else if(fp_res_tvalid) begin
            qa_out_q_reg <= fp_res;
        end else if(c_state == QA_COMPUTE_WAIT && m_axis_int_tvalid) begin
            qa_x_tran_cnt  <= qa_x_tran_done ? '0 : qa_x_tran_cnt + 1'b1;
            qa_out_int_reg[qa_x_tran_cnt * FP_TRAN_NUM * Q_INT_WIDTH_OUT +: FP_TRAN_NUM * Q_INT_WIDTH_OUT] <= m_axis_int_tdata;
        end else if(c_state == IDLE) begin
            qa_x_tran_cnt<= '0;
            qa_out_q_reg <= '0;
            qa_out_int_reg <= '0;
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
                if(qa_unit_start) begin
                    n_state = QA_LOAD_SCALE;
                end
            end
            QA_LOAD_SCALE   : n_state  = QA_WAIT_SCALE;
            QA_WAIT_SCALE   : n_state  = QA_LOAD_X;
            QA_UPDATE       : n_state  = QA_LOAD_X;
            QA_LOAD_X       : n_state  = QA_WAIT_X;
            QA_WAIT_X       : n_state  = qa_x_load_block_done ? QA_COMPUTE : QA_UPDATE;
            QA_COMPUTE      : n_state  = fp_array_tready? QA_COMPUTE:QA_COMPUTE_WAIT;
            QA_COMPUTE_WAIT : n_state  = fp_res_tvalid ? QA_INT : QA_COMPUTE_WAIT;
            QA_INT          : n_state = QA_INT_WAIT;
            QA_INT_WAIT     : begin
                if(m_axis_int_tvalid)
                    n_state = qa_x_tran_done ?  QA_SAVE : QA_INT;
                else
                    n_state = QA_INT_WAIT;
            end 
            QA_SAVE        : begin
                if(qa_done) begin
                    n_state = IDLE;
                end else begin
                    n_state = qa_save_done? QA_UPDATE: QA_SAVE;
                end
            end
            default: n_state = IDLE;
            
        endcase

    end


endmodule
