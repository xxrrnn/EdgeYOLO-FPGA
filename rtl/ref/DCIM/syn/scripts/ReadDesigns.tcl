set DESIGN_NAME "dcim_wrapper"
set FILE_LIST "filelist.f"
set PATH_INCLUDE "/data/home/za_xiao31/workplace/DCIM/src/inc"
set WORK_DIR ./work

lappend search_path $PATH_INCLUDE

file mkdir $WORK_DIR
define_design_lib WORK -path $WORK_DIR

set src_files [AnalyzeFilelist $FILE_LIST]

analyze -format sverilog $src_files

# Elaboration
elaborate $DESIGN_NAME

link

uniquify

set all_adderTree_designs [get_designs *adderTree_WD_IN8_CH_IN16*]
if {[sizeof_collection $all_adderTree_designs] > 0} {
	puts "Info: Found [sizeof_collection $all_adderTree_designs] adderTree instants. Flatting..."

	foreach_in_collection design_obj $all_adderTree_designs {
		set design_name [get_object_name $design_obj]

		current_design $design_name

		ungroup -all -flatten
	}
} else {
	puts "Warning: No adderTree instant found!"
}

current_design $DESIGN_NAME
