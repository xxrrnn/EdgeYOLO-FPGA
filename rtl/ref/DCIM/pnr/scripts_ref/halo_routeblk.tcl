#####################################################################################
# Description:  Innovus Add Halo & Route Blockage Script
# Author:       Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
#####################################################################################

# a halo is an area that prevents the placement of blocks and standard cells within the specified halo distance from the edges of a hard macro, black box, or committed partition in order to reduce congestion
# use "deleteHaloFromBlock" command to delete halos
addHaloToBlock [list $macro_halo_spc_4 $macro_halo_spc_4 $macro_halo_spc_4 $macro_halo_spc_4] -allMacro

# the object area prevents routing of specified metal layers, signal routes, and hierarchical instances in this area
# use "deleteRouteBlk" command to delete blocks
# cover:        specify that a routing blockage of the same size as the specified block instance (-inst name) will be created on top of the instance
# exceptpgnet:  the routing blockage is to be applied on a signal net routing and not on power or ground net routing
# spacing:      specify the minimum spacing allowed between the blockage and any other routing shape
# cutLayer:     specify the cut layer, list of cut layers, or all cut layers on which the routing blockage is to be applied
# partial:      specify the density for partial routing blockages, range [0,100]
foreach {sram_inst} $sram_domain {
    createRouteBlk -cover -inst $sram_inst -exceptpgnet -layer {M1 M2 M3 M4 M5 M6 M7} -spacing $macro_halo_spc
}
