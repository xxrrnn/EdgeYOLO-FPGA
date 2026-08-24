"""
IR schema definitions for the EdgeYOLO-FPGA-lite compiler.

A `plan.json` describes the complete static execution of one ONNX model on the
EdgeYOLO-FPGA-lite hardware (DCIM_Array + Global_VPU + INST_Decoder).

Schema (top-level keys):

    {
      "schema_version":  "1",
      "network":         "yolov5n" | "resnet18",
      "input_shape":     [N, C, H, W],
      "output_shape":    [...],
      "mode":            "int8" | "int16",     # data path width
      "address_map": {                          # mirrors chip-v3 Vivado BD
          "ibuf_base":   0x100000000,
          "ibuf_size":   524288,
          "tile_obuf_base": 0x101000000,
          "tile_obuf_size": 262144,
          "vpu_buf_base": 0x102000000,
          "obuf_base":   0x102000000,
          "obuf_size":   8388608,
          "vpu_buf_size": 8388608,
          "wb_base":     0x103000000,
          "wb_size":     32768,
          "inst_base":   0x104000000,
          "inst_size":   131072,
          "regs_base":   0x105000000,
          "regs_size":   4096
      },
      "memory_plan": {                          # OBUF byte ranges (16MB)
          "ping_a":      [0x000000, 0x400000],  # 4MB ping
          "pong_b":      [0x400000, 0x800000],  # 4MB pong
          "im2col":      [0x800000, 0xC00000],  # 4MB im2col scratch
          "skip":        [0xC00000, 0xFF0000],  # add/concat scratch
          "wb_scratch":  [0xFF0000, 0x1000000], # 64KB WB shadow before CDMA→WB
          "layers": [                           # per-layer input/output regions
            {"name": "...", "input_off": 0x000000, "output_off": 0x400000,
             "im2col_off": 0x800000, "wb_off": 0xFF0000}
          ]
      },
      "weights_layout": {                       # IBUF (2MB)
          "layers": [
            {"name": "...", "wei_base_word": 0,
             "tile_base_word": [t0, t1, ..., t7],
             "weight_bytes": N}
          ]
      },
      "wb_layout": {                            # 32KB WB on-chip
          "layers": [
            {"name": "...", "scale_off": 0, "bias_off": 256,
             "qa_scale_off": 512, "lut_off": 516, "section_bytes": N}
          ]
      },
      "ops": [                                  # ordered sequence of primitives
          {"kind": "vpu_exec",  "unit": "im2col"|"qa"|"dqa"|"ad"|"mp"|"us"|"nn",
           "layer": "<name>", "args": {...12 VPU regs...}},
          {"kind": "cdma_copy", "src_lsb": ..., "dst_lsb": ..., "length": ...},
          {"kind": "dcim_cfg",  "pairs": [[addr, data], ...]},
          {"kind": "dcim_exec"},
          {"kind": "wait_vpu" | "wait_cdma" | "wait_dcim" | "sync" | "nop"},
          {"kind": "end"}
      ],
      "host_io": {                              # what the host has to do
          "input_obuf_off":  0x000000,          # where to upload the image
          "output_obuf_off": 0x...,             # where to read final result
          "input_dtype":     "uint8",
          "output_dtype":    "float32" | "uint8" | "int8"
      }
    }

This file is deliberately documentation + a few helper constants only; the
authoritative implementation of each section lives next to where it is
produced (`lowering.lower`, `packer.*`).
"""

from typing import Any, Dict

SCHEMA_VERSION = "1"

# ---- VPU sub-unit selectors (must match Global_VPU.v:77-83) ----
UNIT_DQA = 1
UNIT_NN = 2
UNIT_QA = 3
UNIT_MP = 4
UNIT_US = 5
UNIT_AD = 6
UNIT_IM2COL = 7

VPU_UNIT_NAME = {
    UNIT_DQA: "dqa",
    UNIT_NN: "nn",
    UNIT_QA: "qa",
    UNIT_MP: "mp",
    UNIT_US: "us",
    UNIT_AD: "ad",
    UNIT_IM2COL: "im2col",
}
VPU_UNIT_ID = {v: k for k, v in VPU_UNIT_NAME.items()}

# ---- Opcode (must match INST_Decoder.sv:84-93) ----
OP_NOP = 0x0
OP_CDMA_COPY = 0x1
OP_VPU_EXEC = 0x2
OP_WAIT_CDMA = 0x3
OP_WAIT_VPU = 0x4
OP_SYNC = 0x5
OP_DCIM_EXEC = 0x6
OP_WAIT_DCIM = 0x7
OP_DCIM_CFG = 0x8
OP_DCIM_LAYER = 0x9
OP_CDMA_STRIDE = 0xA
OP_END = 0xF

# ---- DCIM register addresses (must match chip_defines.vh:154-158) ----
DCIM_REG_CTRL = 0x000
DCIM_REG_MODE = 0x008
DCIM_REG_ACT_BASE = 0x010
DCIM_REG_BATCH_COUNT = 0x018
DCIM_REG_ACT_STRIDE = 0x01C
DCIM_REG_OUT_STRIDE = 0x020
DCIM_REG_REPEAT_COUNT = 0x024
DCIM_REG_WEI_BASE = 0x040       # +4 per tile, 8 tiles
DCIM_REG_OUT_BASE = 0x140       # +4 per tile, 8 tiles
DCIM_REG_TILE_MASK = 0x240
DCIM_REG_TILE_MASK_HI = 0x244

# ---- DCIM mode field (chip_defines.vh:20-25) ----
DCIM_MODE_INT4 = 0b100
DCIM_MODE_INT8 = 0b110
DCIM_MODE_INT16 = 0b111
DCIM_MODE_UINT4 = 0b000
DCIM_MODE_UINT8 = 0b010
DCIM_MODE_UINT16 = 0b011

# ---- VPU flags (header[27:24]) ----
VPU_FLAG_RELU_EN = 0   # bit 0: DQA relu enable
VPU_FLAG_INT16 = 1     # bit 1: INT16 mode for QA/DQA
VPU_FLAG_DQA_ACT = 2   # bit 2: DQA input is QA-packed activation


def empty_plan(network: str, input_shape, output_shape, mode: str = "int8") -> Dict[str, Any]:
    """Return a freshly-initialized plan dict with the standard top-level keys."""
    return {
        "schema_version": SCHEMA_VERSION,
        "network": network,
        "input_shape": list(input_shape),
        "output_shape": list(output_shape),
        "mode": mode,
        "address_map": {},
        "memory_plan": {"layers": []},
        "weights_layout": {"layers": []},
        "wb_layout": {"layers": []},
        "ops": [],
        "host_io": {},
    }
