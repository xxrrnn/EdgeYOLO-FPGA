# tops_ila_hbmfix_260813 release manifest

本文件把 HBM/CDMA 修复源码与 eda02 上完成的 Vivado implementation 绑定。
生成物体积较大，不提交到 Git；发布时必须成对使用这里记录的 `top.bit` 和
`top.ltx`。

## 构建输入

- Branch：`test/tops/ila`
- 基线提交：`a6a29fa45f3289949523fd9a9e56b2537ce05720`
- Device：`xcvu37p-fsvh2892-2L-e`
- Vivado：`2024.2.2`
- Build tag：`tops_ila_hbmfix_260813`
- Flow：4 place，选择 top-half，对每个候选运行 4 个 route

实际参加构建的修改文件与本次提交内容一致，Git blob：

```text
scripts/ip/bd/lite/cdma.tcl     8d8b3f353c95cbca4eeb8c78cd07a39be420d96b
scripts/ip/bd/lite/connect.tcl  2ba85fe976616d57864a1729fcf7a910663839bf
scripts/ip/bd/lite/hbm.tcl      384649db20c0beeb61d6da985ad25407cdc8b06a
```

本地与 eda02 在 implementation 完成后再次执行 `git hash-object`，以上三个值
逐项一致。计算 RTL 均来自基线提交 `a6a29fa`。

## Implementation 结果

- Winner：`route7_place0_ExtraTimingOpt_ExploreWithHoldFix_Explore`
- Post-route WNS/TNS：`+0.029 ns / 0.000 ns`
- Post-route WHS/THS：`+0.001 ns / 0.000 ns`
- Setup/Hold failing endpoints：`0 / 0`
- ERROR/CRITICAL WARNING：`0 / 0`
- 判定：`LOW_MARGIN`，时序合法但低于 WNS 0.05 ns、WHS 0.02 ns guard band

## 远程生成物

```text
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila/build/lite/tops_ila_hbmfix_260813/ImplOutputDir/post_route.dcp
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila/build/lite/tops_ila_hbmfix_260813/ImplOutputDir/top.bit
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila/build/lite/tops_ila_hbmfix_260813/ImplOutputDir/top.bin
/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila/build/lite/tops_ila_hbmfix_260813/ImplOutputDir/top.ltx
```

SHA-256：

```text
top.bit  cc0c28f9ee064c79528128dd462a59e8529d787a050090d91fb9ef5d95da9d2a
top.bin  7284d77df678b3e8ca2d8b85e33a1a5d4b8efe86e0db1f06e52823c3bf0739ee
top.ltx  b1feb90460ab4b581bb70a4736f2210c888efe9ba0f7a7cf17037af37b4f127d
```

## 已完成与未完成验证

已完成：BD validation、受影响 IP OOC 综合、VCS streamed multiblock、INT8/INT16
模块回归、完整综合/布局/布线和 bit/ltx 生成。

仍需板测：

1. Windows XDMA 正常枚举；
2. `run_peak_int8.py --staging preload --repeat-count 1` 为 2048/2048；
3. `run_peak_int8.py --staging hbm --repeat-count 1` 为 2048/2048；
4. main-compatible YOLO/ResNet end-to-end，初测保持 256B C2H 分块；
5. 单笔 4KB/64KB C2H。当前修改没有实现 tile/VPU 专用 outstanding limiter，
   因此不能在板测前宣称长 C2H 已根治。
