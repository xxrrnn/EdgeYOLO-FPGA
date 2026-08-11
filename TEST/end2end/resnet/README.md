# ResNet E2E 资产

- `model/resnet18_fp32.onnx`：FP32 参考图。
- `model/resnet18_w8a8.onnx`：W8A8 QDQ 图。
- `model/parsed_vai/`：当前原生 INT8 部署权重。
- `model/parsed_vai_int16_widened/`：INT8 数值扩宽为 INT16 存储/计算的数据通路测试集。
- `examples/`：20 张 ImageNet 输入及 manifest。
- `resnet_e2e.py`：ResNet 专用图连接、前后处理与 host FC；`run.py` 是专用入口。

当前没有“重新训练或量化得到的原生 INT16 ResNet PT/ONNX”。因此 widened INT16 的
合格结论应写成“支持 INT16 硬件执行路径”，不能用它证明原生 INT16 ResNet 模型精度。
INT8 和 widened INT16 仍应分别运行、分别记录结果。
