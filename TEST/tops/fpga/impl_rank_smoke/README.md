# Place-rank-top-N-route smoke test

该目录用一个很小的四路 16-bit 乘加流水线，验证生产 implementation 调度脚本本身：

1. Vivado 生成 `post_opt.dcp`；
2. `impl_two_stage.sh` 并行执行三种唯一 place；
3. 按 post-place WNS、TNS、失败端点数排序；
4. 默认只将 top-2 送入 phys_opt/route；
5. 检查 place/route 数量、winner 状态和统一 `post_route.dcp`。

在 Linux Vivado 环境运行：

```bash
bash TEST/tops/fpga/impl_rank_smoke/run_smoke.sh
```

可用 `SMOKE_TOP_N=3`、`PLACE_THREADS`、`ROUTE_THREADS` 调整测试。该 smoke test
验证调度、报告解析和 DCP 传递，不用于衡量大设计的 timing quality。

已验证记录（Vivado 2024.2.2，VU37P，tag `rank_smoke_260812_0052`）：3 个 place
均为 `SUCCESS`，top-2 只生成2个 route，二者均为
`WNS=+1.358 ns / WHS=+0.088 ns`，最终输出 `RANK_SMOKE_PASS`。复用同一组
post-place DCP 的 top-3 恢复测试也通过，rank0/rank1/rank2 各自只启动一个主
route，三个结果均为 `SUCCESS`，winner DCP 正确发布。
