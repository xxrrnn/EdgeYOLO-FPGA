# Weight-cache timing A/B test

该测试复刻完整设计当前最差路径的核心拓扑：5120×128-bit BRAM权重存储、
64×128-bit双bank cache，以及BRAM响应到cache写入的流水级。

- `baseline`：当前单份`load_data`寄存器；
- `replicated`：4份不可合并的本地寄存器，每份静态驱动16个cache word。

为使小设计稳定复现完整设计中BRAM与cache寄存器相距较远的情况，测试分别约束
BRAM、复制寄存器和cache寄存器到三个横向区域。它用于验证寄存器是否保留、扇出
是否下降以及相同物理距离下的时序变化，不用于预测完整设计的绝对WNS。

```bash
VIVADO=/path/to/vivado bash test/tops/fpga/synth/weight_cache_timing/run_ab.sh
```

结果位于`test/tops/output/fpga/weight_cache_timing/<tag>/`。

## 已验证结果

eda02、Vivado 2024.2.2、`xcvu37p-fsvh2892-2L-e`的post-route A/B结果：

| variant | WNS | WHS | cache FF | response FF |
| --- | ---: | ---: | ---: | ---: |
| baseline | 0.052 ns | 0.048 ns | 16384 | 128 |
| replicated | 0.199 ns | 0.052 ns | 16384 | 512 |

基线最差路径是RAMB36输出到cache寄存器，数据路径3.858 ns，其中route
3.648 ns，单bit扇出128。复制后该路径slack为0.245 ns，并退出最差路径；
新的最差路径是cache写地址译码，WNS为0.199 ns。小设计只证明改动方向和
物理结构有效，完整设计的最终WNS/WHS仍须重新综合、布局和布线确认。
