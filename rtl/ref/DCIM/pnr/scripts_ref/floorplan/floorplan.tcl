#####################################################################################
# Description:  Innovus Floorplan Script
# Modifier:     
# Acknowledge:  
#####################################################################################

set die_sizex 260
set die_sizey 260

# floorPlan [-d {W H Left Bottom Right Top}] [-s {W H Left Bottom Right Top}] [-su {aspectRatio stdCellDensity Left Bottom Right Top}]
# -d:   specify die size and spacing to core boundary, die box width == W, die box height == H, {Left Bottom Right Top} == spacing to core boundary
# -s:   specify core size and spacing to die boundary, core box width == W, core box height == H, {Left Bottom Right Top} == spacing to die boundary
# -su:  determine the core size by standard cell density, aspectRatio == height / width, {Left Bottom Right Top} == spacing to die boundary
floorPlan -d $die_sizex $die_sizey 10 10 10 10
# floorPlan -su 1 0.7 100 100 100 100
