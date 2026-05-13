#####################################################################################
# Description:  Innovus Add Pin Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
#set bottompinlist [dbget top.terms.name]
#editPin -fixOverlap 1 -spreadDirection clockwise -edge 3 -layer 6 -spreadType center -spacing 12  -pin $bottompinlist
# editPin -use CLOCK -fixOverlap 1 -unit MICRON -spreadDirection clockwise -edge 2 -layer 5 -spreadType center -spacing 0.1 -pin clk
#setPinAssignMode -pinEditInBatch false

##################IO_TOP################################
#set bottomPinList0 [list EN {CC_SEL[5]} {CC_SEL[4]} {CC_SEL[3]} {CC_SEL[2]} {CC_SEL[1]} {CC_SEL[0]}]
#editPin -fixOverlap 1 -spreadDirection clockwise -edge 3 -layer 4 -spreadType center -spacing 1.5  -pin $bottomPinList0

#set topPinList0 [list {FC_SEL[5]} {FC_SEL[4]} {FC_SEL[3]} {FC_SEL[2]} {FC_SEL[1]} {FC_SEL[0]} EXT_CLK]
#editPin -fixOverlap 1 -spreadDirection clockwise -edge 1 -layer 4 -spreadType center -spacing 1.5  -pin $topPinList0

#set rightPinList0 [list CLK CLK_DIV ]
#editPin -fixOverlap 1 -spreadDirection clockwise -edge 2 -layer 3 -spreadType center -spacing 8  -pin $rightPinList0

#set leftPinList0 [list {DIV_SEL[1]} {DIV_SEL[0]} {FREQ_SEL[1]} {FREQ_SEL[0]} RSTN CLK_SEL]
#editPin -fixOverlap 1 -spreadDirection clockwise -edge 0 -layer 3 -spreadType center -spacing 1.5  -pin $leftPinList0

editPin -pinWidth 0.05 -pinDepth 0.34 -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Left -layer 5 -spreadType center -spacing 10 -pin {{dco_cc_sel[0]} {dco_cc_sel[1]} {dco_cc_sel[2]} {dco_cc_sel[3]} {dco_cc_sel[4]} {dco_cc_sel[5]} dco_clk_div dco_clk_sel {dco_div_sel[0]} {dco_div_sel[1]} dco_en dco_ext_clk {dco_fc_sel[0]} {dco_fc_sel[1]} {dco_fc_sel[2]} {dco_fc_sel[3]} {dco_fc_sel[4]} {dco_fc_sel[5]} {dco_freq_sel[0]} {dco_freq_sel[1]}}

editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -edge 1 -layer 4 -spreadType start -spacing 6 -offsetStart 15 -pin {{irq[0]} {irq[1]} {irq[2]} {irq[3]} {irq[4]} {irq[5]} {irq[6]} {irq[7]} {irq[8]} {irq[9]} {irq[10]} {irq[11]} {irq[12]} {irq[13]} {irq[14]} {irq[15]} {irq[16]} {irq[17]} {irq[18]} {irq[19]} {irq[20]} {irq[21]} {irq[22]} {irq[23]} {irq[24]} {irq[25]} {irq[26]} {irq[27]} {irq[28]} {irq[29]} {irq[30]} {irq[31]}}


editPin -pinWidth 0.05 -pinDepth 0.34 -fixOverlap 1 -unit MICRON -spreadDirection counterclockwise -edge 3 -layer 4 -spreadType start -spacing 30.0 -offsetStart 30 -pin {sys_rstn trap}

setPinAssignMode -pinEditInBatch false
