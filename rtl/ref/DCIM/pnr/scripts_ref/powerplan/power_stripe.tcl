#####################################################################################
# Description:  Innovus Add Power Stripe Script
# Modifier:     
# Acknowledge:  
#####################################################################################

# set global variables for power stripes
# stacked_via_bottom_layer:     specify the lowest layer in which vias can be stacked, stacked vias mean the directly stacked vias between two non-adjacent layers, default: the lowest metal layer in the design
# stacked_via_top_layer:        specify the highest layer in which vias can be stacked, default: the highest metal layer in the design
# ignore_nondefault_domains:    create global stripes over domains without breaking, default: false

#setAddStripeMode    -stacked_via_bottom_layer   M1 \
#                    -stacked_via_top_layer      M8 \
#                    -ignore_nondefault_domains  true

# create power stripes within the specified area
# nets:                             specify the names of the nets for which stripes are to be created, the number of net names determines the number of stripes within each set of stripes
# layer:                            specify the name of layer in which to create stripes, stripes can be created on only one layer at a time
# direction:                        set the stripe direction, possible value: horizontal | vertical, default: vertical
# width:                            specify the width of the stripes
# spacing:                          specify the width of the gap between stripes in one set
# start_offset:                     specify the starting offset value off of the appropriate boundary of the stripe generation area to the nearest edge of the first stripe
# set_to_set_distance:              specify the distance (pitch) from the reference stripe of one set to the reference stripe of the next set
# block_ring_bottom_layer_limit:    specify the lowest layer that stripes can switch to when encountering a block ring
# block_ring_top_layer_limit:       specify the highest layer that stripes can switch to when encountering a block ring
# padcore_ring_bottom_layer_limit:  specify the lowest layer that stripes can switch to when encountering a core or pad ring
# padcore_ring_top_layer_limit:     specify the hightest layer that stripes can switch to when encountering a core or pad ring

#addStripe   -nets                               { VDD VDDCLO VDDCM VSS } \
#			-layer                              M7 \
#			-direction                          horizontal \
#			-width                              0.7 \
#			-spacing                            0.7 \
#			-start_offset                       7 \
#			-set_to_set_distance                14 \
#			-block_ring_bottom_layer_limit      M1 \
#			-block_ring_top_layer_limit         M8 \
#			-padcore_ring_bottom_layer_limit    M1 \
#			-padcore_ring_top_layer_limit       M8

editDelete -use {POWER} -shape {STRIPE} -layer 7


setAddStripeMode    -stacked_via_bottom_layer   M1 \
                    -stacked_via_top_layer      M7 \
                    -ignore_nondefault_domains  true

addStripe   -nets                               { VDD VDD_SRAM VSS } \
			-layer                              M6 \
			-direction                          vertical \
			-width                              0.7 \
			-spacing                            2.8 \
			-start_offset                       100 \
			-set_to_set_distance                15 \
			-block_ring_bottom_layer_limit      M1 \
			-block_ring_top_layer_limit         M8 \
			-padcore_ring_bottom_layer_limit    M1 \
			-padcore_ring_top_layer_limit       M8

addStripe   -nets                               { VDD VSS } \
			-layer                              M6 \
			-direction                          vertical \
			-width                              0.7 \
			-spacing                            2.8 \
			-start_offset                       10 \
			-stop_offset                        130 \
			-set_to_set_distance                15 \
			-block_ring_bottom_layer_limit      M1 \
			-block_ring_top_layer_limit         M8 \
			-padcore_ring_bottom_layer_limit    M1 \
			-padcore_ring_top_layer_limit       M8

setAddStripeMode    -stacked_via_bottom_layer   M6 \
                    -stacked_via_top_layer      M7 \
                    -ignore_nondefault_domains  true

addStripe   -nets                               { VDD VDD_SRAM VDD_DCO VSS } \
			-layer                              M7 \
			-direction                          horizontal \
			-width                              0.7 \
			-spacing                            2.3 \
			-start_offset                       100 \
			-stop_offset                        110 \
			-set_to_set_distance                13 \
			-block_ring_bottom_layer_limit      M1 \
			-block_ring_top_layer_limit         M8 \
			-padcore_ring_bottom_layer_limit    M1 \
			-padcore_ring_top_layer_limit       M8

addStripe   -nets                               { VDD VDD_SRAM VSS } \
			-layer                              M7 \
			-direction                          horizontal \
			-width                              0.7 \
			-spacing                            2.5 \
			-start_offset                       10 \
			-stop_offset                        140 \
			-set_to_set_distance                15 \
			-block_ring_bottom_layer_limit      M1 \
			-block_ring_top_layer_limit         M8 \
			-padcore_ring_bottom_layer_limit    M1 \
			-padcore_ring_top_layer_limit       M8

addStripe   -nets                               { VDD VDD_SRAM VSS } \
			-layer                              M7 \
			-direction                          horizontal \
			-width                              0.7 \
			-spacing                            2.5 \
			-start_offset                       135 \
			-set_to_set_distance                15 \
			-block_ring_bottom_layer_limit      M1 \
			-block_ring_top_layer_limit         M8 \
			-padcore_ring_bottom_layer_limit    M1 \
			-padcore_ring_top_layer_limit       M8
