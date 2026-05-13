#####################################################################################
# Description:  Innovus Routing Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################

# set the native RC extraction mode
# engine:               possible value: preRoute | postRoute, default: preRoute
# effortLevel:          possible value: low | medium | high | signoff, default: low
setExtractRCMode    -engine                 postRoute \
                    -effortLevel            medium

# run routing or postroute via or wire optimization using the NanoRoute router
# if specified without any arguments, it runs global and detail routing
routeDesign

# optimize setup, hold and drv
optDesign -outDir ../${rm_core_top}/reports/postRoute -postRoute -setup -hold
optDesign -outDir ../${rm_core_top}/reports/postRoute -postRoute -drv
optDesign -outDir ../${rm_core_top}/reports/postRoute -postRoute -incr
optDesign -outDir ../${rm_core_top}/reports/postRoute -postRoute -hold
exec ../scripts/extract_report.csh ../${rm_core_top}/reports/postRoute

