# 唯一部署 bitstream

烧录 `edgeyolo_80832ec_attempt1_native_w16a16.bit`。

- 原文件：`80832ec_attempt1_clean_ExtraTimingOpt_AggressiveExplore_AggressiveExplore.bit`
- 当时的本地选用名：`0725.bit`
- RTL 源提交：`80832ec49984c559d4f5c1bba8d8da40807369f3`
- 大小：84,989,276 bytes
- SHA256：`17ec07b150d187d777b02f79541adad7407ddbafa38aeddfdd7ff74c084933cf`
- 目标器件：`xcvu37p-fsvh2892-2L-e`
- Vivado：2024.2.2

该版本实现 native INT16/INT64 accumulator contract。2026-07-25 的上板记录显示，
COCO YOLO native W16A16 完成 57/57 层，并在 `atol=0.01` 下通过 feature gate。

`attempt0` 和旧 `c1773f6` 不属于当前发布，已从 main 移出；历史文件仍可在
`codex/archive-main-full-20260810` 分支恢复。仓库中没有保留 attempt1 的数值 timing
summary，因此不复用 c1773f6 的 WNS/TNS 报告，也不在此虚构具体裕量。
