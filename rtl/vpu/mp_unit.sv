`timescale 1ns / 1ps
//==============================================================================
// mp_unit：5×5 最大池化任务调度，经 Global Buffer 读入 25 路块数据，委托
//          max_pooling2d5x5 做逐通道比较，结果写回 GB。
// 启动：mp_unit_start 脉冲；空闲时 mp_unit_ready=1 可接新任务。
// 配置：mp_src_addr / h / w / c、mp_dst_addr 为逻辑地址；与 GB 块寻址
//      （>>5）在内部完成。MAX_CHANNEL_NUM、FP_WIDTH、GB_BANDWIDTH 须与系统一致。
// 依赖：max_pooling2d5x5；下层连接 global_buffer_bram（端口 gb_*）。
// 仿真：仓库根执行 vivado -mode batch -source rtl/vpu/sim/run_tb_mp_xsim.tcl
//==============================================================================
// 由于路径太长，setup violation，因此加入reg来截断路径
module mp_unit#(
    parameter ADDR_WIDTH = 32,
    parameter GB_BANDWIDTH = 256,
    parameter GB_ADDR_WIDTH = 32,
    parameter FP_WIDTH=32,
    parameter MAX_CHANNEL_NUM = 1024
)(

    input wire clk,
    input wire rst_n,
    input wire mp_unit_start,
    output  wire                     mp_unit_ready,                     
    // special unit ports
    
    input   wire[ADDR_WIDTH - 1:0]      mp_src_addr,
    input   wire[ADDR_WIDTH - 1:0]      mp_src_h,
    input   wire[ADDR_WIDTH - 1:0]      mp_src_w,
    input   wire[ADDR_WIDTH - 1:0]      mp_src_c,
    input   wire[ADDR_WIDTH - 1:0]      mp_dst_addr,

    output logic [GB_ADDR_WIDTH-1:0]    gb_addrb, 
    output logic [GB_BANDWIDTH-1:0]     gb_dinb,  
    output logic [GB_BANDWIDTH/8-1:0]   gb_web,   
    output logic                        gb_enb,    
    input  wire [GB_BANDWIDTH-1:0]      gb_doutb 

    );

    reg [ADDR_WIDTH - 1:0]      mp_src_addr_reg;
    reg [ADDR_WIDTH - 1:0]      mp_src_h_reg;
    reg [ADDR_WIDTH - 1:0]      mp_src_w_reg;
    reg [ADDR_WIDTH - 1:0]      mp_src_c_reg;
    reg [ADDR_WIDTH - 1:0]      mp_dst_addr_reg;
    
    

    typedef enum logic [5:0] {
        IDLE          ,
        MP_REG        ,
        MP_BOUND_1,
        MP_BOUND_2,
        MP_UPDATE     ,
        MP_LOAD_CMP   ,
        MP_VALID_FETCH,
        MP_VALID_MUL  ,
        MP_VALID_COMP  ,
        MP_VALID_GET  ,
        MP_LOAD       ,
        MP_WAIT     ,
        MP_COMPARE    ,
        MP_SAVE_GET,
        MP_SAVE       
    } state_t;
    state_t c_state, n_state;

    always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                mp_src_addr_reg     <= '0;
                mp_src_h_reg        <= '0;
                mp_src_w_reg        <= '0;
                mp_src_c_reg        <= '0;
                mp_dst_addr_reg     <= '0;
            end else begin
                if(c_state == MP_REG) begin
                    mp_src_addr_reg     <= mp_src_addr;
                    mp_src_h_reg        <= mp_src_h   ;
                    mp_src_w_reg        <= mp_src_w   ;
                    mp_src_c_reg        <= mp_src_c   ;
                    mp_dst_addr_reg     <= mp_dst_addr;
                end
            end

        end


    assign mp_unit_ready = c_state == IDLE;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            c_state <= IDLE;   // 复位时清零
        end else begin
            c_state <= n_state; // 正常运行时更新
        end
    end
    
    wire[ADDR_WIDTH - 1:0]                                  mp_src_stride_col;
    wire[ADDR_WIDTH - 1:0]                                  mp_src_stride_row;
    // assign       mp_src_stride_col = mp_src_c_reg * FP_WIDTH / 8;
    // assign       mp_src_stride_row = mp_src_w_reg * mp_src_c_reg * FP_WIDTH / 8;

    assign       mp_src_stride_col = mp_src_c_reg * FP_WIDTH / 8;
    assign       mp_src_stride_row = (mp_src_h_reg + 4) * mp_src_c_reg * FP_WIDTH / 8;
    wire [ADDR_WIDTH-1:0]                                     mp_load_addr [0:24];
    reg  [ADDR_WIDTH-1:0]                                     mp_save_addr;
    wire [GB_BANDWIDTH - 1 : 0]                               mp_res;
    wire                                                      mp_res_valid;
    reg [GB_BANDWIDTH - 1 : 0]                                mp_res_reg;
    logic [GB_BANDWIDTH - 1 : 0]                              mp_act_buf[0:24];
    logic [$clog2(5*5) - 1 : 0]                               mp_pool_cnt;
    logic [$clog2(MAX_CHANNEL_NUM * FP_WIDTH) - 1 : 0]  mp_channel_cnt;

    logic [GB_ADDR_WIDTH-1:0]                                 mp_src_addr_block;
    logic [GB_ADDR_WIDTH-1:0]                                 mp_src_stride_col_block;
    logic [GB_ADDR_WIDTH-1:0]                                 mp_src_stride_row_block;
    logic [GB_ADDR_WIDTH-1:0]                                 mp_dst_addr_block;
    
    

    assign mp_src_addr_block        = mp_src_addr        >> 5;
    assign mp_src_stride_col_block  = mp_src_stride_col  >> 5;
    assign mp_src_stride_row_block  = mp_src_stride_row  >> 5;
    assign mp_dst_addr_block        = mp_dst_addr_reg        >> 5;

    
    
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            for (i = 0; i < 25; i = i + 1) begin
                mp_act_buf[i] <= 0;   // ✅ 对每个元素清零
            end
        end else begin
            if(c_state == IDLE) begin
                for (i = 0; i < 25; i = i + 1) begin
                    mp_act_buf[i] <= 0;   // ✅ 对每个元素清零
                end
            end else if(c_state == MP_WAIT) begin
                mp_act_buf[mp_pool_cnt] <= gb_doutb;
            end
        end
    end

  // ================================= MP start =======================================


    
    // 假设这些 limit/wires 已经在别处定义/计算
    wire [$clog2(5*5)-1:0] POOL_LIMIT = 24; // or parameter
    wire [ADDR_WIDTH-1:0] ROW_LIMIT   = mp_src_h_reg + 2*2 - 5;
    wire [ADDR_WIDTH-1:0] COL_LIMIT   = mp_src_w_reg  + 2*2 - 5;

    // logicisters (unchanged widths as your original)
    logic [ADDR_WIDTH - 1 : 0]  mp_row_index, mp_col_index;


    // next-state temporaries (combinational)
    logic [ADDR_WIDTH - 1 : 0]  next_mp_row_index, next_mp_col_index;
    logic [$clog2(5*5) - 1 : 0] next_pool_cnt;
    logic [$clog2(MAX_CHANNEL_NUM * FP_WIDTH) - 1 : 0] next_channel_cnt;

    // logicistered done
    logic mp_done_r;
    wire mp_done = mp_done_r; // use this externally
    

    // combinational: build next-state based on current state and current "load_done" conditions
    // (we still use current col_load_done/current row_load_done for branching, but we compute
    // the final "done" based on next_* so it aligns with new values)
    wire row_load_done_cur = (mp_row_index == ROW_LIMIT);
    wire col_load_done_cur =    (mp_col_index == COL_LIMIT);
    wire channel_load_done_cur = (mp_channel_cnt == mp_src_stride_col_block - 1);
    wire pool_load_done_cur = (mp_pool_cnt == POOL_LIMIT);


        // compute done signals based on next-state (so they will be true in same cycle after logics update)
    wire pool_load_done_next    = (next_pool_cnt == POOL_LIMIT);
    wire channel_load_done_next = (next_channel_cnt == mp_src_stride_col_block - 1);
    wire row_load_done_next     = (next_mp_row_index == ROW_LIMIT);
    wire col_load_done_next     = (next_mp_col_index == COL_LIMIT);

    reg [$clog2(5*5) : 0]   mp_valid_cnt;
    wire   mp_valid_done;
    assign mp_valid_done          = (mp_valid_cnt == (5 * 5));

    always @* begin
        // default: hold
        next_mp_row_index    = mp_row_index;
        next_mp_col_index    = mp_col_index;
        next_channel_cnt  = mp_channel_cnt;
        next_pool_cnt     = mp_pool_cnt;

        if (mp_done_r) begin
            // once done, next cycle reset all to zero
            next_mp_row_index   = 0;
            next_mp_col_index   = 0;
            next_channel_cnt = 0;
            next_pool_cnt    = 0;
        end else if (col_load_done_cur && channel_load_done_cur && pool_load_done_cur) begin
            // finished a column-block, move to next row
            next_mp_row_index   = mp_row_index + 1;
            next_mp_col_index   = 0;
            next_channel_cnt = 0;
            next_pool_cnt    = 0;
        end else if (channel_load_done_cur && pool_load_done_cur) begin
            // finished a channel-block, move to next col
            next_mp_row_index   = mp_row_index;
            next_mp_col_index   = mp_col_index + 1;
            next_channel_cnt = 0;
            next_pool_cnt    = 0;
        end else if (pool_load_done_cur) begin
            // finished a pooling element, advance channel counter
            next_mp_row_index   = mp_row_index;
            next_mp_col_index   = mp_col_index;
            next_channel_cnt = mp_channel_cnt + 1'b1;
            next_pool_cnt    = 0;
        end else begin
            // normal: advance pool counter
            next_mp_row_index   = mp_row_index;
            next_mp_col_index   = mp_col_index;
            next_channel_cnt = mp_channel_cnt;
            next_pool_cnt    = mp_pool_cnt + 1'b1;
        end
    end



    wire mp_done_next_comb = pool_load_done_next && channel_load_done_next && row_load_done_next && col_load_done_next;

    // sequential: logicister all next values (synchronous)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mp_row_index   <= 0;
            mp_col_index   <= 0;
            mp_channel_cnt <= 0;
            mp_pool_cnt    <= 0;
            mp_done_r      <= 1'b0;
        end else begin
            if(c_state == IDLE) begin
                mp_row_index   <= 0;
                mp_col_index   <= 0;
                mp_channel_cnt <= 0;
                mp_pool_cnt    <= 0;
                mp_done_r      <= 1'b0;
            end else if(c_state == MP_UPDATE) begin
                mp_row_index   <= next_mp_row_index;
                mp_col_index   <= next_mp_col_index;
                mp_channel_cnt <= next_channel_cnt;
                mp_pool_cnt    <= next_pool_cnt;
                mp_done_r      <= mp_done_next_comb;
            end
            
        end
    end


    // genreate 4 margin point of src
    /*
    1------------0
    |            |
    |            |
    2------------3 
    */
    reg [ADDR_WIDTH - 1 : 0]  mp_src_addr_0, mp_src_addr_1,mp_src_addr_2,mp_src_addr_3, mp_row_min, mp_row_max, mp_col_min,mp_col_max;
    wire [ADDR_WIDTH - 1 : 0] mp_full_row_length;
    // assign mp_src_addr_0 =  2 * (4 + mp_src_w_reg) + 2;
    // assign mp_src_addr_1 = mp_src_addr_0 + mp_src_w_reg - 1;
    // assign mp_src_addr_2 = mp_src_addr_3 + mp_src_w_reg - 1;
    // assign mp_src_addr_3 = (4 + mp_src_w_reg) * (2 + mp_src_h_reg - 1) + 2;
    // assign mp_full_row_length = 4 + mp_src_w_reg;
    // assign mp_row_min = mp_src_addr_0 / mp_full_row_length;
    // assign mp_col_min = mp_src_addr_0 % mp_full_row_length;
    // assign mp_row_max = mp_src_addr_2 / mp_full_row_length;
    // assign mp_col_max = mp_src_addr_2 % mp_full_row_length;

    assign mp_full_row_length = 15;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mp_src_addr_0    <= '0;
            mp_src_addr_1    <= '0;
            mp_src_addr_2    <= '0;
            mp_src_addr_3    <= '0;
            mp_row_min       <= '0;
            mp_row_max       <= '0;
            mp_col_min       <= '0;
            mp_col_max       <= '0;
            // mp_full_row_length <= '0;
        end else begin
            if(c_state == MP_BOUND_1) begin
                mp_src_addr_0 <=  2 * (4 + mp_src_w_reg) + 2;
                mp_src_addr_1 <= (2 * (4 + mp_src_w_reg) + 2) + mp_src_w_reg - 1;
                mp_src_addr_2 <= ((4 + mp_src_w_reg) * (2 + mp_src_h_reg - 1) + 2) + mp_src_w_reg - 1;
                mp_src_addr_3 <= (4 + mp_src_w_reg) * (2 + mp_src_h_reg - 1) + 2;
                // mp_full_row_length <= 4 + mp_src_w_reg;
            end else if(c_state == MP_BOUND_2) begin
                mp_row_min <= mp_src_addr_0 / mp_full_row_length;
                mp_col_min <= mp_src_addr_0 % mp_full_row_length;
                mp_row_max <= mp_src_addr_2 / mp_full_row_length;
                mp_col_max <= mp_src_addr_2 % mp_full_row_length;
            end else if(c_state == IDLE) begin
                mp_src_addr_0    <= '0;
                mp_src_addr_1    <= '0;
                mp_src_addr_2    <= '0;
                mp_src_addr_3    <= '0;
                mp_row_min       <= '0;
                mp_row_max       <= '0;
                mp_col_min       <= '0;
                mp_col_max       <= '0;
                // mp_full_row_length <= '0;
            end

        end
    end





    reg [ADDR_WIDTH-1:0] mp_load_addr_reg[0:24];
    reg                  mp_valid_mask_reg[0:24];

    genvar gi, gj;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : GEN_ROW
            for (gj = 0; gj < 5; gj = gj + 1) begin : GEN_COL
                localparam idx = gi*5 + gj;
                // ---------------------------
                // mp_load_addr 线性计算
                // ---------------------------
                assign mp_load_addr[idx] = (mp_row_index + gi) * (mp_src_w_reg + 4)
                                            + (mp_col_index + gj);
            end
        end
    endgenerate


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for(i = 0; i < 25; i = i + 1) begin
                mp_load_addr_reg[i]   <= '0;
            end
        end else begin
            if (c_state == MP_LOAD_CMP) begin
                for(i = 0; i < 25; i = i + 1) begin
                    mp_load_addr_reg[i] <= mp_load_addr[i];
                end
            end
        end
    end

    // generate
    //     for (gi = 0; gi < 5; gi = gi + 1) begin : GEN_ROW_1
    //         for (gj = 0; gj < 5; gj = gj + 1) begin : GEN_COL_1
    //             localparam idx = gi*5 + gj;
        reg [ADDR_WIDTH-1:0] lar;
        reg [ADDR_WIDTH-1:0] lar_row_reg;
        reg [ADDR_WIDTH-1:0] lar_col_reg;
        reg row_in_range_reg;
        reg col_in_range_reg;

        // ---------------------------
        // 掩码逻辑
        // ---------------------------
        // assign mp_valid_mask[idx] = row_in_range_reg && col_in_range_reg;
    //         end
    //     end
    // endgenerate


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for(i = 0; i < 25; i = i + 1) begin
                mp_valid_mask_reg[i]  <= 1'b0;
            end
            mp_valid_cnt          <= '0;
            lar_row_reg           <= '0;
            lar_col_reg           <= '0;
            col_in_range_reg      <= '0;
            row_in_range_reg      <= '0;
            lar                   <= '0;
        end else begin
            if(c_state == MP_VALID_FETCH) begin
                lar <= mp_load_addr_reg[mp_valid_cnt];
            end else if(c_state == MP_VALID_MUL) begin
                lar_row_reg <= lar / mp_full_row_length;
                lar_col_reg <= lar % mp_full_row_length; 
            end else if(c_state == MP_VALID_COMP) begin
                row_in_range_reg <= (lar_row_reg <= mp_row_max) && (lar_row_reg >= mp_row_min);
                col_in_range_reg <= (lar_col_reg <= mp_col_max) && (lar_col_reg >= mp_col_min);
            end else if (c_state == MP_VALID_GET) begin
                mp_valid_mask_reg[mp_valid_cnt] <= row_in_range_reg && col_in_range_reg;
                mp_valid_cnt <= mp_valid_cnt + 1'b1;
            end else if(c_state == IDLE || c_state == MP_UPDATE ) begin
                for(i = 0; i < 25; i = i + 1) begin
                    mp_valid_mask_reg[i]  <= 1'b0;
                end
                mp_valid_cnt          <= '0;
            end
        end
    end


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
            
        end else if(c_state == MP_LOAD) begin
            gb_addrb = (mp_load_addr_reg[mp_pool_cnt] * mp_src_stride_col_block) + mp_src_addr_block + mp_channel_cnt;
            gb_enb = 1'b1;
            gb_web = {(GB_BANDWIDTH / 8){1'b0}};
        end else if(c_state == MP_WAIT) begin
            gb_enb   = 1'b0;
            gb_addrb = '0;
        end else if(c_state == MP_SAVE) begin
            gb_addrb = mp_save_addr ;
            gb_web = {(GB_BANDWIDTH / 8){1'b1}};
            gb_enb = 1'b1;
            gb_dinb = mp_res_reg;
        end  else begin
            gb_enb=0; 
            gb_web=0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mp_save_addr <= '0;
            mp_res_reg   <= '0;
        end else begin
            if(c_state == MP_SAVE_GET) begin
                mp_save_addr <= mp_row_index * mp_src_w_reg * mp_src_stride_col_block + mp_col_index * mp_src_stride_col_block + mp_dst_addr_block + mp_channel_cnt;
                mp_res_reg <= mp_res;
            end
        end
    end
    // assign mp_save_addr = mp_row_index * mp_src_w_reg * mp_src_stride_col_block + mp_col_index * mp_src_stride_col_block + mp_dst_addr_block + mp_channel_cnt;


    wire [GB_BANDWIDTH*25 - 1 : 0] mp_act_buf_flat;
    wire                           mp_act_valid;
    assign  mp_act_valid = (c_state == MP_COMPARE);
    wire [25-1:0]                             mp_valid_mask_flat;

    // genvar gi;
    generate
        for (gi = 0; gi < 25; gi = gi + 1) begin
            // mp_act_buf[gi] 放到 mp_act_buf_flat 的偏移 gi*GB_BANDWIDTH 开始处
            assign mp_act_buf_flat[ gi*GB_BANDWIDTH +: GB_BANDWIDTH ] = mp_act_buf[gi];
            assign mp_valid_mask_flat[gi] = mp_valid_mask_reg[gi];
        end
    endgenerate

    // 模块实例：传入平铺向量
    max_pooling2d5x5 #(
        .FP_WIDTH(FP_WIDTH),
        .GB_BANDWIDTH(GB_BANDWIDTH)
    ) u_max_pool (
        .rst_n(rst_n),
        .clk(clk),
        .mp_act_buf(mp_act_buf_flat),
        .mp_valid_mask(mp_valid_mask_flat),
        .mp_act_valid(mp_act_valid),
        .mp_res(mp_res),
        .mp_res_valid(mp_res_valid)
    );


  // ================================= MP end =======================================

  //========================controller=========================================

    //´ÎÌ¬Âß¼­
    always @(*) begin
        n_state=IDLE;
        case(c_state)
            IDLE:   begin
                if(mp_unit_start) begin
                    n_state = MP_REG;

                end
            end
            MP_REG: n_state = MP_BOUND_1;
            MP_BOUND_1: n_state = MP_BOUND_2;
            MP_BOUND_2: n_state = MP_LOAD_CMP;
            MP_UPDATE : n_state = MP_LOAD_CMP;
            MP_LOAD_CMP: n_state = MP_VALID_FETCH;
            MP_VALID_FETCH: n_state = MP_VALID_MUL;
            MP_VALID_MUL: n_state = MP_VALID_COMP;
            MP_VALID_COMP: n_state =  MP_VALID_GET;
            MP_VALID_GET: n_state = mp_valid_done ? MP_LOAD : MP_VALID_FETCH;
            MP_LOAD: n_state = MP_WAIT;
            MP_WAIT: n_state = pool_load_done_cur ? MP_COMPARE: MP_UPDATE;
            MP_COMPARE : n_state = mp_res_valid ? MP_SAVE_GET : MP_COMPARE;
            MP_SAVE_GET: n_state = MP_SAVE;
            MP_SAVE: if(mp_done) n_state = IDLE; else n_state = MP_UPDATE;
            default : n_state = IDLE;
        endcase
        end
    endmodule

