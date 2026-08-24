#!/usr/bin/env python3
"""Compile and run the CDMA SR idle-hold Verilator TB from WSL."""
import os
import pathlib
import subprocess
import sys

repo = pathlib.Path("/mnt/e/work2026/runnan_xu/FPGA/EdgeYOLO-FPGA")
script = r"""#!/usr/bin/env bash
set -euo pipefail
REPO=/mnt/e/work2026/runnan_xu/FPGA/EdgeYOLO-FPGA
SIM=$REPO/test/tops/simulation
RUN_DIR=/tmp/cdma_sr_idle_hold
OBJ=$RUN_DIR/obj_dir
TOP=tb_cdma_sr_idle_hold
rm -rf "$RUN_DIR"
mkdir -p "$OBJ"
verilator --cc --exe --top-module "$TOP" --autoflush \
  -DSIMULATION \
  -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-PINMISSING \
  -I"$REPO/rtl/chip" \
  -Mdir "$OBJ" \
  "$REPO/rtl/vpu/CDMA_Controller.sv" \
  "$SIM/tb_cdma_sr_idle_hold.sv" \
  --exe "$SIM/tb_cdma_sr_idle_hold.cpp"
make -C "$OBJ" -f "V${TOP}.mk" -j"$(nproc 2>/dev/null || echo 4)"
"$OBJ/V${TOP}"
"""
dst = pathlib.Path("/tmp/run_cdma_sr_idle_hold.sh")
dst.write_text(script.replace("\r", ""), encoding="utf-8")
dst.chmod(0o755)
env = os.environ.copy()
sys.exit(subprocess.call(["bash", str(dst)], env=env))
