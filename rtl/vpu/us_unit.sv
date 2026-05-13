`timescale 1ns / 1ps
//==============================================================================
// us_unit：上采样（含与 pool 窗口相关的滑动读取），按特征图尺寸从 GB 取数、
//          组装后写回目标区域；状态含 LOAD / WAIT / UPDATE / SAVE。
// 启动：us_unit_start；空闲时 us_unit_ready=1。
// 配置：us_src_*、us_dst_addr；MAX_MP_CHANNEL_NUM、FP_WIDTH、GB_BANDWIDTH
//      与布线宽度一致。地址 stride 在模块内由 h/w/c 推导。
// 依赖：仅 GB 端口（通常接 global_buffer_bram）。仿真可参考 tb_us_unit.sv。
//==============================================================================
module us_unit#(
    parameter ADDR_WIDTH = 0,
    parameter GB_BANDWIDTH = 0,
    parameter GB_ADDR_WIDTH = 0,
    parameter FP_WIDTH = 0,
    parameter MAX_MP_CHANNEL_NUM = 1024
)(

    input wire clk,
    input wire rst_n,
    input wire us_unit_start,                     
    // special unit ports
    
    output  wire                        us_unit_ready,
    input   wire[ADDR_WIDTH - 1:0]      us_src_addr,
    input   wire[ADDR_WIDTH - 1:0]      us_src_h,
    input   wire[ADDR_WIDTH - 1:0]      us_src_w,
    input   wire[ADDR_WIDTH - 1:0]      us_src_c,
    input   wire[ADDR_WIDTH - 1:0]      us_dst_addr,

    output logic [GB_ADDR_WIDTH-1:0]    gb_addrb, 
    output logic [GB_BANDWIDTH-1:0]     gb_dinb,  
    output logic [GB_BANDWIDTH/8-1:0]   gb_web,   
    output logic                        gb_enb,    
    input  wire [GB_BANDWIDTH-1:0]      gb_doutb 

    );

    typedef enum logic [5:0] {
        IDLE          ,
        US_LOAD       ,
        US_WAIT     ,
        US_UPDATE     ,
        US_SAVE     
    } state_t;
    (* fsm_encoding = "one_hot" *) state_t c_state, n_state;

    assign us_unit_ready = (c_state == IDLE);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            c_state <= IDLE;   // 复位时清零
        end else begin
            c_state <= n_state; // 正常运行时更新
        end
    end
    
    wire[ADDR_WIDTH - 1:0]                                  us_src_stride_col;
    wire[ADDR_WIDTH - 1:0]                                  us_src_stride_row;
    assign       us_src_stride_col = us_src_c * FP_WIDTH / 8;
    assign       us_src_stride_row = us_src_h * us_src_c * FP_WIDTH / 8;

    logic     [ADDR_WIDTH - 1 : 0]                            us_load_row_index, us_load_col_index;
    wire     [ADDR_WIDTH - 1 : 0]                           us_load_addr, us_save_addr;
    logic [$clog2(MAX_MP_CHANNEL_NUM * FP_WIDTH) - 1 : 0]  us_channel_cnt;
    logic [GB_BANDWIDTH - 1 : 0]                              us_act_buf;
    logic [GB_ADDR_WIDTH-1:0]                                 us_src_addr_block;
    logic [GB_ADDR_WIDTH-1:0]                                 us_src_stride_col_block;
    logic [GB_ADDR_WIDTH-1:0]                                 us_src_stride_row_block;
    logic [GB_ADDR_WIDTH-1:0]                                 us_dst_addr_block;
    logic [ADDR_WIDTH - 1 : 0]                                next_us_load_row_index, next_us_load_col_index;
    logic [$clog2(MAX_MP_CHANNEL_NUM * FP_WIDTH) - 1 : 0] next_us_channel_cnt;
    wire    [ADDR_WIDTH - 1 : 0]  us_save_index[0:3];
    logic[2:0]    us_save_block_cnt, next_us_save_block_cnt;
    
    assign us_load_addr = us_src_addr_block + us_load_col_index * us_src_stride_col_block + us_load_row_index * us_src_stride_row_block + us_channel_cnt;
    assign us_save_addr = us_dst_addr_block  + us_src_stride_col_block * us_save_index[us_save_block_cnt]  + us_channel_cnt;



    assign us_src_addr_block        = us_src_addr        >> 5;
    assign us_src_stride_col_block  = us_src_stride_col  >> 5;
    assign us_src_stride_row_block  = us_src_stride_row  >> 5;
    assign us_dst_addr_block        = us_dst_addr        >> 5;

    
    
    integer i;
    //logic for gb read/write: load_x¡¢wait_x¡¢save state
    always_comb begin
            gb_enb=1'b0;
            gb_addrb = 0;
            gb_dinb={GB_BANDWIDTH{1'b0}};
            gb_web=0;
        if(c_state == IDLE) begin
            gb_enb=1'b0;
            gb_addrb = 0;
            gb_dinb={GB_BANDWIDTH{1'b0}};
            gb_web=0;
        end else if(c_state == US_LOAD) begin
            gb_addrb = us_load_addr;
            gb_web = {(GB_BANDWIDTH / 8){1'b0}};
            gb_enb = 1'b1;
            gb_dinb = 0;
        end else if(c_state == US_SAVE) begin
            gb_enb = 1'b1;
            gb_addrb = us_save_addr;
            gb_dinb = us_act_buf;
            gb_web = {(GB_BANDWIDTH / 8){1'b1}};
        end  else begin
            gb_enb=0; 
            gb_web=0;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if(!rst_n) begin
            us_act_buf <= '0;
        end else begin
            if(c_state == US_WAIT)
                us_act_buf <= gb_doutb;
        end
    end

  // ================================= MP start =======================================


    
    // 假设这些 limit/wires 已经在别处定义/计算
    wire [$clog2(5*5)-1:0] POOL_LIMIT = 24; // or parameter
    wire [ADDR_WIDTH-1:0] ROW_LIMIT   = us_src_h + 2*2 - 5;
    wire [ADDR_WIDTH-1:0] COL_LIMIT   = us_src_w  + 2*2 - 5;




    logic [$clog2(5*5) - 1 : 0] next_pool_cnt;
    logic [$clog2(MAX_MP_CHANNEL_NUM * FP_WIDTH) - 1 : 0] next_channel_cnt;




        // compute done signals based on next-state (so they will be true in same cycle after logics update)
    wire pool_load_done_next    = (next_pool_cnt == POOL_LIMIT);
    wire channel_load_done_next = (next_channel_cnt == us_src_stride_col_block - 1);



    // ================================= US start =======================================
    
    
    /*
    1-----0
    |
    |
    2-----3
    */
    assign us_save_index[0] = us_load_row_index * us_src_w * 4 + us_load_col_index * 2;
    assign us_save_index[1] = us_save_index[0] + 1;
    assign us_save_index[2] = us_save_index[0] + 2 * us_src_w + 1;
    assign us_save_index[3] = us_save_index[0] + 2 * us_src_w;

    
    
    wire        us_block_save_done = (us_save_block_cnt == 3'd3);
    wire        us_col_load_done_cur =    (us_load_col_index == us_src_w  - 1);
    wire        us_row_load_done_cur =    (us_load_row_index == us_src_h - 1);
    wire        us_channel_load_done_cur = (us_channel_cnt == us_src_stride_col_block - 1);
    wire        us_done_comb = us_col_load_done_cur & us_row_load_done_cur & us_block_save_done & us_channel_load_done_cur;
    reg         us_done_r;



    always @* begin
        // default: hold
        next_us_load_row_index    = us_load_row_index;
        next_us_load_col_index    = us_load_col_index;
        next_us_save_block_cnt    = us_save_block_cnt;
        next_us_channel_cnt       = us_channel_cnt;
        if (us_done_r) begin
            // once done, next cycle reset all to zero
            next_us_load_row_index   = 0;
            next_us_load_col_index   = 0;
            next_us_save_block_cnt   = 0;
            next_us_channel_cnt      = 0;

        end else if (us_col_load_done_cur && us_channel_load_done_cur && us_block_save_done) begin
            next_us_load_row_index   = us_load_row_index + 1;
            next_us_load_col_index   = 0;
            next_us_save_block_cnt         = 0;
            next_us_channel_cnt      = 0;

        end else if (us_channel_load_done_cur && us_block_save_done) begin
            next_us_load_row_index   = us_load_row_index;
            next_us_load_col_index   = next_us_load_col_index + 1;
            next_us_channel_cnt      = 0;
            next_us_save_block_cnt         = 0;
        end else if (us_block_save_done) begin
            next_us_load_row_index   = us_load_row_index;
            next_us_load_col_index   = us_load_col_index;
            next_us_channel_cnt      = us_channel_cnt + 1;
            next_us_save_block_cnt         = 0;
        end else begin
            // normal: advance pool counter
            next_us_load_row_index   = us_load_row_index;
            next_us_load_col_index   = us_load_col_index;
            next_us_channel_cnt      = us_channel_cnt;
            next_us_save_block_cnt   = us_save_block_cnt + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            us_load_row_index <= 0;
            us_load_col_index <= 0;
            us_save_block_cnt       <= 0;
            us_save_block_cnt  <= 0;
            us_channel_cnt     <= 0;
            us_done_r <= '0;
        end else begin
            if(c_state == IDLE) begin
                us_load_row_index <= 0;
                us_load_col_index <= 0;
                us_save_block_cnt       <= 0;
                us_save_block_cnt  <= 0;
                us_channel_cnt     <= 0;
                us_done_r <= 0;
            end else if (c_state == US_SAVE) begin
                us_load_row_index <= next_us_load_row_index;
                us_load_col_index <= next_us_load_col_index;
                us_save_block_cnt       <= next_us_save_block_cnt;
                us_channel_cnt     <=      next_us_channel_cnt;
                us_done_r          <=      us_done_comb;
            end
        end

    end
    



    // ================================= US end =======================================


  //========================controller=========================================

    //´ÎÌ¬Âß¼­
    always @(*) begin
        n_state=IDLE;
        case(c_state)
            IDLE:   begin
                if(us_unit_start) begin
                    n_state = US_LOAD; 
                end
            end
            US_LOAD: n_state = US_WAIT;
            US_WAIT: n_state = US_SAVE;
            // US_UPDATE: n_state = US_SAVE;
            US_SAVE: begin
                if(us_done_comb) begin
                    n_state = IDLE;
                end  else begin
                    if(us_block_save_done) begin
                        n_state = US_LOAD;
                    end else begin
                        n_state = US_SAVE;
                    end
                end
            end
            default : n_state = IDLE;
                
        endcase
    end

    
endmodule

