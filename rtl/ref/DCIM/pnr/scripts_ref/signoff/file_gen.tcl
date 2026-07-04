#####################################################################################
# Description:  Innovus Generate Output File Script
# Modifier:     Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Zhantong Zhu [Peking University]
#####################################################################################

# generate design abstract (LEF) information for the current routed block-level design
# 5.8:              specify the LEF version number
# cutObsMinSpacing: create cut outs in the blockages around pins
# PGpinLayers:      write out power and ground stripes on the specified layer numbers as power and ground pins
# specifyTopLayer:  create obstructions (OBS shapes) covering the block only for layers up to the specified layer
# stripePin:        write out power and ground stripes on the top metal layer as power and ground pins
write_lef_abstract  -5.8 \
                    -cutObsMinSpacing \
                    -PGpinLayers        {M7} \
                    -specifyTopLayer    M7 \
                    -stripePin \
                    ../${rm_core_top}/${rm_core_top}.lef

# write delays to a Standard Delay Format (SDF) file
# view:                 use the early and late delays for the specified analysis view to populate the min and max SDF triplet slots, the SDF typ slot remains empty
# min_view:             use the early delay from the specified analysis view to populate the SDF min slot
# type_view:            use the late delay from the specified analysis view to populate the SDF typ slot
# max_view:             use the late delay from the specified analysis view to populate the SDF max slot
# recompute_delay_calc: instruct the software to recompute any necessary data required for a complete SDF file before exporting 
write_sdf   -view func_tt_0p80v_25c \
            -recompute_delay_calc \
            ../${rm_core_top}/${rm_core_top}_tt_0p80v_25c.sdf
# -min_view func_ff_0p88v_125c
# -typ_view func_tt_0p80v_25c
# -max_view func_ss_0p72v_m40c

# build a Liberty (.lib) format model for the top cell, which is the timing model equivalent of the original design
# view: specify the current active view
do_extract_model    -view func_tt_0p80v_25c \
                    ../${rm_core_top}/${rm_core_top}_tt_0p80v_25c.lib 

set redundant_files [glob -nocomplain "../${rm_core_top}/model.asrt*"]
foreach redundant_file $redundant_files {
    file delete ${redundant_file}
}

# create a GDSII Stream file of the current database
# mapFile:  specify the file used for layer mapping
# merge:    specify a single file or a list of files to merge
# mode:     identify the layers to write, possible value: ALL | FILLONLY | NOFILL | NOINSTANCES
streamOut   -mapFile    ${rm_lef_layer_map} \
            -merge      "${gds_list}" \
            -mode       ALL \
            ../${rm_core_top}/${rm_core_top}.gds2

# write a netlist file of the design for LVS
# excludeCellInst:  exclude the instances of the specified cells from the netlist
# excludeLeafCell:  write I/O instances, macro or block instances and standard cell instances to the netlist, but do not include leaf cell definitions in the netlist
# flat:             write a flattened Verilog netlist
# phys:             write out physical cell instances, insert power and ground nets in the netlist, used for LVS
# topModuleFirst:   write out top module first
saveNetlist -excludeCellInst    ${lvs_exclude_cells} \
            -excludeLeafCell \
            -flat \
            -phys \
            ../${rm_core_top}/${rm_core_top}_flat_postpnr.v

saveNetlist -excludeCellInst    ${lvs_exclude_cells} \
            -excludeLeafCell \
            -topModuleFirst \
            ../${rm_core_top}/${rm_core_top}_hier_postpnr.v

# generate detailed timing report
timeDesign -outDir ../${rm_core_top}/reports/postSignoff -postRoute 
timeDesign -outDir ../${rm_core_top}/reports/postSignoff -postRoute -hold 
exec ../scripts/extract_report.csh ../${rm_core_top}/reports/postSignoff

