# EdgeYOLO-FPGA

HBM 近存 AI 处理器的 FPGA 验证工程。顶层只保留源码、测试，以及烧录文件。

```text
top.bit / top.ltx     烧录与 ILA 探针
project/              RTL、编译器、运行时、模型、Vivado 脚本
test/network/         网络执行与量化一致性
test/tops/            峰值算力
test/topsw/           峰值能效（占位）
```

测试命令、产物目录、判定标准和本次实测见 [`test/TESTING.md`](test/TESTING.md)。每组测试的产物写在自己的 `output/` 里。

Python 依赖：

```powershell
python -m pip install -r requirements-fpga-runtime.txt
python test/network/run.py --self-check
```

综合入口在 `project/`：

```powershell
cd project
make synth
```
