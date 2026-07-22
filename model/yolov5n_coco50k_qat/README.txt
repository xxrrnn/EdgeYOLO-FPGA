Files per model (int8 / int16):
  best.pt         - QAT checkpoint: float weights + 57 activation scales + yaml (PyTorch inference)
  best.onnx       - Full inference graph (fake-quant FP32, use with detect.py)
  best.quant.onnx - int weights + scale + zero_point per layer (FPGA deployment)

Template image: template/000000000139.jpg
Expected detections (conf=0.25): 2 person, 3 chair, 1 tv, 1 laptop, 1 clock (8 total)
