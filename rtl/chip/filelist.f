# DCIM_Array filelist

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
../../ref/DCIM/src/dcim/postProcess.v
../../ref/DCIM/src/dcim/act_nibble_converter.sv

# SRAM 模型
../../ref/DCIM/src/model/model_rf.sv
../../ref/DCIM/src/model/model_rf_bram.sv

# IBUF/OBUF
../../DCIM_Macro/ibuf.v
../../DCIM_Macro/obuf.v

# DCIM_Tile 及 Array
../DCIM_Tile.sv
../ibuf_rd_arbiter.sv
../obuf_wr_arbiter.sv
../DCIM_Array.sv
