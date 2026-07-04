#####################################################################################
# Description:  Innovus Fix DRC Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################

# clear route blockage for DRC verification
deleteRouteBlk -all

# routeWithEco: route in engineering change order (ECO) mode if `globalDetailRoute` is specified, default: false
setNanoRouteMode -routeWithEco true

# use the NanoRoute router to perform both global and detailed routing
globalDetailRoute

# check for DRC violations and create violation markers 
verify_drc -limit 99999 -report ../${rm_core_top}/reports/postRoute/verify_drc.rpt
