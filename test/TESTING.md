# 测试说明与实测记录

仓库根目录 `top.bit` / `top.ltx` 是当前烧录与 ILA 文件。测试分三组，产物写在各自目录、不进 Git。

```text
test/network/output/    编译缓存、验收报告、推理图、golden cache
test/tops/output/       峰值上板向量与报告
test/topsw/output/      能效（尚未接入）
```

一律在仓库根目录执行。同一时刻只跑一路上板进程。

```powershell
python -m pip install -r requirements-fpga-runtime.txt
python test/network/run.py --self-check
```

当前 bitstream：`top.bit`，84 989 276 字节，SHA256 `93d0ff5f8388a1238d63d189b65adfaa8f34cd73ae5908e70be4d10351757b06`。

---

## 网络 FPGA

`--network`：`yolo` / `resnet` / `all`。`--precision`：`int8` / `int16` / `both`。`--num`：每组图片张数。默认 `all` + `both`。

单图：

```powershell
python test/network/run.py --num 1
python test/network/run.py --network yolo --precision int8 --num 1
python test/network/run.py --network yolo --precision int8 --num 1 --golden
python test/network/run.py --network yolo --precision int8 --num 1 --golden --verbose
python test/network/run.py --network yolo --precision int16 --num 1
python test/network/run.py --network resnet --precision int8 --num 1
python test/network/run.py --network resnet --precision int16 --num 1
```

全部（每组 20 张；YOLO 用 `examples/coco`，ResNet 用 `examples/imagenet`。`all` + `both` 共 80 个用例）：

```powershell
python test/network/run.py --num 20
python test/network/run.py --network yolo --precision int8 --num 20
python test/network/run.py --network yolo --precision int16 --num 20
python test/network/run.py --network resnet --precision int8 --num 20
python test/network/run.py --network resnet --precision int16 --num 20
```

`--num 1` 默认把 FPGA 特征与 golden cache 比对；加 `--golden` 则 FPGA 跑完后再在主机计算 compiler golden。默认只打印检测类别/置信度和醒目的 `result: same`；`--verbose` 才输出 [win]/golden/路径等细节。硬门限仍是特征数值一致。产物：单图在 `test/network/output/inference/`，全部在 `test/network/output/acceptance/`。

**单图实测：四套 golden max_abs=0。**

| Workload | 图 | execute | host |
| --- | --- | ---: | --- |
| YOLO INT8 | `000000000139.jpg` | 1.12 s | 5 框 |
| YOLO INT16 | 同上 | 1.33 s | 5 框 |
| ResNet INT8 | `n01443537_goldfish.JPEG` | 0.82 s | Top-1 goldfish |
| ResNet INT16 | 同上 | 1.38 s | Top-1 goldfish |

**全部实测（reset 后单路重跑）：PASS，80/80。** 墙钟约 12.0 min。

| 组 | 张数 | 墙钟 | execute / 图 |
| --- | ---: | ---: | ---: |
| YOLO INT8 | 20 | 227 s | 1.17 s |
| YOLO INT16 | 20 | 231 s | 1.38 s |
| ResNet INT8 | 20 | 103 s | 0.85 s |
| ResNet INT16 | 20 | 149 s | 1.48 s |

不要并行跑两路上板进程，否则会抢 XDMA，H2C 可能卡住。

---

## Compiler 契约

```powershell
python project/compiler/test_int16_contract.py
python project/compiler/test_resnet_native_int16_frontend.py
python project/compiler/check_release_repro.py
```

**实测：全部 PASS。** 四组程序各编译两次，`program.bin` / `weights.bin` / `wb.bin` 字节一致。

| Workload | program words | weights.bin | wb.bin |
| --- | ---: | ---: | ---: |
| YOLO INT8 | 17813 | 1 761 280 | 38928 |
| YOLO INT16 | 32261 | 3 522 560 | 38928 |
| ResNet INT8 | 17977 | 11 169 792 | 93472 |
| ResNet INT16 | 53194（2 段） | 22 339 584 | 93472 |

---

## 计算精度（INT8 / INT16 矩阵乘）

脚本在 `test/precision/`。用随机 INT8×INT8 和 INT16×INT16 测例做主机回读；片上波形用现成 `top.ltx` 的 `peak_phase`（INT8 每 job 2 拍，INT16 每 job 4 拍）。测例 **8 个 tile 全开**，ILA 触发与峰值相同：`peak_compute_mask == 8'hFF`。

```powershell
python test/precision/run.py --prepare-only --seed 20260822
python test/precision/run.py --mode int8 --seed 20260822
python test/precision/run.py --mode int16 --seed 20260822
```

步骤和判定见 [`test/precision/README.md`](precision/README.md)。

---

## 峰值 TOPS

脚本在 `test/tops/`。先烧 `top.bit`；算 TOPS 还需 Vivado 打开 `top.ltx` 并 arm ILA。

```powershell
python test/tops/fpga/run.py --staging hbm --quiet-xdma --repeat-count 1
python test/tops/fpga/run.py --report-only --ila-active-cycles 128
```

**实测主机数值：PASS_HOST_PENDING_ILA。** 2048/2048 个 128-bit 字一致。未抓 ILA，因此没有 TOPS 数字。补 ILA 后执行上面第二条即可。

---

## topsw

占位。产物将写到 `test/topsw/output/`。

---

## 边界

- Detect head / NMS 和 ResNet GAP / FC / Top-k 在 host。
- 20+20 证明功能与数据一致性，不是完整 COCO mAP / ImageNet Top-1。
- 完整 2 TOPS 结论需要 ILA 有效周期，不能用主机比对代替。
