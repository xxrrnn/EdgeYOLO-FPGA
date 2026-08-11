# YOLO E2E 资产

- `model/int8/`：W8A8 QAT 的 PT、普通 ONNX 和 FPGA quant ONNX。
- `model/int16/`：原生 W16A16 QAT 的 PT、普通 ONNX 和 FPGA quant ONNX。
- `model/parsed_int8/`、`model/parsed_int16/`：compiler 直接使用的网络描述与 NPZ 权重。
- `examples/`：20 张 COCO val2017 输入及 SHA/来源 manifest。
- `detect_head.py`：YOLO 专用 host 检测头；`run.py` 是只运行 YOLO 的入口。

INT8 与 INT16 必须分别运行并分别出结果；一次 `--yolo-precision both` 可以连续执行，
但报告中仍需保留两组独立的数值正确性、检测结果和耗时证据。
