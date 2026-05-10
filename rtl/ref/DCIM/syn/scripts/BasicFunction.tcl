proc AnalyzeFilelist {filelist_path} {
	set src_files [list]

	if {![file exist $filelist_path]} {
		puts "Error: [info level 0] $filelist_path Not Found!."
		return $src_files
	}

	set fp [open $filelist_path r]
	while {[gets $fp line] >= 0} {
		set line [string trim $line]
		if {$line eq ""} {continue}
		if {[regexp {^//} $line] || [regexp {^#} $line]} {continue}
		if {[regexp {^\+} $line] || [regexp {^\-} $line]} {continue}
		lappend src_files $line
	}
	close $fp

	return $src_files
}
