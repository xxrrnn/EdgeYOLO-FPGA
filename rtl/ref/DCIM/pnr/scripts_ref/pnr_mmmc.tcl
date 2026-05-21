#####################################################################################
# Description:  Physical Implementation MMMC Definition
# Modifier:     Siris Li <mingxuanli_siris@163.com> [Peking University]
# Acknowledge:  Columbia University, System Level Design Group
#####################################################################################

create_constraint_mode -name func -sdc_file $proj(constraints,func)

foreach corner $proj(corners) {
    create_library_set -name lib_$corner -timing $proj(library_set,$corner)
    create_rc_corner -name rc_$corner -qx_tech_file $proj(techfile,$corner) -T $proj($corner,T)
    create_delay_corner -name $corner -rc_corner rc_$corner -library_set lib_$corner -si_enabled false
    create_analysis_view -name func_$corner -constraint_mode func -delay_corner $corner
}

set_analysis_view -setup $proj(analysis_view,setup) -hold $proj(analysis_view,hold)

