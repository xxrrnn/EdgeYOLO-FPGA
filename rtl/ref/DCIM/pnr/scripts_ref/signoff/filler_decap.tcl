#####################################################################################
# Description:  Innovus Add Filler and Decap Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################

# insert filler cell instances in the gap between standard cell instances
addFiller -cell ${rm_fill_cells} -prefix DECAP

# preprocess the design for the NanoRoute router and launch ECO routing within the router
# fix_drc: allow NanoRoute to fix only the DRC's on existing DRC markers in the design
ecoRoute  -fix_drc

# check DRC
verify_drc

