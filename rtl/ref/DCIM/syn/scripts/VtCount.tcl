set all_cells [get_cells -hierarchical * -filter "is_hierarchical == false"]
set total_cells [sizeof_collection $all_cells]

set ulvt_num 0
set lvt_num  0
set svt_num  0
set hvt_num  0
set ehvt_num 0

set ulvt_area 0.0
set lvt_area  0.0
set svt_area  0.0
set hvt_area  0.0
set ehvt_area 0.0

foreach_in_collection cell $all_cells {
	set ref_name [get_attribute [get_cells $cell] ref_name]
	set area [get_attribute [get_cells $cell] area]
	if {[string match "*HVT*" $ref_name]} {
		if {[string match "*EHVT*" $ref_name]} {
			incr ehvt_num
			set ehvt_area [format "%.2f" [expr $ehvt_area + $area]]
		} else {
			incr hvt_num
			set hvt_area [format "%.2f" [expr $hvt_area + $area]]
		}
	} elseif {[string match "*LVT*" $ref_name]} {
		if {[string match "*ULVT*" $ref_name]} {
			incr ulvt_num
			set ulvt_area [format "%.2f" [expr $ulvt_area + $area]]
		} else {
			incr lvt_num
			set lvt_area [format "%.2f" [expr $lvt_area + $area]]
		}
	} else {
		incr svt_num
		set svt_area [format "%.2f" [expr $svt_area + $area]]
	}
}

# 计算百分比
set ehvt_pct [format "%.2f" [expr ($ehvt_num.0 / $total_cells) * 100]]
set hvt_pct [format "%.2f" [expr ($hvt_num.0 / $total_cells) * 100]]
set ulvt_pct [format "%.2f" [expr ($ulvt_num.0 / $total_cells) * 100]]
set lvt_pct [format "%.2f" [expr ($lvt_num.0 / $total_cells) * 100]]
set svt_pct [format "%.2f" [expr ($svt_num.0 / $total_cells) * 100]]

set total_area [expr $svt_area + $hvt_area + $lvt_area]
set svt_area_pct [format "%.2f" [expr ($svt_area / $total_area) * 100]]
set ulvt_area_pct [format "%.2f" [expr ($ulvt_area / $total_area) * 100]]
set lvt_area_pct [format "%.2f" [expr ($lvt_area / $total_area) * 100]]
set ehvt_area_pct [format "%.2f" [expr ($ehvt_area / $total_area) * 100]]
set hvt_area_pct [format "%.2f" [expr ($hvt_area / $total_area) * 100]]

redirect -file ./report/vt.rpt {
	echo "VT Distribution Report:(Numbers/Area)"
	echo "--------------------------"
	echo "Total Leaf Cells: $total_cells / $total_area"
	if {[expr $ulvt_num != 0]} {
		echo "uLVT Cells: $ulvt_num ($ulvt_pct%) / $ulvt_area ($ulvt_area_pct%)"
	}
	if {[expr $lvt_num != 0]} {
		echo "LVT Cells: $lvt_num ($lvt_pct%) / $lvt_area ($lvt_area_pct%)"
	}
	if {[expr $svt_num != 0]} {
		echo "SVT Cells: $svt_num ($svt_pct%) / $svt_area ($svt_area_pct%)"
	}
	if {[expr $hvt_num != 0]} {
		echo "HVT Cells: $hvt_num ($hvt_pct%) / $hvt_area ($hvt_area_pct%)"
	}
	if {[expr $ehvt_num != 0]} {
		echo "eHVT Cells: $ehvt_num ($ehvt_pct%) / $ehvt_area ($ehvt_area_pct%)"
	}
}
