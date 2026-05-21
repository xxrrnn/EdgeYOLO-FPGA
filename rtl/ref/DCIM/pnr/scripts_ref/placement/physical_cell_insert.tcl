#####################################################################################
# Description:  Innovus Add Physical-only Cells (EndCap & WellTap & DeCap) Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################

# setInstancePlacementStatus {-allHardMacros | -allPtnBlks |-allBlackBoxes | -name instName(s)} [-status {unplaced | fixed | placed | cover | softFixed}]
# unplaced:     unplaced component does not have a location
# fixed:        fixed component has a location and cannot be moved by automatic tools, but can be moved using interactive commands
# placed:       placed component has a location, and can be moved using automatic tools and interactive commands
# cover:        cover component has a location, but cannot be moved by automatic tools or interactive commands
# softFixed:    softFixed placement status means that instances cannot be moved by global placement and can only be moved by the legalization step of detail placement, instances with this status can also be upsized by optimization  
setInstancePlacementStatus -allHardMacros -status Fixed

# add physical-only end cap cells at the ends of the sites rows, a single-height cap cell is required at the end of each row
addEndCap

# add physical-only well-tap cells
# cell:         specify the name of the cell in the technology library to use as a well-tap
# cellInterval: specify the maximum distance from the center of one well-tap cell to the center of the following well-tap cell in the same row
# checkerboard: place the well-tap cells in a checkered pattern
addWellTap  -cell           ${rm_tap_cell} \
            -cellInterval   $rm_tap_cell_distance \
            -checkerboard

# add decap cells
addWellTap  -prefix         DECAP \
            -cellInterval   $rm_tap_cell_distance \
            -cell           ${dcap_cell} \
            -skipRow        1

