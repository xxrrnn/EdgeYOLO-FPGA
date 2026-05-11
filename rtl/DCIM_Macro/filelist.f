// DCIM_Macro 文件列表

// 参数定义
../../ref/DCIM/src/inc/para.v

// DCIM 核心模块
../../ref/DCIM/src/dcim/dcim.v
../../ref/DCIM/src/dcim/memory.v
../../ref/DCIM/src/dcim/ppCache.v
../../ref/DCIM/src/dcim/calculate_core.v
../../ref/DCIM/src/dcim/maArray.v
../../ref/DCIM/src/dcim/multiplier.v
../../ref/DCIM/src/dcim/adderTree.v
../../ref/DCIM/src/dcim/postProcess.v
../../ref/DCIM/src/dcim/mergeArray.v
../../ref/DCIM/src/dcim/accumulateArray.v
../../ref/DCIM/src/dcim/sramWrap.v

// SRAM 模型（+define+SIM 与 +define+FPGA 均走 sramWrap → model_rf_bram；model_rf 保留供其它 bench）
../../ref/DCIM/src/model/model_rf.sv
../../ref/DCIM/src/model/model_rf_bram.sv

// 激活预处理
../../ref/DCIM/src/dcim/act_nibble_converter.sv

// BRAM 缓冲
../ibuf.v
../obuf.v

// 顶层模块
../DCIM_Macro.sv
