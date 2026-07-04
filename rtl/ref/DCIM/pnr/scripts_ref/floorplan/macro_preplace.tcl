#####################################################################################
# Description:  Innovus Place Hard Macro Script
# Modifier:     
# Acknowledge:  
#####################################################################################

# macro alias
set sram sram_inst
set dco dco_inst

# placeInstance instance_name location [orientation] [{-fixed | -placed | -softFixed}]
# location:     lower-left coordinate (x,y)        
# orientation:  R0 (default), R90, R180, R270, MX, MX90, MY, or MY90
placeInstance sram_inst 120 20

placeInstance dco_inst 25 115
