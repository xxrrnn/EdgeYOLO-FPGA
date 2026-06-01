# DCIM Tile/Array 低层调试测试 Makefile（路径: rtl/chip/tb/Makefile）
#
# 后续主测试入口已切换到 rtl/tb/lite_bd/module_tb：它覆盖完整 lite BD、
# INST_Decoder、CDMA/VPU/DCIM 和 OBUF 检查，适合作为数值级别等同依据。
# 本目录仅保留为 DCIM_Tile/DCIM_Array 的低层 smoke/debug。
# 当前 DCIM RTL 主线只有两层：DCIM_Tile 和 DCIM_Array。Group 层已退出主 flow。
# 当前 chip_defines.vh 配置：NUM_TILES=4，单 Tile 为 CH_IN=64、CH_OUT=64、CYCLE=128。
# INT8 每 Tile 输出 CH_OUT/2=32 个逻辑通道，4 Tile @250MHz 理论峰值 2.048 TOPS。
#
# 本目录测试目标是“数值级别等同”：RTL 输出逐 128-bit word 对齐 golden/预期值，
# 不再验证旧 Group 拓扑。

CHIP_DIR = ..
BUILD_DIR = $(CHIP_DIR)/build
REF_DIR = $(CHIP_DIR)/../ref/DCIM

VCS = vcs
VCS_FLAGS = -sverilog -full64 -debug_access+all -timescale=1ns/1ps
VCS_FLAGS += +incdir+$(REF_DIR)/src/inc
VCS_FLAGS += +incdir+$(REF_DIR)/src/dcim
VCS_FLAGS += +incdir+$(CHIP_DIR)
VCS_FLAGS += -ignore initializer_driver_checks
VCS_FLAGS += -kdb -lca

FSDB_FLAGS = +fsdb+autoflush

.PHONY: all help clean \
        compile_smoke sim_smoke test_smoke \
        compile_array sim_array test_array \
        compile sim test \
        compile_tile sim_tile test_tile \
        test_all fsdb verdi

all: test_smoke

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

help:
	@echo "DCIM Tile/Array 低层 smoke/debug（无 Group flow）"
	@echo "主测试请使用：cd rtl/tb/lite_bd/module_tb && make sim 或 make rebuild-suite"
	@echo ""
	@echo "主线命令："
	@echo "  make test_smoke   # 推荐：4 Tile × 64×64 DCIM_Array 数值 smoke"
	@echo "  make test_array   # test_smoke 的别名"
	@echo "  make test         # test_smoke 的别名"
	@echo "  make fsdb         # 带 FSDB 跑 array smoke"
	@echo "  make verdi        # 打开 array smoke 波形"
	@echo ""
	@echo "开发命令："
	@echo "  make compile_smoke / sim_smoke"
	@echo "  make compile_tile  / sim_tile   # DCIM_Tile 单体 TB；需保持与 chip_defines.vh 参数同步"
	@echo "  make clean"
	@echo ""
	@echo "说明：Group 层已退出主 flow，本 Makefile 不再提供 group target。"

# -----------------------------------------------------------------------------
# Array 数值 smoke：使用 chip_defines.vh 当前参数，验证 4 Tile × 64×64 INT8
# 权重全 1、激活全 1 时，每个逻辑输出通道期望累加值为 CH_IN=64。
# -----------------------------------------------------------------------------
compile_smoke: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) +define+SIM \
		-f ../filelist.f \
		../tb/tb_DCIM_Array_64_smoke.sv \
		-o simv_smoke

sim_smoke: compile_smoke
	cd $(BUILD_DIR) && chmod +x simv_smoke && ./simv_smoke

test_smoke: sim_smoke

compile_array: compile_smoke
sim_array: sim_smoke
test_array: test_smoke

compile: compile_smoke
sim: sim_smoke
test: test_smoke

# -----------------------------------------------------------------------------
# Tile 单体 TB：保留为底层调试入口。若 chip_defines.vh 修改 CH_IN/CH_OUT/CYCLE，
# 该 TB 的 golden/检查也必须同步参数化，避免只验证旧 16×16 行为。
# -----------------------------------------------------------------------------
compile_tile: $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VCS) $(VCS_FLAGS) +define+SIM \
		-f ../filelist.f \
		../tb/tb_DCIM_Tile.sv \
		-o simv_tile

sim_tile: compile_tile
	cd $(BUILD_DIR) && chmod +x simv_tile && ./simv_tile

test_tile: sim_tile

# 默认全量只跑当前已参数化的 Array smoke；Tile TB 参数化完成后再加入。
test_all: test_smoke

fsdb: compile_smoke
	cd $(BUILD_DIR) && chmod +x simv_smoke && ./simv_smoke $(FSDB_FLAGS) +fsdbfile+dcim_array_64_smoke.fsdb

verdi:
	cd $(BUILD_DIR) && verdi -dbdir simv_smoke.daidir -ssf dcim_array_64_smoke.fsdb &

clean:
	rm -rf $(BUILD_DIR) $(CHIP_DIR)/csrc $(CHIP_DIR)/*.daidir $(CHIP_DIR)/*.log $(CHIP_DIR)/*.key $(CHIP_DIR)/*.vpd $(CHIP_DIR)/DVEfiles
	rm -rf csrc *.daidir *.log *.key *.vpd DVEfiles
