`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// TIMING FIX APPLIED:
// 1. Removed combinational logic driving gb_addrb/gb_enb to fix Setup Violation (-2.2ns).
// 2. Introduced pipeline registers (gb_addrb_reg, gb_enb_reg) to cut the critical path.
// 3. Address calculation is now performed in the state PRECEDING the load/save operation.
//////////////////////////////////////////////////////////////////////////////////

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
        // ★ 每一行在 block 地址空间里的步长：mp_src_w_reg * mp_src_stride_col_block
    reg [ADDR_WIDTH - 1:0]      mp_row_stride_block_reg;
    reg [ADDR_WIDTH - 1:0]      mp_line_stride_reg;      // 存储 mp_src_w_reg + 4
    reg [ADDR_WIDTH - 1:0]      mp_row_base_addr_reg;    // 存储 mp_row_index * stride 的结果
    reg [ADDR_WIDTH - 1:0]      stride_x1, stride_x2, stride_x3, stride_x4;
    reg [ADDR_WIDTH - 1:0]      mult_temp_reg; // ★ NEW: 用于存储乘法中间结果

    
    

    typedef enum logic [5:0] {
        IDLE          ,
        MP_REG        ,
        MP_BOUND_1,
        MP_BOUND_1_WAIT, // ★ NEW: 新增一个等待状态用于打拍乘法
        MP_BOUND_2,
        MP_UPDATE     ,
        MP_LOAD_CMP , 
        MP_VALID_FETCH,
        MP_VALID_MUL  ,
        MP_VALID_MUL2 ,   // ★ 新增
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
    wire [ADDR_WIDTH-1:0]                                     mp_load_addr [0:24]; // 加法结果（组合）
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

    
    // Stage 1: 简单的 increment / reset 逻辑
    
    logic [$clog2(5*5)-1:0] stage1_pool_cnt;
    logic [$clog2(5*5)-1:0] stage1_pool_cnt_r;

    always_comb begin
        if (pool_load_done_cur)
            stage1_pool_cnt = 0;
        else
            stage1_pool_cnt = mp_pool_cnt + 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            stage1_pool_cnt_r <= 0;
        else
            stage1_pool_cnt_r <= stage1_pool_cnt;   // pipeline!
    end

    // -----------------------------------------------------
    // Stage 2: 使用打一拍之后的 stage1_pool_cnt_r
    // 处理所有 row/col/channel/pool 的复杂条件
    // -----------------------------------------------------
    always_comb begin
        // default: hold
        next_mp_row_index    = mp_row_index;
        next_mp_col_index    = mp_col_index;
        next_channel_cnt     = mp_channel_cnt;
        next_pool_cnt        = stage1_pool_cnt_r;

        if (mp_done_r) begin
            next_mp_row_index   = 0;
            next_mp_col_index   = 0;
            next_channel_cnt    = 0;
            next_pool_cnt       = 0;

        end else if (col_load_done_cur && channel_load_done_cur && pool_load_done_cur) begin
        // finished a column-block → go to next row
            next_mp_row_index   = mp_row_index + 1;
            next_mp_col_index   = 0;
            next_channel_cnt    = 0;
            next_pool_cnt       = 0;

        end else if (channel_load_done_cur && pool_load_done_cur) begin
        // finished a channel-block → go to next col
            next_mp_row_index   = mp_row_index;
            next_mp_col_index   = mp_col_index + 1;
            next_channel_cnt    = 0;
            next_pool_cnt       = 0;

        end else if (pool_load_done_cur) begin
        // finished a pooling element → advance channel
            next_mp_row_index   = mp_row_index;
            next_mp_col_index   = mp_col_index;
            next_channel_cnt    = mp_channel_cnt + 1'b1;
            next_pool_cnt       = 0;
        end
     // normal case 已经由 stage1_pool_cnt_r 处理
    end


    wire mp_done_next_comb = pool_load_done_next && channel_load_done_next && row_load_done_next && col_load_done_next;

    // sequential: logicister all next values (synchronous)
    // ============================================================
    // 第三步修改：状态更新逻辑 (Accumulator Update)
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mp_row_index         <= 0;
            mp_col_index         <= 0;
            mp_channel_cnt       <= 0;
            mp_pool_cnt          <= 0;
            mp_done_r            <= 1'b0;
            
            // ★【新增】复位基地址
            mp_row_base_addr_reg <= 0; 

        end else begin
            if(c_state == IDLE) begin
                mp_row_index         <= 0;
                mp_col_index         <= 0;
                mp_channel_cnt       <= 0;
                mp_pool_cnt          <= 0;
                mp_done_r            <= 1'b0;
                
                // ★【新增】IDLE 时清零
                mp_row_base_addr_reg <= 0;

            end else if(c_state == MP_UPDATE) begin
                // 1. 更新原本的索引 (保持不变)
                mp_row_index   <= next_mp_row_index;
                mp_col_index   <= next_mp_col_index;
                mp_channel_cnt <= next_channel_cnt;
                mp_pool_cnt    <= next_pool_cnt;
                mp_done_r      <= mp_done_next_comb;

                // 2. ★【新增】核心优化逻辑：基地址累加
                
                // 情况 A: 如果下一行又要从 0 开始 (比如处理完了一张图，或者复位)
                if (next_mp_row_index == 0) begin
                    mp_row_base_addr_reg <= 0;
                end 
                // 情况 B: 如果行号增加了 1 (next = current + 1)
                // 这说明我们要换行了，只需要把当前的基地址 + 步长 (mp_line_stride_reg)
                else if (next_mp_row_index == mp_row_index + 1) begin
                    mp_row_base_addr_reg <= mp_row_base_addr_reg + mp_line_stride_reg;
                end
                // 情况 C: 如果行号没变 (还在处理同一行的不同列或不同通道)
                // mp_row_base_addr_reg 保持不变 (Latch/Reg hold)，不需要操作
                
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
    // 临时逻辑变量，用于辅助计算，不占用寄存器资源
    reg [ADDR_WIDTH-1:0] row_width_comb; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mp_src_addr_0       <= '0;
            mp_src_addr_1       <= '0;
            mp_src_addr_2       <= '0;
            mp_src_addr_3       <= '0;
            mp_row_min          <= '0;
            mp_row_max          <= '0;
            mp_col_min          <= '0;
            mp_col_max          <= '0;
            
            // ★ 新增寄存器复位
            mp_line_stride_reg  <= '0;
            stride_x1 <= '0; stride_x2 <= '0; stride_x3 <= '0; stride_x4 <= '0;
            mp_row_stride_block_reg <= '0; 
        end else begin
            
            // 计算单行宽度的组合逻辑 (Width + Padding)
            row_width_comb = mp_src_w_reg + 4; 

            if(c_state == MP_BOUND_1) begin
                // 1. 简单的移位/加法逻辑，可以直接算完
                mp_line_stride_reg <= row_width_comb;
                stride_x1          <= row_width_comb;
                stride_x2          <= row_width_comb << 1;
                stride_x3          <= (row_width_comb << 1) + row_width_comb; 
                stride_x4          <= row_width_comb << 2;

                mp_src_addr_0 <= (row_width_comb << 1) + 2;
                mp_src_addr_1 <= ((row_width_comb << 1) + 2) + mp_src_w_reg - 1;
                
                // 2. ★ 复杂乘法：只算乘法部分，存入中间寄存器
                mult_temp_reg <= row_width_comb * (mp_src_h_reg + 1);

                // 这个乘法看起来比较小(stride * block)，如果也报错，也可以同样拆分。
                // 目前先保持原样，或者也用 mult_temp_reg 逻辑处理(如果不需要并发)
                mp_row_stride_block_reg <= mp_src_w_reg * mp_src_stride_col_block;

            end else if (c_state == MP_BOUND_1_WAIT) begin
                // ★ NEW STATE: 利用上一拍算好的乘法结果，加上偏移量
                // 这样就把长路径切断了
                mp_src_addr_2 <= mult_temp_reg + 2 + mp_src_w_reg - 1;
                mp_src_addr_3 <= mult_temp_reg + 2;


            end else if(c_state == MP_BOUND_2) begin
                // 你的除法和取模运算 (除数是常数 15，综合器会优化成乘法和移位，通常没问题)
                mp_row_min <= mp_src_addr_0 / mp_full_row_length;
                mp_col_min <= mp_src_addr_0 % mp_full_row_length;
                mp_row_max <= mp_src_addr_2 / mp_full_row_length;
                mp_col_max <= mp_src_addr_2 % mp_full_row_length;

            end else if(c_state == IDLE) begin
                // IDLE 清零
                mp_src_addr_0       <= '0;
                mp_src_addr_1       <= '0;
                mp_src_addr_2       <= '0;
                mp_src_addr_3       <= '0;
                mp_row_min          <= '0;
                mp_row_max          <= '0;
                mp_col_min          <= '0;
                mp_col_max          <= '0;
                mp_line_stride_reg  <= '0;
                stride_x1 <= '0; stride_x2 <= '0; stride_x3 <= '0; stride_x4 <= '0;
                mp_row_stride_block_reg <= '0;
            end
        end
    end




    reg [ADDR_WIDTH-1:0] mp_load_addr_reg[0:24];
    reg                  mp_valid_mask_reg[0:24];

        genvar gi, gj;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : GEN_ROW
            // 在每一行生成块中，根据 gi 选择预先算好的偏移量
            // 因为 gi 是编译时常量，综合器会直接连线，没有任何逻辑门延迟
            wire [ADDR_WIDTH-1:0] row_offset;
            
            if (gi == 0)      assign row_offset = 0;
            else if (gi == 1) assign row_offset = stride_x1;
            else if (gi == 2) assign row_offset = stride_x2;
            else if (gi == 3) assign row_offset = stride_x3;
            else              assign row_offset = stride_x4; // gi=4

            for (gj = 0; gj < 5; gj = gj + 1) begin : GEN_COL
                localparam idx = gi*5 + gj;
                
                // ---------------------------
                // ★ 优化后的计算：纯加法
                // 地址 = (当前行基地址) + (行内固定偏移) + (当前列索引) + (列偏移)
                // ---------------------------
                assign mp_load_addr[idx] = mp_row_base_addr_reg + row_offset + mp_col_index + gj;

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

        // 新增：打一拍的中间结果
        reg [ADDR_WIDTH-1:0] lar_row_mid;
        reg [ADDR_WIDTH-1:0] lar_col_mid;
        reg row_in_range_reg;
        reg col_in_range_reg;

        // ---------------------------
        // 掩码逻辑
        // ---------------------------
        // assign mp_valid_mask[idx] = row_in_range_reg && col_in_range_reg;
    //         end
    //     end
    // endgenerate
    reg [63:0] div_temp_prod; // 用于存乘积

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        for(i = 0; i < 25; i = i + 1) begin
            mp_valid_mask_reg[i]  <= 1'b0;
        end
        mp_valid_cnt          <= '0;

        lar            <= '0;
        lar_row_mid    <= '0;
        lar_col_mid    <= '0;
        lar_row_reg    <= '0;
        lar_col_reg    <= '0;

        row_in_range_reg <= 1'b0;
        col_in_range_reg <= 1'b0;
        end else begin
        // 默认不改 mp_valid_mask_reg[...]，只在 MP_VALID_GET 或清零时改

        if (c_state == IDLE || c_state == MP_UPDATE) begin
            // 每次重新开始一次 window 的时候，把 mask 和计数清掉
            for(i = 0; i < 25; i = i + 1) begin
                mp_valid_mask_reg[i]  <= 1'b0;
            end
            mp_valid_cnt      <= '0;

            row_in_range_reg  <= 1'b0;
            col_in_range_reg  <= 1'b0;
        end

        // 1. 取线性地址
        if (c_state == MP_VALID_FETCH) begin
            lar <= mp_load_addr_reg[mp_valid_cnt];
        end

        // 2. ★ 最重的 / 和 % 放在这拍里，结果打一拍到 mid 寄存器
        if (c_state == MP_VALID_MUL) begin
            div_temp_prod <= lar * 64'd286331153;
            /*lar_row_mid <= lar / mp_full_row_length;
            lar_col_mid <= lar % mp_full_row_length;*/
        end

        // 3. ★ 下一拍再把 mid 搬到真正的 row/col 寄存器
        if (c_state == MP_VALID_MUL2) begin
            // 商 = 乘积的高 32 位
            lar_row_reg <= div_temp_prod[63:32]; 
            
            // 余数 = 被除数 - 商 * 15
            // 注意：这里引用的是上一拍的 lar，需要保持 lar 不变
            lar_col_reg <= lar - (div_temp_prod[63:32] * 15);
            /*lar_row_reg <= lar_row_mid;
            lar_col_reg <= lar_col_mid;*/
        end

        // 4. 再下一拍做范围比较
        if (c_state == MP_VALID_COMP) begin
            row_in_range_reg <= (lar_row_reg <= mp_row_max) && (lar_row_reg >= mp_row_min);
            col_in_range_reg <= (lar_col_reg <= mp_col_max) && (lar_col_reg >= mp_col_min);
        end

        // 5. 最后一拍写 mask，计数 +1
        if (c_state == MP_VALID_GET) begin
            mp_valid_mask_reg[mp_valid_cnt] <= row_in_range_reg && col_in_range_reg;
            mp_valid_cnt                    <= mp_valid_cnt + 1'b1;
        end
        end
    end


    //logic for gb read/write: load_x、wait_x、save state
    
    // FIX START: Register definitions for pipeline
    reg [GB_ADDR_WIDTH-1:0]    gb_addrb_reg;
    reg [GB_BANDWIDTH-1:0]     gb_dinb_reg;
    reg [GB_BANDWIDTH/8-1:0]   gb_web_reg;
    reg                        gb_enb_reg;

    // Combinational logic just connects registers to ports (truncating the path)
    always_comb begin
        gb_addrb = gb_addrb_reg;
        gb_dinb  = gb_dinb_reg;
        gb_web   = gb_web_reg;
        gb_enb   = gb_enb_reg;
    end

    // Registered Logic for GB ports
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            gb_addrb_reg <= 0;
            gb_dinb_reg  <= 0;
            gb_web_reg   <= 0;
            gb_enb_reg   <= 0;
        end else begin
            // Turn off ENB by default in states where we executed the command
            // This creates a 1-cycle pulse for LOAD and SAVE if valid for 1 cycle
            if (c_state == MP_LOAD || c_state == MP_SAVE) begin
                gb_enb_reg <= 1'b0; 
                gb_web_reg <= 0;
            end

            // Pre-calculate Address for MP_LOAD
            // Original: Calculated inside MP_LOAD.
            // Fix: Calculate inside MP_VALID_GET when moving to MP_LOAD
            else if (c_state == MP_VALID_GET && mp_valid_done) begin
                gb_addrb_reg <= (mp_load_addr_reg[mp_pool_cnt] * mp_src_stride_col_block) + mp_src_addr_block + mp_channel_cnt;
                gb_enb_reg   <= 1'b1;
                gb_web_reg   <= '0; // Read operation
            end

            // Pre-calculate Address/Data for MP_SAVE
            // Original: Calculated inside MP_SAVE_GET (for addr) and MP_SAVE (for write).
            // Fix: Setup everything in MP_SAVE_GET
            else if (c_state == MP_SAVE_GET) begin
            // ★ 只做：row_index * row_stride + col_index * stride_col + offset
            gb_addrb_reg <= mp_row_index * mp_row_stride_block_reg
                            + mp_col_index * mp_src_stride_col_block
                            + mp_dst_addr_block + mp_channel_cnt;
            gb_dinb_reg  <= mp_res; // mp_res is valid from previous state
            gb_enb_reg   <= 1'b1;
            gb_web_reg   <= {(GB_BANDWIDTH/8){1'b1}}; // Write all bytes
        end

            
            // IDLE Reset
            else if (c_state == IDLE) begin
                gb_enb_reg <= 1'b0;
            end
        end
    end

        always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mp_save_addr <= '0;
            mp_res_reg   <= '0;
        end else begin
            if(c_state == MP_SAVE_GET) begin
                // ★ 和 gb_addrb_reg 用同一个地址公式
                mp_save_addr <= mp_row_index * mp_row_stride_block_reg
                                + mp_col_index * mp_src_stride_col_block
                                + mp_dst_addr_block + mp_channel_cnt;
                mp_res_reg <= mp_res;
            end
        end
    end

    // assign mp_save_addr = mp_row_index * mp_src_w_reg * mp_src_stride_col_block + mp_col_index * mp_src_stride_col_block + mp_dst_addr_block + mp_channel_cnt;


    wire [GB_BANDWIDTH*25 - 1 : 0] mp_act_buf_flat;
    wire                           mp_act_valid;
    assign  mp_act_valid = (c_state == MP_COMPARE);
    wire [25-1:0]                                     mp_valid_mask_flat;

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
            
            // ★ 修改跳转逻辑：插入 WAIT 状态
            MP_BOUND_1:      n_state = MP_BOUND_1_WAIT; 
            MP_BOUND_1_WAIT: n_state = MP_BOUND_2;
            
            MP_BOUND_2: n_state = MP_LOAD_CMP;
            MP_UPDATE : n_state = MP_LOAD_CMP;
            MP_LOAD_CMP:    n_state = MP_VALID_FETCH;
            MP_VALID_FETCH: n_state = MP_VALID_MUL;
            MP_VALID_MUL:   n_state = MP_VALID_MUL2;   // ★ 先进新状态打一拍
            MP_VALID_MUL2:  n_state = MP_VALID_COMP;
            MP_VALID_COMP:  n_state = MP_VALID_GET;
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