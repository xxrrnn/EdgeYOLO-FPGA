#!/bin/bash
# xsim 仿真脚本 - INST_Decoder CDMA 测试

set -e

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}INST_Decoder CDMA 仿真测试${NC}"
echo -e "${GREEN}========================================${NC}"

# 切换到项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."

# 创建仿真目录
SIM_DIR="sim/inst_decoder_cdma"
mkdir -p "$SIM_DIR"
cd "$SIM_DIR"

echo -e "${YELLOW}清理旧文件...${NC}"
rm -rf xsim.dir *.wdb *.jou *.log *.pb

# RTL 文件列表
RTL_FILES=(
    "../../rtl/vpu/INST_Decoder.sv"
    "../../rtl/vpu/tb_inst_decoder_cdma.v"
)

# 检查文件是否存在
echo -e "${YELLOW}检查 RTL 文件...${NC}"
for file in "${RTL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 文件不存在: $file${NC}"
        exit 1
    fi
    echo "  ✓ $file"
done

# 分析 (xvlog)
echo -e "${YELLOW}分析 RTL 文件...${NC}"
xvlog --sv "${RTL_FILES[@]}" 2>&1 | tee xvlog.log

# 检查分析是否成功
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}✗ RTL 分析失败${NC}"
    exit 1
fi

# 精化 (xelab)
echo -e "${YELLOW}精化设计...${NC}"
xelab -debug typical tb_inst_decoder_cdma -s tb_inst_decoder_cdma_sim 2>&1 | tee xelab.log

# 检查精化是否成功
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}✗ 设计精化失败${NC}"
    exit 1
fi

# 仿真 (xsim)
echo -e "${YELLOW}运行仿真...${NC}"
xsim tb_inst_decoder_cdma_sim -runall 2>&1 | tee xsim.log

# 检查仿真结果
if grep -q "✓ 测试通过" xsim.log; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ 仿真测试通过${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ 仿真测试失败${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
