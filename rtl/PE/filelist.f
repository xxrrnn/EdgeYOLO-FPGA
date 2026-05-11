// ============================================================================
// PE Array RTL 文件列表
// ============================================================================

// 参数定义
+incdir+../ref/DCIM/src/inc

// DCIM 核心模块（来自 ref）
../ref/DCIM/src/dcim/dcim.v
../ref/DCIM/src/dcim/memory.v
../ref/DCIM/src/dcim/sramWrap.v
../ref/DCIM/src/dcim/postProcess.v
../ref/DCIM/src/dcim/ppCache.v
../ref/DCIM/src/dcim/calculate_core.v
../ref/DCIM/src/dcim/maArray.v
../ref/DCIM/src/dcim/multiplier.v
../ref/DCIM/src/dcim/adderTree.v
../ref/DCIM/src/dcim/accumulateArray.v
../ref/DCIM/src/dcim/mergeArray.v
../ref/DCIM/src/model/model_rf_bram.sv

// 激活预处理器
../ref/DCIM/src/dcim/act_nibble_converter.sv

// BRAM 模块（来自 DCIM_Macro）
../DCIM_Macro/ibuf.v
../DCIM_Macro/obuf.v

// PE Array 模块
./OBUF_Arbiter.sv
./DCIM_Tile.sv
./PE_Array.sv
./AXI_Lite_Regs.sv
./GEMM_Top.sv
