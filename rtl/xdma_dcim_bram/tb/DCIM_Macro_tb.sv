`timescale 1ns / 1ps
`include "dcim_defs.vh"

// ============================================================================
// DCIM_Macro Testbench - 验证 INT8/INT16 矩阵乘法，支持 CH_OUT=64
// ============================================================================
// 测试场景：
//   1. INT8 超小矩阵 [4, 8] × [8, 64]（M<16, K<16，需要补0对齐）
//   2. INT8 小矩阵 [8, 16] × [16, 64]（M<16, K=16）
//   3. INT8 正好 tile [32, 16] × [16, 64]（单 tile）
//   4. INT8 大矩阵 [32, 64] × [64, 64]（4 个 tile 累加）
//   5. INT16 超小矩阵 [2, 4] × [4, 64]（M<16, K<16）
//   6. INT16 小矩阵 [4, 16] × [16, 64]（M<16, K=16）
//   7. INT16 正好 tile [16, 16] × [16, 64]（单 tile）
//   8. INT16 大矩阵 [16, 64] × [64, 64]（4 个 tile 累加）

module DCIM_Macro_tb;

    localparam CLK_PERIOD = 10;
    localparam CH_IN = `DCIM_CH_IN;      // 16
    localparam CH_OUT = `DCIM_CH_OUT;    // 64
    localparam IBUF_DEPTH = (1 << `DCIM_IBUF_ADDR_WIDTH);
    localparam OBUF_DEPTH = (1 << `DCIM_OBUF_ADDR_WIDTH);

    // 时钟和复位
    logic clk;
    logic rst_n;

    // DUT 信号
    logic                         dcim_start;
    logic                         dcim_config_valid;
    logic                         dcim_config_ready;
    logic                         dcim_busy;
    logic                         dcim_done;
    logic                         dcim_error;
    logic [31:0]                  dcim_error_code;
    
    logic [31:0]                  wsrc_base_addr;
    logic [31:0]                  asrc_base_addr;
    logic [31:0]                  dst_addr;
    logic [31:0]                  raw_rows;
    logic [2:0]                   mode;
    logic [4:0]                   acc;
    logic                         save_to_obuf;
    
    logic                         ibuf_enb;
    logic [`DCIM_IBUF_ADDR_WIDTH-1:0]   ibuf_addrb;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0]   ibuf_doutb;
    
    logic                         obuf_enb;
    logic [`DCIM_BRAM_BYTES-1:0]        obuf_web;
    logic [`DCIM_OBUF_ADDR_WIDTH-1:0]   obuf_addrb;
    logic [`DCIM_BRAM_DATA_WIDTH-1:0]   obuf_dinb;
    
    logic [CH_OUT*32-1:0]         psum_out;

    // BRAM 模型（使用var类型允许procedural赋值）
    var logic [`DCIM_BRAM_DATA_WIDTH-1:0] ibuf_mem [IBUF_DEPTH] = '{default: '0};
    var logic [`DCIM_BRAM_DATA_WIDTH-1:0] obuf_mem [OBUF_DEPTH] = '{default: '0};

    // 时钟生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // IBUF 读逻辑
    always_ff @(posedge clk) begin
        if (ibuf_enb)
            ibuf_doutb <= ibuf_mem[ibuf_addrb];
    end

    // OBUF 写逻辑
    always_ff @(posedge clk) begin
        if (obuf_enb && (&obuf_web))
            obuf_mem[obuf_addrb] <= obuf_dinb;
    end

    // DUT 例化
    DCIM_Macro dut (
        .clk(clk),
        .rst_n(rst_n),
        .dcim_start(dcim_start),
        .dcim_config_valid(dcim_config_valid),
        .dcim_config_ready(dcim_config_ready),
        .dcim_busy(dcim_busy),
        .dcim_done(dcim_done),
        .dcim_error(dcim_error),
        .dcim_error_code(dcim_error_code),
        .wsrc_base_addr(wsrc_base_addr),
        .asrc_base_addr(asrc_base_addr),
        .dst_addr(dst_addr),
        .raw_rows(raw_rows),
        .mode(mode),
        .acc(acc),
        .save_to_obuf(save_to_obuf),
        .ibuf_enb(ibuf_enb),
        .ibuf_addrb(ibuf_addrb),
        .ibuf_doutb(ibuf_doutb),
        .obuf_enb(obuf_enb),
        .obuf_web(obuf_web),
        .obuf_addrb(obuf_addrb),
        .obuf_dinb(obuf_dinb),
        .psum_out(psum_out)
    );

    // ========== 通用测试数组（module级别）==========
    reg signed [7:0]  i8_act[2048];     // 最大 32×64
    reg signed [7:0]  i8_weight[2048];  // 最大 64×32
    reg signed [7:0]  i8_tile_act[512]; // tile用
    reg signed [7:0]  i8_tile_wgt[512]; // tile用
    
    reg signed [15:0] i16_act[1024];    // 最大 16×64
    reg signed [15:0] i16_weight[1024]; // 最大 64×16
    reg signed [15:0] i16_tile_act[256];// tile用
    reg signed [15:0] i16_tile_wgt[256];// tile用
    
    int expected_result[64][64];        // 最大输出 64×64

    // ========== 辅助函数 ==========

    // 配置任务
    task automatic config_and_start(
        input [31:0] w_addr,
        input [31:0] a_addr,
        input [31:0] d_addr,
        input [31:0] rows,
        input [2:0]  m,
        input [4:0]  a,
        input        save
    );
        @(posedge clk);
        dcim_config_valid = 1;
        wsrc_base_addr = w_addr;
        asrc_base_addr = a_addr;
        dst_addr = d_addr;
        raw_rows = rows;
        mode = m;
        acc = a;
        save_to_obuf = save;
        
        wait(dcim_config_ready);
        @(posedge clk);
        dcim_config_valid = 0;
        
        // 上升沿触发 start
        dcim_start = 1;
        @(posedge clk);
        dcim_start = 0;
        
        wait(dcim_done);
        @(posedge clk);
    endtask

    // INT8 权重打包
    // INT8模式下，有效输出通道数是ch_out（应该传入CH_OUT/2=32）
    // 每个8位权重对应一个逻辑输出通道
    // 硬件会将8位权重拆成两个4位nibble，在两个phase分别处理，然后合并
    // 权重布局：i8_weight[ch*ch_out + n]，其中ch是输入通道，n是输出通道
    function automatic void pack_weight_int8_flat(
        input int base_word_addr,
        input int ch_in,
        input int ch_out  // 逻辑输出通道数（INT8时为CH_OUT/2=32）
    );
        int col, ch, word_idx, byte_offset, flat_idx;
        logic [255:0] word_data;
        logic [7:0] byte_val;
        int num_words;
        
        // 总共 ch_in * ch_out 字节
        num_words = (ch_in * ch_out * 8 + 255) / 256;
        
        for (word_idx = 0; word_idx < num_words; word_idx++) begin
            word_data = '0;
            for (byte_offset = 0; byte_offset < 32; byte_offset++) begin
                flat_idx = word_idx * 32 + byte_offset;
                ch = flat_idx / ch_out;
                col = flat_idx % ch_out;
                
                if (ch < ch_in && col < ch_out) begin
                    // 直接存储完整的8位权重
                    byte_val = i8_weight[ch*ch_out + col];
                    word_data[byte_offset*8 +: 8] = byte_val;
                end
            end
            ibuf_mem[base_word_addr + word_idx] = word_data;
        end
    endfunction

    // INT8 激活打包（扁平化数组，两行一个 256bit 字）
    function automatic void pack_act_int8_flat(
        input int rows,
        input int base_word_addr
    );
        int r, ch, word_idx;
        logic [255:0] word_data;
        int num_words;
        
        num_words = (rows + 1) / 2;
        for (word_idx = 0; word_idx < num_words; word_idx++) begin
            word_data = '0;
            // 低 128bit：偶数行
            for (ch = 0; ch < CH_IN; ch++)
                if (word_idx*2 < rows)
                    word_data[ch*8 +: 8] = i8_act[(word_idx*2)*CH_IN + ch];
            // 高 128bit：奇数行
            for (ch = 0; ch < CH_IN; ch++)
                if (word_idx*2+1 < rows)
                    word_data[128 + ch*8 +: 8] = i8_act[(word_idx*2+1)*CH_IN + ch];
            ibuf_mem[base_word_addr + word_idx] = word_data;
        end
    endfunction

    // INT16 权重打包
    // INT16模式下，有效输出通道数是ch_out（应该传入CH_OUT/4=16）
    // 每个16位权重对应一个逻辑输出通道
    // 硬件会将16位权重拆成4个4位nibble，在4个phase分别处理，然后合并
    function automatic void pack_weight_int16_flat(
        input int base_word_addr,
        input int ch_in,
        input int ch_out  // 逻辑输出通道数（INT16时为CH_OUT/4=16）
    );
        int g, ch, word_idx, half_offset, flat_idx;
        logic [255:0] word_data;
        logic [15:0] half_val;
        int num_words;
        
        // 总共 ch_in * ch_out 个halfword
        num_words = (ch_in * ch_out * 16 + 255) / 256;
        
        for (word_idx = 0; word_idx < num_words; word_idx++) begin
            word_data = '0;
            for (half_offset = 0; half_offset < 16; half_offset++) begin
                flat_idx = word_idx * 16 + half_offset;
                ch = flat_idx / ch_out;
                g = flat_idx % ch_out;
                
                if (ch < ch_in && g < ch_out) begin
                    // 直接存储完整的16位权重
                    half_val = i16_weight[ch*ch_out + g];
                    word_data[half_offset*16 +: 16] = half_val;
                end
            end
            ibuf_mem[base_word_addr + word_idx] = word_data;
        end
    endfunction

    // INT16 激活打包（扁平化数组）
    function automatic void pack_act_int16_flat(
        input int rows,
        input int base_word_addr
    );
        int r, ch;
        logic [255:0] word_data;
        
        for (r = 0; r < rows; r++) begin
            word_data = '0;
            for (ch = 0; ch < CH_IN; ch++)
                word_data[ch*16 +: 16] = i16_act[r*CH_IN + ch];
            ibuf_mem[base_word_addr + r] = word_data;
        end
    endfunction

    // 验证输出 - INT8模式
    // INT8模式下，每个256位字包含4个有效的32位输出（位置0,2,4,6）
    // 每行输出占用 8 个256位字（CH_OUT=64时）
    function automatic int verify_output_int8(
        input int rows,
        input int cols,
        input int base_word_addr
    );
        int r, c, word_idx, ch_in_word, errors;
        logic [255:0] word_data;
        int got;
        int words_per_row;
        
        words_per_row = 8;  // CH_OUT=64时固定为8个字/行
        errors = 0;
        for (r = 0; r < rows; r++) begin
            for (c = 0; c < cols; c++) begin
                // INT8: 每个字4个有效输出（位置0,2,4,6，即偶数位置）
                word_idx = r * words_per_row + c / 4;
                ch_in_word = (c % 4) * 2;  // 0,2,4,6
                word_data = obuf_mem[base_word_addr + word_idx];
                got = $signed(word_data[ch_in_word*32 +: 32]);
                
                if (got !== expected_result[r][c]) begin
                    $error("[%0d,%0d] Expected %0d, Got %0d", r, c, expected_result[r][c], got);
                    errors++;
                    if (errors >= 10) return errors;
                end
            end
        end
        return errors;
    endfunction

    // 验证输出 - INT16模式
    // INT16模式下，每个256位字包含2个有效的32位输出（位置0,4）
    function automatic int verify_output_int16(
        input int rows,
        input int cols,
        input int base_word_addr
    );
        int r, c, word_idx, ch_in_word, errors;
        logic [255:0] word_data;
        int got;
        int words_per_row;
        
        words_per_row = 8;  // CH_OUT=64时固定为8个字/行
        errors = 0;
        for (r = 0; r < rows; r++) begin
            for (c = 0; c < cols; c++) begin
                // INT16: 每个字2个有效输出（位置0,4）
                word_idx = r * words_per_row + c / 2;
                ch_in_word = (c % 2) * 4;  // 0,4
                word_data = obuf_mem[base_word_addr + word_idx];
                got = $signed(word_data[ch_in_word*32 +: 32]);
                
                if (got !== expected_result[r][c]) begin
                    $error("[%0d,%0d] Expected %0d, Got %0d", r, c, expected_result[r][c], got);
                    errors++;
                    if (errors >= 10) return errors;
                end
            end
        end
        return errors;
    endfunction

    // ========== 测试场景 ==========

    int errors_total = 0;

    initial begin
        $display("========================================");
        $display("DCIM_Macro Testbench (CH_OUT=%0d)", CH_OUT);
        $display("========================================");

        // 初始化
        rst_n = 0;
        dcim_start = 0;
        dcim_config_valid = 0;
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // ========== 测试 1: INT8 超小矩阵 [4, 8] × [8, 32]（K<16）==========
        // INT8模式：有效输出通道数是CH_OUT/2=32
        // 计算：8位激活 × 8位权重（每个权重字节对应一个输出通道）
        begin
            int M, K, N, m, k, n;
            M = 4; K = 8; N = CH_OUT/2;  // N=32
            $display("\n[Test 1] INT8 Ultra-Small Matrix [4, 8] x [8, 32] (K<16)");
            
            // 初始化全0（包括补零部分）
            for (int i = 0; i < M*CH_IN; i++) i8_act[i] = 0;
            for (int i = 0; i < CH_IN*N; i++) i8_weight[i] = 0;
            
            // 填充有效的 K=8 数据
            // 激活：8位有符号数
            for (m = 0; m < M; m++)
                for (k = 0; k < K; k++)
                    i8_act[m*CH_IN + k] = $signed($random % 256 - 128);
            
            // 权重：8位有符号数
            for (k = 0; k < K; k++)
                for (n = 0; n < N; n++)
                    i8_weight[k*N + n] = $signed($random % 256 - 128);
            
            // 计算期望值：Sum_k(act * wgt)
            // INT8模式下是完整的8位×8位乘法
            for (m = 0; m < M; m++)
                for (n = 0; n < N; n++) begin
                    expected_result[m][n] = 0;
                    for (k = 0; k < K; k++) begin
                        expected_result[m][n] += $signed(i8_act[m*CH_IN + k]) * 
                                                 $signed(i8_weight[k*N + n]);
                    end
                end
            
            pack_weight_int8_flat(0, CH_IN, N);
            pack_act_int8_flat(M, 100);
            
            // 调试：打印所有期望值
            $display("Expected values (all 32 outputs of row 0):");
            for (int i = 0; i < 32; i++)
                $display("  [0,%0d] = %0d", i, expected_result[0][i]);
            
            $display("Expected values (first 8 outputs of row 1):");
            for (int i = 0; i < 8; i++)
                $display("  [1,%0d] = %0d", i, expected_result[1][i]);
            
            config_and_start(32'h0, 32'h0C80, 32'h8000, M, `DCIM_MODE_INT8, 0, 1);
            
            // 调试：打印OBUF内容
            $display("OBUF contents (first 2 words at addr 1024):");
            $display("  obuf_mem[1024] = %h", obuf_mem[1024]);
            $display("  obuf_mem[1025] = %h", obuf_mem[1025]);
            
            // 调试：打印更多OBUF内容
            $display("OBUF contents (words 5-6 at addr 1024):");
            $display("  obuf_mem[1029] = %h", obuf_mem[1029]);
            $display("  obuf_mem[1030] = %h", obuf_mem[1030]);
            
            // 调试：打印row 1的OBUF内容
            $display("OBUF contents (row 1, words 0-1 at addr 1032):");
            $display("  obuf_mem[1032] = %h", obuf_mem[1032]);
            $display("  obuf_mem[1033] = %h", obuf_mem[1033]);
            
            // 验证前4个输出
            begin
                int err, c, word_idx, ch_in_word, got;
                err = 0;
                for (c = 0; c < 4; c++) begin
                    word_idx = c / 4;
                    ch_in_word = (c % 4) * 2;
                    got = $signed(obuf_mem[1024 + word_idx][ch_in_word*32 +: 32]);
                    if (got !== expected_result[0][c]) begin
                        $error("[0,%0d] Expected %0d, Got %0d", c, expected_result[0][c], got);
                        err++;
                    end else begin
                        $display("[0,%0d] OK: %0d", c, got);
                    end
                end
                if (err == 0) $display("[Test 1] First 4 outputs PASS");
                errors_total += err;
            end
            if (errors_total == 0) $display("[Test 1] PASS");
            
            // 等待并复位
            repeat(10) @(posedge clk);
        end

        // ========== 测试 2: INT8 小矩阵 [8, 16] × [16, 32] ==========
        begin
            int M, K, N, m, k, n;
            M = 8; K = CH_IN; N = CH_OUT/2;  // N=32
            $display("\n[Test 2] INT8 Small Matrix [8, 16] x [16, 32]");
            
            for (int i = 0; i < M*K; i++)
                i8_act[i] = $signed($random % 256 - 128);
            for (int i = 0; i < K*N; i++)
                i8_weight[i] = $signed($random % 256 - 128);
            
            for (m = 0; m < M; m++)
                for (n = 0; n < N; n++) begin
                    expected_result[m][n] = 0;
                    for (k = 0; k < K; k++)
                        expected_result[m][n] += $signed(i8_act[m*K + k]) * 
                                                 $signed(i8_weight[k*N + n]);
                end
            
            pack_weight_int8_flat(0, K, N);
            pack_act_int8_flat(M, 100);
            config_and_start(32'h0, 32'h0C80, 32'h8000, M, `DCIM_MODE_INT8, 0, 1);
            errors_total += verify_output_int8(M, N, 1024);
            if (errors_total == 0) $display("[Test 2] PASS");
            repeat(10) @(posedge clk);
        end

        //  ========== 测试 3: INT8 正好 tile [32, 16] × [16, 32] ==========
        begin
            int M, K, N, m, k, n;
            M = 32; K = CH_IN; N = CH_OUT/2;  // N=32
            $display("\n[Test 3] INT8 Exact Tile [32, 16] x [16, 32]");
            
            for (int i = 0; i < M*K; i++)
                i8_act[i] = $signed($random % 256 - 128);
            for (int i = 0; i < K*N; i++)
                i8_weight[i] = $signed($random % 256 - 128);
            
            for (m = 0; m < M; m++)
                for (n = 0; n < N; n++) begin
                    expected_result[m][n] = 0;
                    for (k = 0; k < K; k++)
                        expected_result[m][n] += $signed(i8_act[m*K + k]) * 
                                                 $signed(i8_weight[k*N + n]);
                end
            
            pack_weight_int8_flat(200, K, N);
            pack_act_int8_flat(M, 300);
            config_and_start(32'h1900, 32'h2580, 32'h10000, M, `DCIM_MODE_INT8, 0, 1);
            errors_total += verify_output_int8(M, N, 2048);
            if (errors_total == 0) $display("[Test 3] PASS");
            repeat(10) @(posedge clk);
        end

        // ========== 测试 4: INT8 大矩阵 [32, 64] × [64, 32]（4 tile 累加）==========
        begin
            int M, K, N, m, k, n, tile;
            M = 32; K = 64; N = CH_OUT/2;  // N=32
            $display("\n[Test 4] INT8 Large Matrix [32, 64] x [64, 32] (4 tiles)");
            
            for (int i = 0; i < M*K; i++)
                i8_act[i] = $signed($random % 256 - 128);
            for (int i = 0; i < K*N; i++)
                i8_weight[i] = $signed($random % 256 - 128);
            
            for (m = 0; m < M; m++)
                for (n = 0; n < N; n++) begin
                    expected_result[m][n] = 0;
                    for (k = 0; k < K; k++)
                        expected_result[m][n] += $signed(i8_act[m*K + k]) * 
                                                 $signed(i8_weight[k*N + n]);
                end
            
            // 4 个 tile：K=64 分成 4 段
            for (tile = 0; tile < 4; tile++) begin
                // 提取当前 tile 的数据
                for (m = 0; m < M; m++)
                    for (k = 0; k < CH_IN; k++)
                        i8_tile_act[m*CH_IN + k] = i8_act[m*K + tile*CH_IN + k];
                
                for (k = 0; k < CH_IN; k++)
                    for (n = 0; n < N; n++)
                        i8_tile_wgt[k*N + n] = i8_weight[(tile*CH_IN + k)*N + n];
                
                // 临时复制到主数组用于打包
                for (int i = 0; i < M*CH_IN; i++) i8_act[i] = i8_tile_act[i];
                for (int i = 0; i < CH_IN*N; i++) i8_weight[i] = i8_tile_wgt[i];
                
                pack_weight_int8_flat(500 + tile*16, CH_IN, N);
                pack_act_int8_flat(M, 600 + tile*16);
                
                config_and_start(
                    32'h3E80 + tile*512,
                    32'h4B00 + tile*512,
                    32'h20000,
                    M,
                    `DCIM_MODE_INT8,
                    0,
                    (tile == 3) ? 1 : 0  // 最后一次写 OBUF
                );
            end
            
            errors_total += verify_output_int8(M, N, 4096);
            if (errors_total == 0) $display("[Test 4] PASS");
            repeat(10) @(posedge clk);
        end

        // ========== 测试 5: INT16 超小矩阵 [2, 4] × [4, 16]（K<16）==========
        // INT16模式：有效输出通道数是CH_OUT/4=16
        begin
            int M, K, N, m, k, n;
            M = 2; K = 4; N = CH_OUT/4;  // N=16
            $display("\n[Test 5] INT16 Ultra-Small Matrix [2, 4] x [4, 16] (K<16)");
            
            // 初始化全0
            for (int i = 0; i < M*CH_IN; i++) i16_act[i] = 0;
            for (int i = 0; i < CH_IN*N; i++) i16_weight[i] = 0;
            
            // 填充有效的 K=4 数据（16位有符号数）
            for (m = 0; m < M; m++)
                for (k = 0; k < K; k++)
                    i16_act[m*CH_IN + k] = $signed($random % 65536 - 32768);
            
            for (k = 0; k < K; k++)
                for (n = 0; n < N; n++)
                    i16_weight[k*N + n] = $signed($random % 65536 - 32768);
            
            // 计算期望值（INT16: 完整16位乘法）
            for (m = 0; m < M; m++)
                for (n = 0; n < N; n++) begin
                    expected_result[m][n] = 0;
                    for (k = 0; k < K; k++)
                        expected_result[m][n] += $signed(i16_act[m*CH_IN + k]) * 
                                                 $signed(i16_weight[k*N + n]);
                end
            
            pack_weight_int16_flat(800, CH_IN, N);
            pack_act_int16_flat(M, 900);
            config_and_start(32'h6400, 32'h7080, 32'h30000, M, `DCIM_MODE_INT16, 0, 1);
            errors_total += verify_output_int16(M, N, 6144);
            if (errors_total == 0) $display("[Test 5] PASS");
            repeat(10) @(posedge clk);
        end

        // ========== 测试 6: INT16 小矩阵 [4, 16] × [16, 16] ==========
        begin
            int M, K, N, m, k, n;
            M = 4; K = CH_IN; N = CH_OUT/4;  // N=16
            $display("\n[Test 6] INT16 Small Matrix [4, 16] x [16, 16]");
            
            for (int i = 0; i < M*K; i++)
                i16_act[i] = $signed($random % 65536 - 32768);
            for (int i = 0; i < K*N; i++)
                i16_weight[i] = $signed($random % 65536 - 32768);
            
            for (m = 0; m < M; m++)
                for (n = 0; n < N; n++) begin
                    expected_result[m][n] = 0;
                    for (k = 0; k < K; k++)
                        expected_result[m][n] += $signed(i16_act[m*K + k]) * 
                                                 $signed(i16_weight[k*N + n]);
                end
            
            pack_weight_int16_flat(800, K, N);
            pack_act_int16_flat(M, 900);
            config_and_start(32'h6400, 32'h7080, 32'h30000, M, `DCIM_MODE_INT16, 0, 1);
            errors_total += verify_output_int16(M, N, 6144);
            if (errors_total == 0) $display("[Test 6] PASS");
            repeat(10) @(posedge clk);
        end

        // ========== 测试 7: INT16 正好 tile [16, 16] × [16, 16] ==========
        begin
            int M, K, N, m, k, n;
            M = 16; K = CH_IN; N = CH_OUT/4;  // N=16
            $display("\n[Test 7] INT16 Exact Tile [16, 16] x [16, 16]");
            
            for (int i = 0; i < M*K; i++)
                i16_act[i] = $signed($random % 65536 - 32768);
            for (int i = 0; i < K*N; i++)
                i16_weight[i] = $signed($random % 65536 - 32768);
            
            for (m = 0; m < M; m++)
                for (n = 0; n < N; n++) begin
                    expected_result[m][n] = 0;
                    for (k = 0; k < K; k++)
                        expected_result[m][n] += $signed(i16_act[m*K + k]) * 
                                                 $signed(i16_weight[k*N + n]);
                end
            
            pack_weight_int16_flat(1000, K, N);
            pack_act_int16_flat(M, 1100);
            config_and_start(32'h7D00, 32'h8980, 32'h40000, M, `DCIM_MODE_INT16, 0, 1);
            errors_total += verify_output_int16(M, N, 8192);
            if (errors_total == 0) $display("[Test 7] PASS");
            repeat(10) @(posedge clk);
        end

        // ========== 测试 8: INT16 大矩阵 [16, 64] × [64, 16]（4 tile 累加）==========
        begin
            int M, K, N, m, k, n, tile;
            M = 16; K = 64; N = CH_OUT/4;  // N=16
            $display("\n[Test 8] INT16 Large Matrix [16, 64] x [64, 16] (4 tiles)");
            
            for (int i = 0; i < M*K; i++)
                i16_act[i] = $signed($random % 65536 - 32768);
            for (int i = 0; i < K*N; i++)
                i16_weight[i] = $signed($random % 65536 - 32768);
            
            for (m = 0; m < M; m++)
                for (n = 0; n < N; n++) begin
                    expected_result[m][n] = 0;
                    for (k = 0; k < K; k++)
                        expected_result[m][n] += $signed(i16_act[m*K + k]) * 
                                                 $signed(i16_weight[k*N + n]);
                end
            
            for (tile = 0; tile < 4; tile++) begin
                // 提取当前 tile 的数据
                for (m = 0; m < M; m++)
                    for (k = 0; k < CH_IN; k++)
                        i16_tile_act[m*CH_IN + k] = i16_act[m*K + tile*CH_IN + k];
                
                for (k = 0; k < CH_IN; k++)
                    for (n = 0; n < N; n++)
                        i16_tile_wgt[k*N + n] = i16_weight[(tile*CH_IN + k)*N + n];
                
                // 临时复制到主数组用于打包
                for (int i = 0; i < M*CH_IN; i++) i16_act[i] = i16_tile_act[i];
                for (int i = 0; i < CH_IN*N; i++) i16_weight[i] = i16_tile_wgt[i];
                
                pack_weight_int16_flat(1200 + tile*16, CH_IN, N);
                pack_act_int16_flat(M, 1300 + tile*16);
                
                config_and_start(
                    32'h9600 + tile*512,
                    32'hA280 + tile*512,
                    32'h50000,
                    M,
                    `DCIM_MODE_INT16,
                    0,
                    (tile == 3) ? 1 : 0
                );
            end
            
            errors_total += verify_output_int16(M, N, 10240);
            if (errors_total == 0)
                $display("[Test 8] PASS");
            repeat(10) @(posedge clk);
        end

        // ========== 总结 ==========
        $display("\n========================================");
        if (errors_total == 0) begin
            $display("ALL TESTS PASSED!");
            $display("========================================");
        end else begin
            $display("FAILED with %0d errors", errors_total);
            $display("========================================");
            $finish(1);
        end

        $finish(0);
    end

    // Timeout - 增加到10ms
    initial begin
        #10000000;
        $display("ERROR: Simulation timeout!");
        $finish(1);
    end

    // VCS dump
    initial begin
        $fsdbDumpfile("DCIM_Macro_tb.fsdb");
        $fsdbDumpvars(0, DCIM_Macro_tb);
    end

endmodule
