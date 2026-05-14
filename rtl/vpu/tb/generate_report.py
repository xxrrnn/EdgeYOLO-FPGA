#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成测试报告
"""

import os
import sys
from datetime import datetime

def parse_log_file(log_file):
    """解析日志文件"""
    if not os.path.exists(log_file):
        return None
    
    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # 检查是否通过
    if 'PASS' in content and 'FAIL' not in content:
        return 'PASS'
    elif 'FAIL' in content or 'ERROR' in content or 'error' in content.lower():
        return 'FAIL'
    else:
        return 'UNKNOWN'

def generate_report():
    """生成测试报告"""
    
    print("\n" + "="*60)
    print("VPU RTL 测试报告")
    print("="*60)
    print(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60 + "\n")
    
    # 测试项目
    tests = [
        ('时序优化测试', 'tb_all_units_timing'),
        ('QA Unit 测试', 'tb_qa_unit'),
        ('DQA Unit 测试', 'tb_dqa_unit'),
        ('AD Unit 测试', 'tb_ad_unit'),
        ('US Unit 测试', 'tb_us_unit'),
        ('MP Unit 测试', 'tb_mp_unit'),
    ]
    
    results = []
    total_tests = 0
    passed_tests = 0
    
    for test_name, test_id in tests:
        total_tests += 1
        log_file = f'{test_id}.log'
        
        # 检查日志
        result = parse_log_file(log_file)
        
        if result == 'PASS':
            status = '✓ 通过'
            passed_tests += 1
        elif result == 'FAIL':
            status = '✗ 失败'
        else:
            status = '? 未运行'
        
        results.append((test_name, status))
        print(f"{test_name:.<40} {status}")
    
    print("\n" + "-"*60)
    print(f"总计: {total_tests} 个测试")
    print(f"通过: {passed_tests} 个")
    print(f"失败: {total_tests - passed_tests} 个")
    
    if passed_tests == total_tests:
        print("\n" + "="*60)
        print("✓ 所有测试通过！硬件功能验证成功！")
        print("="*60 + "\n")
    else:
        print("\n" + "="*60)
        print("✗ 部分测试失败，请检查日志")
        print("="*60 + "\n")
    
    # 写入报告文件
    with open('test_report.txt', 'w', encoding='utf-8') as f:
        f.write("="*60 + "\n")
        f.write("VPU RTL 测试报告\n")
        f.write("="*60 + "\n")
        f.write(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("="*60 + "\n\n")
        
        for test_name, status in results:
            f.write(f"{test_name:.<40} {status}\n")
        
        f.write("\n" + "-"*60 + "\n")
        f.write(f"总计: {total_tests} 个测试\n")
        f.write(f"通过: {passed_tests} 个\n")
        f.write(f"失败: {total_tests - passed_tests} 个\n")
    
    print("报告已保存到 test_report.txt")

if __name__ == '__main__':
    generate_report()
