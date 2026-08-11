# 跨测试分支公共工具

`TEST/utils` 是 `main`、`test/tops/ila` 和 `test/tops-w` 应共同使用的稳定接口：

- `paths.py`：仓库、输出、E2E compiler/runtime、RTL case generator 等统一路径；
- `benchmark.py`：UTC 时间、TOPS/TOPS-W 计算和稳定 JSON 报告；
- `xdma_win.py`：Windows XDMA/板卡访问；
- `hbm_flow.py`：HBM-first 指令与数据搬运；
- `bin/`：`xdma_info.exe`、`xdma_rw.exe`；
- `bitstream/`：各测试共用的发布 bitstream 与完整性 manifest。

分支脚本应先把仓库根目录加入 `sys.path`，然后使用包导入：

```python
from TEST.utils.benchmark import calculate_tops, utc_now, write_json_report
from TEST.utils.paths import OUTPUT_ROOT, RTL_CASE_GENERATOR
from TEST.utils.xdma_win import ChipRunnerWin
```

不要再从 `tests/chip/unit-tb` 复制 `xdma_win.py`，也不要在每个分支重复定义仓库层级、
TOPS 公式或 JSON 写入逻辑。旧 `tests/chip/unit-tb/{xdma_win,hbm_flow}.py` 只保留兼容
转发，不是第二份实现；各分支合并本次目录变更后应逐步改为上面的包导入。
