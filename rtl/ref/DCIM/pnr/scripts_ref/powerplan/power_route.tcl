#####################################################################################
# Description:  Innovus Power Routing Script
# Modifier:	    Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################

verify_drc -limit 99999 -report ../${rm_core_top}/reports/postPowerplan/verify_drc.rpt 
verifyConnectivity -net {VDD VDD_SRAM VDD_DCO VSS} -error 99999 -report ../${rm_core_top}/reports/postPowerplan/verify_connectivity.rpt

# route power structures
# connect:                  connect the specified objects to rings and stripes, possible value: blockPin | corePin | padPin | padRing | floatingStripe | secondaryPowerPin
# nets:                     specify the names of the nets to connect
# layerChangeRange:         allow routing between the specified bottom-most and top-most layer
# crossoverViaLayerRange:   specify the highest and lowest layer that can be used for via stacking at the crossover point between power structures
# targetViaLayerRange:      specify the highest and lowest layer that can be used for via stacking at a target
# allowJogging:             specify that jogs allowed during routing to avoid DRC violations, possible value: 0 | 1
# allowLayerChange:         allow connections to target on different layers, possible value: 0 | 1
# deleteExistingRoutes:     specify that the software remove existing connections when using sroute command multiple times
sroute 	-connect                    { corePin } \
        -nets                       { VDD VSS } \
        -layerChangeRange           { M1 M7 } \
        -crossoverViaLayerRange     { M1 M7 } \
        -targetViaLayerRange        { M1 M7 } \
        -allowJogging               1 \
        -allowLayerChange           1 \
        -checkAlignedSecondaryPin   1 \
        -deleteExistingRoutes

# modify or delete existing power vias or add new power vias, INEFFECTIVE in most cases
# skip_via_on_pin:  prevent vias from being generated on the specified types of pins, possible value: Pad | Block | Cover | Standardcell | Physicalpin
# bottom_layer:     specify the lowest layer to which vias can connect
# top_layer:        specify the highest layer to which vias can connect
# add_vias:         when set to 1, adds power vias, possible value: 0 | 1
# editPowerVia    -skip_via_on_pin    Standardcell \
#                 -bottom_layer       M1 \
#                 -top_layer          M8 \
#                 -add_vias           1

# get an idea of zero wire load timing of the design
timeDesign  -outDir ../${rm_core_top}/reports/postPowerplan -prePlace
exec ../scripts/extract_report.csh ../${rm_core_top}/reports/postPowerplan

