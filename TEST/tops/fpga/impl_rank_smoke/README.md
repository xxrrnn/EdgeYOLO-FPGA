# Place-rank-top-N-route smoke test

该目录用一个很小的四路 16-bit 乘加流水线，验证生产 implementation 调度脚本本身：

1. Vivado 生成 `post_opt.dcp`；
2. `impl_two_stage.sh` 并行执行四种唯一 place；
3. 按 post-place WNS、TNS、失败端点数排序；
4. 默认选择前一半（4个候选即top-2），每个候选展开4种 phys_opt/route；
5. 检查 place/route 数量、winner 状态、统一 `post_route.dcp` 和 Markdown 汇总。

在 Linux Vivado 环境运行：

```bash
bash TEST/tops/fpga/impl_rank_smoke/run_smoke.sh
```

可用 `SMOKE_TOP_N`、`SMOKE_ROUTE_VARIANTS`、`PLACE_THREADS`、`ROUTE_THREADS`
调整测试。该 smoke test
验证调度、报告解析和 DCP 传递，不用于衡量大设计的 timing quality。

已验证记录（Vivado 2024.2.2，VU37P，tag `rank_smoke_260812_md`）：
`ExtraTimingOpt`、`Explore`、`Default`、`SSI_SpreadLogic_high` 四个 place 均为
`SUCCESS`；选择 top-2 后展开4种 route，共8个 route，全部为
`WNS=+1.358 ns / WHS=+0.088 ns`。winner DCP 和
`summary/two_stage_impl_summary.md` 均正确发布。
