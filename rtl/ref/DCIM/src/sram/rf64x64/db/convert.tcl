# 获取当前路径下所有的 .lib 文件
set lib_files [glob *.lib]

foreach lib $lib_files {
    read_lib $lib
	set current_lib [file rootname $lib]
    write_lib -format db $current_lib -output $current_lib.db
    remove_lib $current_lib
}
exit
