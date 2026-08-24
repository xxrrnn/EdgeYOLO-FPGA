Bundled source models (int8/ and int16/):
  best.pt         - QAT checkpoint (PyTorch reference/migration)
  best.onnx       - fake-quant FP32 inference graph
  best.quant.onnx - integer weights/scales used to regenerate FPGA parsed data

Deployment inputs:
  parsed_int8/    - native W8A8
  parsed_int16/   - native W16A16 with signed INT64 FPGA accumulators

Default test image: examples/coco/000000000139.jpg
