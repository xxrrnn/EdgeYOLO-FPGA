"""
yolov5n_schedule.py - Static execution schedule for YOLOv5n (model.0 to model.23).

This hardcoded schedule defines the exact order of operations for YOLOv5n
on the EdgeYOLO-FPGA-lite hardware. We stop before the detect head (model.24).

YOLOv5n structure (57 Conv + 13 Concat + 3 MaxPool + 2 Resize):
  Backbone: model.0 → model.9 (SPPF)
  FPN (neck): model.10 → model.14
  PAN: model.15 → model.23

Each entry is either:
  ("conv", layer_idx)              - run conv layer by index into layers[]
  ("concat", [src_names...])       - concat named tensor buffers
  ("upsample", src_name)           - 2x nearest neighbor upsample
  ("maxpool", src_name)            - 5x5 s1 p2 maxpool (SPPF)
  ("save", name)                   - save current tensor to named buffer (for concat/skip)
  ("load", name)                   - load named buffer as current tensor
"""

# fmt: off
YOLOV5N_SCHEDULE = [
    # === Backbone ===
    # model.0: Conv 6x6 s2, 3→16, input 640x640
    ("conv", 0),
    # model.1: Conv 3x3 s2, 16→32
    ("conv", 1),

    # model.2: C3 block (n=1), in=32, cv1_out=16, cv2_out=16, cv3_out=32
    ("save", "m2_in"),       # save input for cv2
    ("conv", 2),             # cv1: 32→16
    ("conv", 5),             # m.0.cv1: 16→16
    ("conv", 6),             # m.0.cv2: 16→16 (bottleneck out)
    ("save", "m2_bn_out"),   # bottleneck output
    ("load", "m2_in"),       # reload for cv2
    ("conv", 3),             # cv2: 32→16
    ("save", "m2_cv2_out"),
    # concat(bottleneck_out, cv2_out) → [H,W,32]
    ("concat", ["m2_bn_out", "m2_cv2_out"]),
    ("conv", 4),             # cv3: 32→32

    # model.3: Conv 3x3 s2, 32→64
    ("conv", 7),

    # model.4: C3 block (n=2), in=64, cv1_out=32, cv2_out=32, cv3_out=64
    ("save", "m4_in"),
    ("conv", 8),             # cv1: 64→32
    ("conv", 11),            # m.0.cv1: 32→32
    ("conv", 12),            # m.0.cv2: 32→32
    ("conv", 13),            # m.1.cv1: 32→32
    ("conv", 14),            # m.1.cv2: 32→32 (bottleneck out)
    ("save", "m4_bn_out"),
    ("load", "m4_in"),
    ("conv", 9),             # cv2: 64→32
    ("save", "m4_cv2_out"),
    ("concat", ["m4_bn_out", "m4_cv2_out"]),
    ("conv", 10),            # cv3: 64→64
    ("save", "P3"),          # P3 = model.4 output (for FPN concat at model.16)

    # model.5: Conv 3x3 s2, 64→128
    ("conv", 15),

    # model.6: C3 block (n=3), in=128, cv1_out=64, cv2_out=64, cv3_out=128
    ("save", "m6_in"),
    ("conv", 16),            # cv1: 128→64
    ("conv", 19),            # m.0.cv1: 64→64
    ("conv", 20),            # m.0.cv2: 64→64
    ("conv", 21),            # m.1.cv1: 64→64
    ("conv", 22),            # m.1.cv2: 64→64
    ("conv", 23),            # m.2.cv1: 64→64
    ("conv", 24),            # m.2.cv2: 64→64 (bottleneck out)
    ("save", "m6_bn_out"),
    ("load", "m6_in"),
    ("conv", 17),            # cv2: 128→64
    ("save", "m6_cv2_out"),
    ("concat", ["m6_bn_out", "m6_cv2_out"]),
    ("conv", 18),            # cv3: 128→128
    ("save", "P4"),          # P4 = model.6 output (for FPN concat at model.12)

    # model.7: Conv 3x3 s2, 128→256
    ("conv", 25),

    # model.8: C3 block (n=1), in=256, cv1_out=128, cv2_out=128, cv3_out=256
    ("save", "m8_in"),
    ("conv", 26),            # cv1: 256→128
    ("conv", 29),            # m.0.cv1: 128→128
    ("conv", 30),            # m.0.cv2: 128→128 (bottleneck out)
    ("save", "m8_bn_out"),
    ("load", "m8_in"),
    ("conv", 27),            # cv2: 256→128
    ("save", "m8_cv2_out"),
    ("concat", ["m8_bn_out", "m8_cv2_out"]),
    ("conv", 28),            # cv3: 256→256

    # model.9: SPPF, in=256, out=256
    ("conv", 31),            # cv1: 256→128
    ("save", "sppf_cv1"),
    ("maxpool", "sppf_cv1"), # mp1
    ("save", "sppf_mp1"),
    ("maxpool", "sppf_mp1"), # mp2
    ("save", "sppf_mp2"),
    ("maxpool", "sppf_mp2"), # mp3
    ("save", "sppf_mp3"),
    # concat(cv1, mp1, mp2, mp3) → [H,W,512]
    ("concat", ["sppf_cv1", "sppf_mp1", "sppf_mp2", "sppf_mp3"]),
    ("conv", 32),            # cv2: 512→256

    # === FPN (top-down) ===
    # model.10: Conv 1x1, 256→128
    ("conv", 33),
    ("save", "m10_out"),

    # model.11: Upsample 2x
    ("upsample", "m10_out"),
    ("save", "m11_out"),     # upsample result

    # model.12: Concat(upsample_out, P4)
    ("concat", ["m11_out", "P4"]),

    # model.13: C3 block (n=1, shortcut=False), in=256
    ("save", "m13_in"),
    ("conv", 34),            # cv1: 256→64
    ("conv", 37),            # m.0.cv1: 64→64
    ("conv", 38),            # m.0.cv2: 64→64
    ("save", "m13_bn_out"),
    ("load", "m13_in"),
    ("conv", 35),            # cv2: 256→64
    ("save", "m13_cv2_out"),
    ("concat", ["m13_bn_out", "m13_cv2_out"]),
    ("conv", 36),            # cv3: 128→128

    # model.14: Conv 1x1, 128→64
    ("conv", 39),
    ("save", "m14_out"),

    # model.15: Upsample 2x
    ("upsample", "m14_out"),
    ("save", "m15_out"),

    # model.16: Concat(upsample_out, P3)
    ("concat", ["m15_out", "P3"]),

    # model.17: C3 block (n=1, shortcut=False), in=128
    ("save", "m17_in"),
    ("conv", 40),            # cv1: 128→32
    ("conv", 43),            # m.0.cv1: 32→32
    ("conv", 44),            # m.0.cv2: 32→32
    ("save", "m17_bn_out"),
    ("load", "m17_in"),
    ("conv", 41),            # cv2: 128→32
    ("save", "m17_cv2_out"),
    ("concat", ["m17_bn_out", "m17_cv2_out"]),
    ("conv", 42),            # cv3: 64→64
    ("save", "PAN_P3"),      # small objects output (80x80x64)

    # === PAN (bottom-up) ===
    # model.18: Conv 3x3 s2, 64→64
    ("conv", 45),
    ("save", "m18_out"),

    # model.19: Concat(m18_out, m14_out)
    ("concat", ["m18_out", "m14_out"]),

    # model.20: C3 block (n=1, shortcut=False), in=128
    ("save", "m20_in"),
    ("conv", 46),            # cv1: 128→64
    ("conv", 49),            # m.0.cv1: 64→64
    ("conv", 50),            # m.0.cv2: 64→64
    ("save", "m20_bn_out"),
    ("load", "m20_in"),
    ("conv", 47),            # cv2: 128→64
    ("save", "m20_cv2_out"),
    ("concat", ["m20_bn_out", "m20_cv2_out"]),
    ("conv", 48),            # cv3: 128→128
    ("save", "PAN_P4"),      # medium objects output (40x40x128)

    # model.21: Conv 3x3 s2, 128→128
    ("conv", 51),
    ("save", "m21_out"),

    # model.22: Concat(m21_out, m10_out)
    ("concat", ["m21_out", "m10_out"]),

    # model.23: C3 block (n=1, shortcut=False), in=256
    ("save", "m23_in"),
    ("conv", 52),            # cv1: 256→128
    ("conv", 55),            # m.0.cv1: 128→128
    ("conv", 56),            # m.0.cv2: 128→128
    ("save", "m23_bn_out"),
    ("load", "m23_in"),
    ("conv", 53),            # cv2: 256→128
    ("save", "m23_cv2_out"),
    ("concat", ["m23_bn_out", "m23_cv2_out"]),
    ("conv", 54),            # cv3: 256→256
    ("save", "PAN_P5"),      # large objects output (20x20x256)

    # model.24 (detect head) is NOT included - done on host
]
# fmt: on
