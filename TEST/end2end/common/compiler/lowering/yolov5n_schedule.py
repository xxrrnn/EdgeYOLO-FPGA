"""
yolov5n_schedule.py - Static execution schedule for YOLOv5n model.0..model.23.

The detect head (model.24), NMS, and image preprocessing stay on the host.
Everything here is intended to run on FPGA: conv, concat,
upsample, and SPPF maxpool.

Each entry is one of:
  ("conv", layer_idx)         - run a parsed Conv layer by index
  ("save", name)              - copy current FP32 tensor to a named buffer
  ("load", name)              - make a named buffer current
  ("concat", [names...])      - concat named FP32 tensors by channel
  ("upsample", name)          - 2x nearest-neighbor upsample
  ("maxpool", name)           - 5x5 stride1 pad2 maxpool
  ("add", name)               - FP32 residual add current + named tensor

Note: the current parsed/legacy E2E YOLO oracle does not apply Bottleneck
shortcut adds inside C3 blocks.  Keep this schedule aligned with that oracle;
otherwise full-network detections drift even when the one-shot feature compare
is internally self-consistent.

Layer indices match TEST/end2end/yolo/model/parsed_int8/network.json.
"""

# fmt: off
YOLOV5N_SCHEDULE = [
    # Backbone
    ("conv", 0),   # model.0.conv
    ("conv", 1),   # model.1.conv

    # model.2 C3, legacy oracle has no bottleneck shortcut add
    ("save", "m2_in"),
    ("conv", 2),
    ("conv", 3),
    ("conv", 4),
    ("save", "m2_bn_out"),
    ("load", "m2_in"),
    ("conv", 5),
    ("save", "m2_cv2_out"),
    ("concat", ["m2_bn_out", "m2_cv2_out"]),
    ("conv", 6),

    ("conv", 7),   # model.3.conv

    # model.4 C3, legacy oracle has no bottleneck shortcut add
    ("save", "m4_in"),
    ("conv", 8),
    ("conv", 9),
    ("conv", 10),
    ("conv", 11),
    ("conv", 12),
    ("save", "m4_bn_out"),
    ("load", "m4_in"),
    ("conv", 13),
    ("save", "m4_cv2_out"),
    ("concat", ["m4_bn_out", "m4_cv2_out"]),
    ("conv", 14),
    ("save", "P3"),

    ("conv", 15),  # model.5.conv

    # model.6 C3, legacy oracle has no bottleneck shortcut add
    ("save", "m6_in"),
    ("conv", 16),
    ("conv", 17),
    ("conv", 18),
    ("conv", 19),
    ("conv", 20),
    ("conv", 21),
    ("conv", 22),
    ("save", "m6_bn_out"),
    ("load", "m6_in"),
    ("conv", 23),
    ("save", "m6_cv2_out"),
    ("concat", ["m6_bn_out", "m6_cv2_out"]),
    ("conv", 24),
    ("save", "P4"),

    ("conv", 25),  # model.7.conv

    # model.8 C3, legacy oracle has no bottleneck shortcut add
    ("save", "m8_in"),
    ("conv", 26),
    ("conv", 27),
    ("conv", 28),
    ("save", "m8_bn_out"),
    ("load", "m8_in"),
    ("conv", 29),
    ("save", "m8_cv2_out"),
    ("concat", ["m8_bn_out", "m8_cv2_out"]),
    ("conv", 30),

    # model.9 SPPF
    ("conv", 31),
    ("save", "sppf_cv1"),
    ("maxpool", "sppf_cv1"),
    ("save", "sppf_mp1"),
    ("maxpool", "sppf_mp1"),
    ("save", "sppf_mp2"),
    ("maxpool", "sppf_mp2"),
    ("save", "sppf_mp3"),
    ("concat", ["sppf_cv1", "sppf_mp1", "sppf_mp2", "sppf_mp3"]),
    ("conv", 32),

    # FPN
    ("conv", 33),  # model.10.conv
    ("save", "m10_out"),
    ("upsample", "m10_out"),
    ("save", "m11_out"),
    ("concat", ["m11_out", "P4"]),

    # model.13 C3, shortcut=False
    ("save", "m13_in"),
    ("conv", 34),
    ("conv", 35),
    ("conv", 36),
    ("save", "m13_bn_out"),
    ("load", "m13_in"),
    ("conv", 37),
    ("save", "m13_cv2_out"),
    ("concat", ["m13_bn_out", "m13_cv2_out"]),
    ("conv", 38),

    ("conv", 39),  # model.14.conv
    ("save", "m14_out"),
    ("upsample", "m14_out"),
    ("save", "m15_out"),
    ("concat", ["m15_out", "P3"]),

    # model.17 C3, shortcut=False
    ("save", "m17_in"),
    ("conv", 40),
    ("conv", 41),
    ("conv", 42),
    ("save", "m17_bn_out"),
    ("load", "m17_in"),
    ("conv", 43),
    ("save", "m17_cv2_out"),
    ("concat", ["m17_bn_out", "m17_cv2_out"]),
    ("conv", 44),
    ("save", "PAN_P3"),

    # PAN
    ("conv", 45),  # model.18.conv
    ("save", "m18_out"),
    ("concat", ["m18_out", "m14_out"]),

    # model.20 C3, shortcut=False
    ("save", "m20_in"),
    ("conv", 46),
    ("conv", 47),
    ("conv", 48),
    ("save", "m20_bn_out"),
    ("load", "m20_in"),
    ("conv", 49),
    ("save", "m20_cv2_out"),
    ("concat", ["m20_bn_out", "m20_cv2_out"]),
    ("conv", 50),
    ("save", "PAN_P4"),

    ("conv", 51),  # model.21.conv
    ("save", "m21_out"),
    ("concat", ["m21_out", "m10_out"]),

    # model.23 C3, shortcut=False
    ("save", "m23_in"),
    ("conv", 52),
    ("conv", 53),
    ("conv", 54),
    ("save", "m23_bn_out"),
    ("load", "m23_in"),
    ("conv", 55),
    ("save", "m23_cv2_out"),
    ("concat", ["m23_bn_out", "m23_cv2_out"]),
    ("conv", 56),
    ("save", "PAN_P5"),
]
# fmt: on
