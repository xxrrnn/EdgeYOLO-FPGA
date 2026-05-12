# DCIM_Tile filelist

# 参数定义
../../ref/DCIM/src/inc/para.v
../../ref/DCIM/src/inc/counter.v
../../ref/DCIM/src/inc/dff.v
../../ref/DCIM/src/inc/pipe_stage.v

# DCIM 核心
../../ref/DCIM/src/dcim/multiplier.v
../../ref/DCIM/src/dcim/adderTree.v
../../ref/DCIM/src/dcim/calculate_core.v
../../ref/DCIM/src/dcim/sramWrap.v
../../ref/DCIM/src/dcim/memory.v
../../ref/DCIM/src/dcim/dcim.v
../../ref/DCIM/src/dcim/maArray.v
../../ref/DCIM/src/dcim/mergeArray.v
../../ref/DCIM/src/dcim/accumulateArray.v
../../ref/DCIM/src/dcim/ppCache.v

# SRAM 模型
../../ref/DCIM/src/model/model_rf.sv
../../ref/DCIM/src/model/model_rf_bram.sv

# 后处理
../../ref/DCIM/src/dcim/postProcess.v

# 激活转换
../../ref/DCIM/src/dcim/act_nibble_converter.sv

# DCIM_Tile 模块
../DCIM_Tile.sv

# IBUF/OBUF (用于 testbench)
../../DCIM_Macro/ibuf.v
../../DCIM_Macro/obuf.v
