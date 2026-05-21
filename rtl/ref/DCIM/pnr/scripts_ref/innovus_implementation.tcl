#####################################################################################
# Description:  Innovus Physical Implementation Main Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowlege:   Zhantong Zhu [Peking University]
#####################################################################################

# ================================================= #
# change and source the following scripts mannually #
# ================================================= #

# -----------------------
# Floorplan
# -----------------------
source ../scripts/floorplan/floorplan.tcl

source ../scripts/floorplan/macro_preplace.tcl

source ../scripts/floorplan/halo_blockage.tcl

source ../scripts/floorplan/pin_add.tcl

saveDesign ../${rm_core_top}/backup/${rm_core_top}_postFloorplan.enc

# -----------------------
# Powerplan
# -----------------------
source ../scripts/powerplan/global_net_connect.tcl

source ../scripts/powerplan/power_ring.tcl

source ../scripts/powerplan/power_stripe.tcl

source ../scripts/powerplan/power_route.tcl

saveDesign ../${rm_core_top}/backup/${rm_core_top}_postPowerplan.enc

# -----------------------
# Placement
# -----------------------
source ../scripts/placement/physical_cell_insert.tcl

source ../scripts/placement/stdcell_place.tcl

saveDesign ../${rm_core_top}/backup/${rm_core_top}_postPlace.enc

# -----------------------
# Clock Tree Synthesis
# -----------------------
source ../scripts/clock_tree/cts.tcl

saveDesign ../${rm_core_top}/backup/${rm_core_top}_postCTS.enc

# -----------------------
# Routing
# -----------------------
source ../scripts/routing/route.tcl

# ======================== #
# Timing should meet here! #
# ======================== #

source ../scripts/routing/drc_fix.tcl

# ====================== #
# DRC should clean here! #
# ====================== #

saveDesign ../${rm_core_top}/backup/${rm_core_top}_postRoute.enc

# -----------------------
# Signoff
# -----------------------
source ../scripts/signoff/filler_decap.tcl

source ../scripts/signoff/pg_pin.tcl

source ../scripts/signoff/file_gen.tcl

source ../scripts/signoff/netlist2cdl.tcl

saveDesign ../${rm_core_top}/backup/${rm_core_top}_postSignoff.enc

# ======================= #
# IMPLEMENTATION FINISHED #
#                         #
#         ^     ^         #
#           \_/           #
#                         #
#    Congratulations!     # 
# ======================= #

