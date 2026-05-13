#####################################################################################
# Description:  Innovus Add Power/Ground Pin Label Script
# Modifier:     
# Acknowledge:  
#####################################################################################

# create a power/ground pin as per the specified coordinates of the physical shape, the net name is assumed to be the same as the pin name
# -geom <layername> <llx> <lly> <urx> <ury>:    specify the geometry of the physical pin
# <layername>:                                  specify the layer one which the power/ground pin will be created
# <llx>:                                        specify the lower-left x coordinate, in microns, of the power/ground pin
# <lly>:                                        specify the lower-left y coordinate, in microns, of the power/ground pin
# <urx>:                                        specify the upper-right x coordinate, in microns, of the power/ground pin
# <ury>:                                        specify the upper-right y coordinate, in microns, of the power/ground pin
for { set i 0 } { $i < 6 } {incr i} {
    set initX           8.24
    set initY           [expr 20.0 + $i * 15]
    set stripeHeight    0.7
    set stripeWidth     243.5
    createPGPin         VDD \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

for { set i 0 } { $i < 6 } {incr i} {
    set initX           6.84
    set initY           [expr 23.2 + $i * 15]
    set stripeHeight    0.7
    set stripeWidth     246.3
    createPGPin         VDD_SRAM \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

for { set i 0 } { $i < 6 } {incr i} {
    set initX           4.04
    set initY           [expr 26.4 + $i * 15]
    set stripeHeight    0.7
    set stripeWidth     251.9
    createPGPin         VSS \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

################################################

for { set i 0 } { $i < 2 } {incr i} {
    set initX           5.44
    set initY           [expr 116 + $i * 13]
    set stripeHeight    0.7
    set stripeWidth     249.1
    createPGPin         VDD_DCO \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

for { set i 0 } { $i < 2 } {incr i} {
    set initX           4.04
    set initY           [expr 119 + $i * 13]
    set stripeHeight    0.7
    set stripeWidth     251.9
    createPGPin         VSS \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

for { set i 0 } { $i < 3 } {incr i} {
    set initX           8.24
    set initY           [expr 110 + $i * 13]
    set stripeHeight    0.7
    set stripeWidth     243.5
    createPGPin         VDD \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

for { set i 0 } { $i < 2 } {incr i} {
    set initX           6.84
    set initY           [expr 126 + $i * 13]
    set stripeHeight    0.7
    set stripeWidth     246.3
    createPGPin         VDD_SRAM \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

createPGPin             VDD_SRAM \
                        -geom M7 \
                        113.44 113.0 \
                        [expr 113.44 + 139.7] [expr 113.0 + 0.7]

################################################
for { set i 0 } { $i < 7 } {incr i} {
    set initX           8.24
    set initY           [expr 145 + $i * 15]
    set stripeHeight    0.7
    set stripeWidth     243.5
    createPGPin         VDD \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

for { set i 0 } { $i < 7 } {incr i} {
    set initX           6.84
    set initY           [expr 148.2 + $i * 15]
    set stripeHeight    0.7
    set stripeWidth     246.3
    createPGPin         VDD_SRAM \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

for { set i 0 } { $i < 7 } {incr i} {
    set initX           4.04
    set initY           [expr 151.4 + $i * 15]
    set stripeHeight    0.7
    set stripeWidth     251.9
    createPGPin         VSS \
                        -geom M7 \
                        $initX $initY \
                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
}

#for { set i 0 } { $i <= 29 } {incr i} {
#    set initX           [expr 15.34 + $i * 14]
#    set initY           6.9
#    set stripeHeight    385.6
#    set stripeWidth     0.7
#    createPGPin         VDDCLO \
#                        -geom M8 \
#                        $initX $initY \
#                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
#}

#for { set i 0 } { $i <= 29 } {incr i} {
#    set initX           [expr 16.74 + $i * 14]
#    set initY           5.5
#    set stripeHeight    388.4
#    set stripeWidth     0.7
#    createPGPin         VDDCM \
#                        -geom M8 \
#                        $initX $initY \
#                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
#}

#for { set i 0 } { $i <= 1 } {incr i} {
#    set initX           [expr 6.92 + $i * 8]
#    set initY           0.45
#    set stripeHeight    18.8
 #   set stripeWidth     0.7
#    createPGPin         VSS_DCO \
#                        -geom M6 \
#                        $initX $initY \
#                        [expr $initX + $stripeWidth] [expr $initY + $stripeHeight]
#}
