# tops_ila_cegate_260812 release manifest

This manifest binds the canonical `test/tops/ila` source tree to the completed
Vivado implementation generated on eda02. Generated Vivado artifacts are not
committed because of their size.

## Build identity

- Build tag: `tops_ila_cegate_260812`
- Device: `xcvu37p-fsvh2892-2L-e`
- Vivado: `2024.2.2`
- Flow: four placements, rank eligible candidates, route the top half with four
  routing combinations per selected placement
- Winner: `route5_place0_ExtraTimingOpt_AggressiveExplore_AggressiveExplore`
- Post-route WNS/TNS: `+0.034 ns / 0.000 ns`
- Post-route WHS/THS: `+0.004 ns / 0.000 ns`
- Setup/hold failing endpoints: `0 / 0`
- Status: timing legal, below the optional `0.05 ns / 0.02 ns` guard bands

The eda02 summary recorded source commit `76f463d`, but the server worktree
also contained the streamed-DCIM, ILA, test, XDC, and two-stage-flow sources as
working-tree content. Before publication, the actual build inputs were
compared by Git blob hash with this canonical branch and synchronized.

## Canonical remote artifacts

```text
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila/build/lite/tops_ila_cegate_260812/ImplOutputDir/post_route.dcp
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila/build/lite/tops_ila_cegate_260812/ImplOutputDir/top.bit
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila/build/lite/tops_ila_cegate_260812/ImplOutputDir/top.bin
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila/build/lite/tops_ila_cegate_260812/ImplOutputDir/top.ltx
```

SHA-256:

```text
top.bit  8466f51983322f5cf65f59c2a2ac699110af8866e5e167ae68f70fff6d45f5a6
top.bin  b56ec174a58739c205d24bd722891932051b123db56768ebb4cb64b7a159016d
top.ltx  b1feb90460ab4b581bb70a4736f2210c888efe9ba0f7a7cf17037af37b4f127d
```

`top.bit` and `top.ltx` must be used as a pair.

## Reproduction

From a clean checkout of `test/tops/ila` on eda02:

```bash
BUILD_TAG=tops_ila_cegate_260812 \
VIVADO_THREADS=32 SYNTH_JOBS=128 PLACE_THREADS=16 ROUTE_THREADS=16 \
RACE_PLACE_GATE_WNS_NS=-0.75 \
bash scripts/chip-lite/impl_two_stage.sh
```

The implementation flow explores multiple legal placements and routes, so a
new run is expected to be functionally equivalent but is not guaranteed to
produce a byte-identical routed checkpoint or bitstream.
