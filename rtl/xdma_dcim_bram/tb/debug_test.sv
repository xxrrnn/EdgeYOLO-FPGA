`timescale 1ns/1ps
`include "../dcim_defs.vh"

module debug_test;
    localparam CLK_PERIOD = 10;
    localparam CH_IN = `DCIM_CH_IN;
    localparam CH_OUT = `DCIM_CH_OUT;
    localparam IBUF_DEPTH = 8192;
    localparam OBUF_DEPTH = 8192;
    
    logic clk, rst_n;
    logic dcim_start, dcim_done;
    logic dcim_config_valid, dcim_config_ready;
    logic [31:0] wsrc_base_addr, asrc_base_addr, dst_addr, raw_rows;
    logic [2:0] mode;
    logic [4:0] acc;
    logic save_to_obuf;
    
    // BRAM
    var logic [255:0] ibuf_mem[IBUF_DEPTH] = '{default: '0};
    var logic [255:0] obuf_mem[OBUF_DEPTH] = '{default: '0};
    logic ibuf_enb;
    logic [`DCIM_IBUF_ADDR_WIDTH-1:0] ibuf_addrb;
    logic [255:0] ibuf_doutb;
    logic obuf_enb;
    logic [31:0] obuf_web;
    logic [`DCIM_OBUF_ADDR_WIDTH-1:0] obuf_addrb;
    logic [255:0] obuf_dinb;
    logic [CH_OUT*32-1:0] psum_out;
    
    // 时钟
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // IBUF读
    always_ff @(posedge clk) begin
        if (ibuf_enb) ibuf_doutb <= ibuf_mem[ibuf_addrb];
    end
    
    // OBUF写
    always_ff @(posedge clk) begin
        if (obuf_enb && (&obuf_web)) obuf_mem[obuf_addrb] <= obuf_dinb;
    end
    
    // DUT
    DCIM_Macro dut (
        .clk(clk), .rst_n(rst_n),
        .dcim_start(dcim_start), .dcim_done(dcim_done),
        .dcim_config_valid(dcim_config_valid),
        .dcim_config_ready(dcim_config_ready),
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
    
    initial begin
        $display("Debug Test: INT8 [2,16]x[16,64] - verify output format");
        
        // 使用简单的已知值来验证输出格式
        // 激活：每个输入通道ch的值 = 1
        // 权重：每个(ch,n)的值 = 1
        // 
        // 对于INT8，每个8位权重被拆成两个4位nibble：
        // - 低nibble给偶数输出通道
        // - 高nibble给奇数输出通道
        // 
        // 如果权重=0x01，则低nibble=1，高nibble=0
        // 如果激活=0x01，则低nibble=1，高nibble=0
        // 
        // 合并后的结果 = (act_high * wgt_high) * 256 + (act_high * wgt_low + act_low * wgt_high) * 16 + (act_low * wgt_low)
        //              = 0 * 256 + (0 + 0) * 16 + 1 * 1 = 1
        // 16个输入通道累加 = 16
        
        // 权重: 每个字节=0x01
        for (int i = 0; i < 16; i++)
            ibuf_mem[i] = {32{8'h01}};
        
        // 激活: 每个字节=0x01
        ibuf_mem[100] = {{16{8'h01}}, {16{8'h01}}};
        
        rst_n = 0;
        dcim_start = 0;
        dcim_config_valid = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // 配置
        @(posedge clk);
        dcim_config_valid = 1;
        wsrc_base_addr = 0;
        asrc_base_addr = 100 * 32;  // 字地址*32
        dst_addr = 1000 * 32;
        raw_rows = 2;
        mode = `DCIM_MODE_INT8;
        acc = 0;
        save_to_obuf = 1;
        
        wait(dcim_config_ready);
        @(posedge clk);
        dcim_config_valid = 0;
        
        // 启动
        dcim_start = 1;
        @(posedge clk);
        dcim_start = 0;
        
        // 等待完成
        fork
            begin
                wait(dcim_done);
                $display("Done at %0t", $time);
            end
            begin
                #100000;
                $display("TIMEOUT!");
                $finish(1);
            end
        join_any
        disable fork;
        
        // 检查输出 - 打印原始数据以理解格式
        begin
            int r, word_idx, c, ch_in_word, got;
            $display("Raw OBUF contents:");
            for (r = 0; r < 2; r++) begin
                for (word_idx = 0; word_idx < 8; word_idx++) begin
                    $display("  Row %0d, Word %0d: %h", r, word_idx, obuf_mem[1000 + r*8 + word_idx]);
                end
            end
            
            // 按32位解析
            $display("\nParsed as 32-bit values (first 16 of row 0):");
            for (c = 0; c < 16; c++) begin
                word_idx = c / 8;
                ch_in_word = c % 8;
                got = $signed(obuf_mem[1000 + word_idx][ch_in_word*32 +: 32]);
                $display("  [0,%0d]: %0d (0x%h)", c, got, obuf_mem[1000 + word_idx][ch_in_word*32 +: 32]);
            end
        end
        
        $display("PASS!");
        $finish(0);
    end
endmodule
