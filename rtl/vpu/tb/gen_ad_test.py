#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 AD Unit 的测试向量和测试文件
"""

import numpy as np
import random

def generate_test_vectors():
    """生成测试向量"""
    test_cases = []
    
    # 测试用例 1: 小规模
    test_cases.append({
        'name': 'small',
        'c': 8,
        'h': 4,
        'w': 4,
        'description': '小规模测试'
    })
    
    # 测试用例 2: 中等规模
    test_cases.append({
        'name': 'medium',
        'c': 32,
        'h': 8,
        'w': 8,
        'description': '中等规模测试'
    })
    
    # 测试用例 3: 较大规模
    test_cases.append({
        'name': 'large',
        'c': 64,
        'h': 16,
        'w': 16,
        'description': '较大规模测试'
    })
    
    return test_cases

def generate_testbench(test_cases):
    """生成测试台文件"""
    
    tb_content = """`timescale 1ns/1ps

//==============================================================================
// tb_ad_unit: AD Unit 功能测试
// 自动生成的测试文件
//==============================================================================

module tb_ad_unit;

    parameter ADDR_WIDTH = 32;
    parameter GB_BANDWIDTH = 256;
    parameter GB_ADDR_WIDTH = 16;
    parameter FP_CORE_NUM = 256;
    parameter FP_WIDTH = 32;
    
    reg clk;
    reg rst_n;
    reg ad_unit_start;
    wire ad_unit_ready;
    
    reg [ADDR_WIDTH-1:0] ad_src_addr;
    reg [ADDR_WIDTH-1:0] ad_src2_addr;
    reg [ADDR_WIDTH-1:0] ad_src_c;
    reg [ADDR_WIDTH-1:0] ad_src_h;
    reg [ADDR_WIDTH-1:0] ad_src_w;
    reg [ADDR_WIDTH-1:0] ad_dst_addr;
    
    wire [GB_ADDR_WIDTH-1:0] gb_addrb;
    wire [GB_BANDWIDTH-1:0] gb_dinb;
    wire [GB_BANDWIDTH/8-1:0] gb_web;
    wire gb_enb;
    reg [GB_BANDWIDTH-1:0] gb_doutb;
    
    // 实例化 DUT
    ad_unit #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_BANDWIDTH(GB_BANDWIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_WIDTH(FP_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ad_unit_start(ad_unit_start),
        .ad_unit_ready(ad_unit_ready),
        .ad_src_addr(ad_src_addr),
        .ad_src2_addr(ad_src2_addr),
        .ad_src_c(ad_src_c),
        .ad_src_h(ad_src_h),
        .ad_src_w(ad_src_w),
        .ad_dst_addr(ad_dst_addr),
        .gb_addrb(gb_addrb),
        .gb_dinb(gb_dinb),
        .gb_web(gb_web),
        .gb_enb(gb_enb),
        .gb_doutb(gb_doutb)
    );
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #2 clk = ~clk;
    end
    
    // 测试任务
    task test_case;
        input [ADDR_WIDTH-1:0] c, h, w;
        input string desc;
        begin
            $display("测试: %s (C=%0d, H=%0d, W=%0d)", desc, c, h, w);
            
            ad_src_addr = 32'h1000_0000;
            ad_src2_addr = 32'h2000_0000;
            ad_dst_addr = 32'h3000_0000;
            ad_src_c = c;
            ad_src_h = h;
            ad_src_w = w;
            
            @(posedge clk);
            ad_unit_start = 1;
            @(posedge clk);
            ad_unit_start = 0;
            
            // 等待完成
            wait(ad_unit_ready);
            @(posedge clk);
            
            $display("  ✓ 测试通过");
        end
    endtask
    
    // 主测试序列
    initial begin
        $display("========================================");
        $display("AD Unit 功能测试");
        $display("========================================\\n");
        
        rst_n = 0;
        ad_unit_start = 0;
        gb_doutb = 0;
        
        #20;
        rst_n = 1;
        #10;
        
"""
    
    # 添加测试用例
    for tc in test_cases:
        tb_content += f"        test_case({tc['c']}, {tc['h']}, {tc['w']}, \"{tc['description']}\");\n"
    
    tb_content += """        
        #100;
        
        $display("\\n========================================");
        $display("所有 AD Unit 测试通过！");
        $display("========================================");
        $finish;
    end
    
    // 超时保护
    initial begin
        #100000;
        $display("错误: 测试超时！");
        $finish;
    end
    
    // GB 接口模拟（简化）
    always @(posedge clk) begin
        if (gb_enb && !gb_web) begin
            // 读操作：返回测试数据
            gb_doutb <= {8{32'h3f800000}}; // 返回 1.0 的浮点表示
        end
    end

endmodule
"""
    
    return tb_content

def main():
    print("生成 AD Unit 测试...")
    
    # 生成测试用例
    test_cases = generate_test_vectors()
    
    # 生成测试台
    tb_content = generate_testbench(test_cases)
    
    # 写入文件
    with open('tb_ad_unit.sv', 'w', encoding='utf-8') as f:
        f.write(tb_content)
    
    print(f"✓ 已生成 tb_ad_unit.sv，包含 {len(test_cases)} 个测试用例")

if __name__ == '__main__':
    main()
