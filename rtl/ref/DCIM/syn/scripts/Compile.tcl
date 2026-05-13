echo "INFO: Running check_design..."
check_design > check_design.rpt

# --- 交互式确认提示 ---
# ********************************************************"
#  CHECK_DESIGN COMPLETED. Please review the warnings. "
#  If everything looks good, press \[Enter\] to start COMPILE."
#  Otherwise, press \[Ctrl+C\] to abort the task."
# ********************************************************"

gets stdin confirm

compile_ultra -no_autoungroup
