#!/bin/bash
# VPU测试快捷脚本

cd "$(dirname "$0")/examples"
PYTHONPATH=.. python test_vpu_ops_example.py "$@"
