#####################################################################################
# Description:  Innovus Add Power Ring Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################
editDelete -use {POWER} -shape {RING STRIPE COREWIRE BLOCKWIRE FOLLOWPIN BLOCKRING}
# nets:     specify the names of the nets of which power rings are to be created
# follow:   specify whether core rings are placed along the core boundary or I/O boundary, possible value: core | io
# layer:    specify metal layer used for ring
# width:    specify width of ring
# spacing:  specify the distance between ring nets
# center:   specify whether to center the core rings between the I/O pads and core boundary, possible value: 0 | 1
# add ring around core box
addRing -nets {VDD VDD_SRAM VDD_DCO VSS} \
		-type core_rings \
		-follow core \
		-layer {top M7 bottom M7 left M6 right M6} \
		-width 0.7 \
		-spacing 0.7 \
		-center 0

# around:                   specify the objects around which to create rings
# offset:                   distance between ring and object boundary
# threshold:                whether to merge the block rings of two objects depending on the distance between these two objects, possible value: <value> | auto
# jog_distance:             specify the least amount of jog (little movement) allowed
# snap_wire_center_to_grid: control the snapping of the center of the rings, snapping means alignment with routing grid, possible value: None | Grid | Half_Grid | Either
# add ring around SRAM and other macros
addRing -nets {VDD VSS} \
		-type block_rings \
		-around each_block \
		-layer {top M7 bottom M7 left M6 right M6} \
		-width 0.7 \
		-spacing 0.7 \
		-center 0 \
		-threshold 0 \
		-jog_distance 0 \
		-snap_wire_center_to_grid None

