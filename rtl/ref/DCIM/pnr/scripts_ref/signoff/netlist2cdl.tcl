#####################################################################################
# Description:  Converting Verilog Netlist to CDL format for LVS
# Author:       Mingxuan Li <mingxuanli_siris@163.com> [Peking University]
#####################################################################################

set cur_dir [pwd]
echo "v2lvs   ${v2lvs_option} \
        -v ${cur_dir}/../${rm_core_top}/${rm_core_top}_flat_postpnr.v \
        -o ${cur_dir}/../${rm_core_top}/${rm_core_top}.cdl" > ../scripts/signoff/v2lvs_run.csh
exec chmod +x ../scripts/signoff/v2lvs_run.csh
exec ../scripts/signoff/v2lvs_run.csh
