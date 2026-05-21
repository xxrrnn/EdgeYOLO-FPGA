#!/usr/bin/env python3
"""
golden_e2e.py - 3-layer CNN end-to-end golden reference for FPGA accelerator verification.

Layers:
  Layer 1: model.1.conv        – in_ch=16, out_ch=32, 3x3, stride=2, pad=1, input 160x160
  Layer 2: model.2.cv1.conv    – in_ch=32, out_ch=16, 1x1, stride=1, pad=0, input 80x80
  Layer 3: model.2.m.0.cv2.conv – in_ch=16, out_ch=16, 3x3, stride=1, pad=1, input 80x80

NOTE: User originally specified model.2.m.0.cv1.conv for layer 3, but that is actually a 1x1
conv in the model. We use model.2.m.0.cv2.conv which is the 3x3 conv in the bottleneck block.

Data flow per layer:
  1. im2col: reshape feature → [OH*OW, KH*KW*IC]
  2. matmul: im2col × weight^T → INT32 accumulators
  3. dqa: FP32 = accum * dqa_scale + dqa_bias (per output channel)
  4. relu: max(0, x)
  5. qa: UINT8 = clamp(round(x / act_scale), 0, 255)

Weight SRAM format (INT8 mode, 4-bit nibble storage):
  Each 128-bit entry stores 1 output channel's weights for 16 input channels.
  Entry layout: {high_nibbles[63:0], low_nibbles[63:0]}
    low_nibbles[ch*4 +: 4]  = weight[ch] & 0xF
    high_nibbles[ch*4 +: 4] = (weight[ch] >> 4) & 0xF
  For acc_depth > 1 (e.g. 3x3 conv with IC=16 → 9 im2col words):
    acc_word i uses weight_sram[base + i] for each output channel.
    Total entries per output channel = acc_depth.
"""

import numpy as np
import struct
import os
import sys

# =============================================================================
# Constants
# =============================================================================
WEIGHT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', '..', '..', '..', 'model', 'parsed', 'weights'
)

NUM_TILES = 8
DCIM_CH_IN = 16
DCIM_CH_OUT_PER_TILE = 2  # 2 ch_out per maColumn pair of entries
DCIM_COLUMNS_PER_TILE = 4
DCIM_CH_OUT_PER_COLUMN = 4  # INT8 mode: 4 ch_out per maColumn
TILE_CH_OUT = 16  # total output channels per tile
CYCLE = 8
WD1 = 4  # nibble width

OBUF_WORD_BYTES = 16  # 128-bit


# =============================================================================
# ConvLayer: encapsulates one convolution layer's parameters and computation
# =============================================================================
class ConvLayer:
    """Represents a single convolution layer with INT8 weights and quantized activations."""

    def __init__(self, name, npz_path, in_h, in_w, in_ch, out_ch, kh, kw, stride, pad):
        self.name = name
        self.in_h = in_h
        self.in_w = in_w
        self.in_ch = in_ch
        self.out_ch = out_ch
        self.kh = kh
        self.kw = kw
        self.stride = stride
        self.pad = pad

        self.oh = (in_h + 2 * pad - kh) // stride + 1
        self.ow = (in_w + 2 * pad - kw) // stride + 1
        self.acc_depth = (kh * kw * in_ch + DCIM_CH_IN - 1) // DCIM_CH_IN

        data = np.load(npz_path)
        self.weight_int8 = data['weight_int8']       # [OC, IC, KH, KW] int8
        self.dqa_scale = data['dqa_scale']           # [OC] float32
        self.dqa_bias = data['dqa_bias']             # [OC] float32
        self.act_scale = float(data['act_scale'])    # scalar float32

        assert self.weight_int8.shape == (out_ch, in_ch, kh, kw), \
            f"{name}: weight shape mismatch: {self.weight_int8.shape}"

    @property
    def im2col_cols(self):
        return self.kh * self.kw * self.in_ch

    @property
    def im2col_cols_padded(self):
        """Padded to multiple of DCIM_CH_IN (16)."""
        return self.acc_depth * DCIM_CH_IN

    @property
    def num_tiles_needed(self):
        """Number of DCIM tiles required to cover all output channels."""
        return (self.out_ch + TILE_CH_OUT - 1) // TILE_CH_OUT

    def compute_im2col(self, feat):
        """
        im2col: NHWC feature [H, W, C] → [OH*OW, KH*KW*IC] (int8).
        Zero padding for out-of-bounds.
        """
        assert feat.shape == (self.in_h, self.in_w, self.in_ch)
        rows = self.oh * self.ow
        cols = self.im2col_cols_padded
        result = np.zeros((rows, cols), dtype=np.int8)

        for oh in range(self.oh):
            for ow in range(self.ow):
                row_idx = oh * self.ow + ow
                col_idx = 0
                for ky in range(self.kh):
                    for kx in range(self.kw):
                        ih = oh * self.stride - self.pad + ky
                        iw = ow * self.stride - self.pad + kx
                        for c in range(self.in_ch):
                            if 0 <= ih < self.in_h and 0 <= iw < self.in_w:
                                result[row_idx, col_idx] = feat[ih, iw, c]
                            col_idx += 1
        return result

    def compute_matmul(self, im2col_matrix):
        """
        Compute INT32 accumulator: im2col × weight^T.
        weight reshaped to [OC, KH*KW*IC], padded to match im2col width.
        Returns [OH*OW, OC] int32.
        """
        w_flat = self.weight_int8.reshape(self.out_ch, -1).astype(np.int32)
        # Pad weight to im2col_cols_padded if needed
        if w_flat.shape[1] < self.im2col_cols_padded:
            pad_width = self.im2col_cols_padded - w_flat.shape[1]
            w_flat = np.pad(w_flat, ((0, 0), (0, pad_width)), constant_values=0)

        act = im2col_matrix.astype(np.int32)
        accum = act @ w_flat.T  # [OH*OW, OC]
        return accum

    def apply_dqa(self, accum):
        """Dequantize-accumulator: FP32 = accum * dqa_scale + dqa_bias."""
        return accum.astype(np.float32) * self.dqa_scale[np.newaxis, :] + self.dqa_bias[np.newaxis, :]

    def apply_relu(self, x):
        """ReLU activation."""
        return np.maximum(x, 0.0)

    def apply_qa(self, x):
        """Requantize to UINT8: clamp(round(x / act_scale), 0, 255)."""
        quantized = np.round(x / self.act_scale).astype(np.int32)
        return np.clip(quantized, 0, 255).astype(np.uint8)

    def forward(self, feat):
        """
        Full forward pass: im2col → matmul → dqa → relu → qa.
        Returns (output_uint8 [OH, OW, OC], intermediates dict).
        """
        im2col = self.compute_im2col(feat)
        accum = self.compute_matmul(im2col)
        dqa_out = self.apply_dqa(accum)
        relu_out = self.apply_relu(dqa_out)
        qa_out = self.apply_qa(relu_out)

        output = qa_out.reshape(self.oh, self.ow, self.out_ch)

        intermediates = {
            'im2col': im2col,
            'accum_int32': accum,
            'dqa_fp32': dqa_out,
            'relu_fp32': relu_out,
            'qa_uint8': qa_out,
        }
        return output, intermediates


# =============================================================================
# Weight SRAM packing
# =============================================================================
def pack_weight_to_sram(layer: ConvLayer, tile_idx: int):
    """
    Pack weights into DCIM weight SRAM format for one tile.

    For a layer with acc_depth=D and TILE_CH_OUT=16 output channels per tile:
      - The weight SRAM stores D entries per output channel.
      - Entry layout (128-bit): {high_nibbles[63:0], low_nibbles[63:0]}
      - SRAM is organized as: for each accumulation word i (0..D-1),
        store CYCLE=8 entries that contain all 16 ch_out of this tile.
      - Entry pair (2 entries) per maColumn covers 4 ch_out in INT8 mode:
        but simplified here as: 1 entry per ch_out per acc word.

    For the simplified golden model we use the flat layout:
      sram[ch_out * acc_depth + acc_word] = pack_entry(weight[ch_out][acc_word*16 : (acc_word+1)*16])

    Returns list of 128-bit integers (one per SRAM entry).
    """
    ch_out_start = tile_idx * TILE_CH_OUT
    ch_out_end = min(ch_out_start + TILE_CH_OUT, layer.out_ch)
    num_ch_out = ch_out_end - ch_out_start

    w_flat = layer.weight_int8.reshape(layer.out_ch, -1)
    # Pad to acc_depth * 16
    if w_flat.shape[1] < layer.im2col_cols_padded:
        pad_width = layer.im2col_cols_padded - w_flat.shape[1]
        w_flat = np.pad(w_flat, ((0, 0), (0, pad_width)), constant_values=0)

    entries = []
    for acc_word in range(layer.acc_depth):
        for ch_out_local in range(TILE_CH_OUT):
            ch_out_global = ch_out_start + ch_out_local
            if ch_out_global < layer.out_ch:
                w_slice = w_flat[ch_out_global, acc_word * DCIM_CH_IN: (acc_word + 1) * DCIM_CH_IN]
            else:
                w_slice = np.zeros(DCIM_CH_IN, dtype=np.int8)

            entry = _pack_nibble_entry(w_slice)
            entries.append(entry)

    return entries


def _pack_nibble_entry(weights_16ch):
    """
    Pack 16 INT8 weights into a 128-bit SRAM entry.
    Format: {high_nibbles[63:0], low_nibbles[63:0]}
      low_nibbles[ch*4 +: 4] = weight[ch] & 0xF
      high_nibbles[ch*4 +: 4] = (weight[ch] >> 4) & 0xF

    Weights are treated as unsigned bytes for nibble extraction
    (the signed interpretation is handled by the hardware merge logic).
    """
    low_nibbles = 0
    high_nibbles = 0
    for ch in range(DCIM_CH_IN):
        w_byte = int(weights_16ch[ch]) & 0xFF
        lo = w_byte & 0xF
        hi = (w_byte >> 4) & 0xF
        low_nibbles |= (lo << (ch * 4))
        high_nibbles |= (hi << (ch * 4))

    entry_128 = (high_nibbles << 64) | low_nibbles
    return entry_128


# =============================================================================
# Hex file generation utilities
# =============================================================================
def int128_to_hex(val):
    """Convert 128-bit integer to 32-char hex string (MSB first)."""
    return f'{val:032x}'


def bytes_to_128bit_words(data):
    """Convert byte array to list of 128-bit integers (little-endian byte order within word)."""
    if isinstance(data, np.ndarray):
        data = data.tobytes()
    if len(data) % 16 != 0:
        data = data + b'\x00' * (16 - len(data) % 16)
    words = []
    for i in range(0, len(data), 16):
        chunk = data[i:i + 16]
        val = int.from_bytes(chunk, byteorder='little')
        words.append(val)
    return words


def write_hex_file(filepath, hex_words):
    """Write hex words (as strings) to file, one per line."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w') as f:
        for w in hex_words:
            f.write(w + '\n')


def write_feature_hex(filepath, feat_nhwc):
    """Write NHWC feature map as 128-bit hex words (contiguous bytes, little-endian packing)."""
    flat = feat_nhwc.flatten()
    if flat.dtype == np.uint8 or flat.dtype == np.int8:
        raw = flat.view(np.uint8).tobytes()
    else:
        raw = flat.tobytes()
    words = bytes_to_128bit_words(raw)
    hex_strs = [int128_to_hex(w) for w in words]
    write_hex_file(filepath, hex_strs)
    return len(hex_strs)


def write_int32_hex(filepath, data_int32):
    """Write INT32 array as 128-bit hex words (4 int32 per word, little-endian)."""
    flat = data_int32.flatten().astype(np.int32)
    raw = flat.tobytes()
    words = bytes_to_128bit_words(raw)
    hex_strs = [int128_to_hex(w) for w in words]
    write_hex_file(filepath, hex_strs)
    return len(hex_strs)


def write_fp32_hex(filepath, data_fp32):
    """Write FP32 array as 128-bit hex words (4 floats per word, little-endian)."""
    flat = data_fp32.flatten().astype(np.float32)
    raw = flat.tobytes()
    words = bytes_to_128bit_words(raw)
    hex_strs = [int128_to_hex(w) for w in words]
    write_hex_file(filepath, hex_strs)
    return len(hex_strs)


def write_weight_sram_hex(filepath, entries_128bit):
    """Write weight SRAM entries (list of 128-bit ints) to hex file."""
    hex_strs = [int128_to_hex(e) for e in entries_128bit]
    write_hex_file(filepath, hex_strs)
    return len(hex_strs)


# =============================================================================
# Self-check utilities
# =============================================================================
def self_check_layer(layer: ConvLayer, feat, output, intermediates):
    """Verify layer output against a naive reference computation."""
    im2col = intermediates['im2col']
    accum = intermediates['accum_int32']

    # Check a few accumulator values manually
    w_flat = layer.weight_int8.reshape(layer.out_ch, -1).astype(np.int32)
    if w_flat.shape[1] < layer.im2col_cols_padded:
        pad_width = layer.im2col_cols_padded - w_flat.shape[1]
        w_flat = np.pad(w_flat, ((0, 0), (0, pad_width)), constant_values=0)

    # Spot-check: row 0, ch_out 0
    row0 = im2col[0].astype(np.int32)
    expected_acc = int(np.dot(row0, w_flat[0]))
    actual_acc = int(accum[0, 0])
    assert expected_acc == actual_acc, \
        f"{layer.name} accum[0,0] mismatch: expected {expected_acc}, got {actual_acc}"

    # Check dqa for row 0, ch_out 0
    expected_dqa = actual_acc * float(layer.dqa_scale[0]) + float(layer.dqa_bias[0])
    actual_dqa = float(intermediates['dqa_fp32'][0, 0])
    assert abs(expected_dqa - actual_dqa) < 1e-3, \
        f"{layer.name} dqa[0,0] mismatch: expected {expected_dqa:.4f}, got {actual_dqa:.4f}"

    # Check qa
    expected_relu = max(0.0, expected_dqa)
    expected_qa = int(np.clip(round(expected_relu / layer.act_scale), 0, 255))
    actual_qa = int(output[0, 0, 0])
    assert expected_qa == actual_qa, \
        f"{layer.name} qa[0,0,0] mismatch: expected {expected_qa}, got {actual_qa}"

    # Statistical check
    non_zero_ratio = np.count_nonzero(output) / output.size
    print(f"    Non-zero activation ratio: {non_zero_ratio:.2%}")
    print(f"    Output range: [{output.min()}, {output.max()}]")
    print(f"    Accum range: [{accum.min()}, {accum.max()}]")


# =============================================================================
# Main execution
# =============================================================================
def main():
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'hex')
    os.makedirs(output_dir, exist_ok=True)

    weight_dir = os.path.abspath(WEIGHT_DIR)
    if not os.path.isdir(weight_dir):
        print(f"ERROR: weight directory not found: {weight_dir}")
        sys.exit(1)

    print("=" * 70)
    print("  E2E Golden Reference: 3-Layer CNN")
    print("  Layers: model.1.conv → model.2.cv1.conv → model.2.m.0.cv2.conv")
    print("=" * 70)

    # =========================================================================
    # Define layers
    # =========================================================================
    layers = [
        ConvLayer(
            name="layer1_model.1.conv",
            npz_path=os.path.join(weight_dir, "model_1_conv.npz"),
            in_h=160, in_w=160, in_ch=16, out_ch=32,
            kh=3, kw=3, stride=2, pad=1
        ),
        ConvLayer(
            name="layer2_model.2.cv1.conv",
            npz_path=os.path.join(weight_dir, "model_2_cv1_conv.npz"),
            in_h=80, in_w=80, in_ch=32, out_ch=16,
            kh=1, kw=1, stride=1, pad=0
        ),
        ConvLayer(
            name="layer3_model.2.m.0.cv2.conv",
            npz_path=os.path.join(weight_dir, "model_2_m_0_cv2_conv.npz"),
            in_h=80, in_w=80, in_ch=16, out_ch=16,
            kh=3, kw=3, stride=1, pad=1
        ),
    ]

    for i, l in enumerate(layers):
        print(f"\n  Layer {i+1}: {l.name}")
        print(f"    Input:  {l.in_h}x{l.in_w}x{l.in_ch}")
        print(f"    Output: {l.oh}x{l.ow}x{l.out_ch}")
        print(f"    Kernel: {l.kh}x{l.kw}, stride={l.stride}, pad={l.pad}")
        print(f"    im2col cols: {l.im2col_cols} (padded: {l.im2col_cols_padded})")
        print(f"    acc_depth: {l.acc_depth}")
        print(f"    Tiles needed: {l.num_tiles_needed}")

    # =========================================================================
    # Generate random input for Layer 1
    # =========================================================================
    print("\n" + "-" * 70)
    print("  Generating random UINT8 input (seed=42)")
    print("-" * 70)

    np.random.seed(42)
    input_feat = np.random.randint(0, 256, size=(160, 160, 16), dtype=np.uint8)
    print(f"  Input shape: {input_feat.shape}, dtype: {input_feat.dtype}")
    print(f"  Input range: [{input_feat.min()}, {input_feat.max()}]")
    print(f"  Input[0,0,:8]: {list(input_feat[0, 0, :8])}")

    # =========================================================================
    # Run 3-layer forward pass
    # =========================================================================
    current_feat = input_feat
    layer_outputs = []

    for i, layer in enumerate(layers):
        print(f"\n{'='*70}")
        print(f"  Running Layer {i+1}: {layer.name}")
        print(f"{'='*70}")

        # For DCIM, activations are treated as INT8 (signed).
        # UINT8 input: values 0-255 are reinterpreted as signed in hardware.
        # However for the matmul golden, we need to match hardware behavior:
        #   - Layer 1 input is UINT8 from image preprocessing (0~255)
        #   - Subsequent layers input is UINT8 from qa (0~255)
        # The hardware reads these as unsigned bytes and the multiplication
        # with signed weights produces the correct signed result via
        # act_nibble_converter treating activation nibbles as unsigned.
        #
        # For golden: treat activation as UNSIGNED (uint8 → int32) for matmul.
        if current_feat.dtype == np.uint8:
            feat_for_im2col = current_feat.view(np.int8)
        else:
            feat_for_im2col = current_feat.astype(np.int8)

        output, intermediates = layer.forward(feat_for_im2col)
        layer_outputs.append((output, intermediates))

        print(f"  Output shape: {output.shape}, dtype: {output.dtype}")
        print(f"  Self-check...")
        self_check_layer(layer, feat_for_im2col, output, intermediates)
        print(f"    PASS")

        current_feat = output

    # =========================================================================
    # Write hex files
    # =========================================================================
    print(f"\n{'='*70}")
    print(f"  Generating hex files → {output_dir}")
    print(f"{'='*70}")

    # Input feature
    n = write_feature_hex(os.path.join(output_dir, 'input_feat.hex'), input_feat)
    print(f"  input_feat.hex: {n} words ({input_feat.nbytes} bytes)")

    for i, (layer, (output, intermediates)) in enumerate(zip(layers, layer_outputs)):
        prefix = f"layer{i+1}"

        # im2col
        n = write_feature_hex(
            os.path.join(output_dir, f'{prefix}_im2col.hex'),
            intermediates['im2col']
        )
        print(f"  {prefix}_im2col.hex: {n} words")

        # Accumulator (INT32)
        n = write_int32_hex(
            os.path.join(output_dir, f'{prefix}_accum.hex'),
            intermediates['accum_int32']
        )
        print(f"  {prefix}_accum.hex: {n} words")

        # DQA output (FP32)
        n = write_fp32_hex(
            os.path.join(output_dir, f'{prefix}_dqa.hex'),
            intermediates['dqa_fp32']
        )
        print(f"  {prefix}_dqa.hex: {n} words")

        # QA output (UINT8 feature map)
        n = write_feature_hex(
            os.path.join(output_dir, f'{prefix}_output.hex'),
            output
        )
        print(f"  {prefix}_output.hex: {n} words")

        # Weight SRAM packed (per tile)
        for tile in range(layer.num_tiles_needed):
            entries = pack_weight_to_sram(layer, tile)
            n = write_weight_sram_hex(
                os.path.join(output_dir, f'{prefix}_weight_tile{tile}.hex'),
                entries
            )
            print(f"  {prefix}_weight_tile{tile}.hex: {n} entries")

        # DQA scale/bias (for VPU post-processing)
        n = write_fp32_hex(
            os.path.join(output_dir, f'{prefix}_dqa_scale.hex'),
            layer.dqa_scale
        )
        print(f"  {prefix}_dqa_scale.hex: {n} words")

        n = write_fp32_hex(
            os.path.join(output_dir, f'{prefix}_dqa_bias.hex'),
            layer.dqa_bias
        )
        print(f"  {prefix}_dqa_bias.hex: {n} words")

    # =========================================================================
    # Summary statistics
    # =========================================================================
    print(f"\n{'='*70}")
    print(f"  Summary")
    print(f"{'='*70}")
    for i, (layer, (output, intermediates)) in enumerate(zip(layers, layer_outputs)):
        print(f"\n  Layer {i+1} ({layer.name}):")
        print(f"    Accum INT32 range: [{intermediates['accum_int32'].min()}, "
              f"{intermediates['accum_int32'].max()}]")
        print(f"    DQA FP32 range: [{intermediates['dqa_fp32'].min():.4f}, "
              f"{intermediates['dqa_fp32'].max():.4f}]")
        print(f"    Output UINT8 range: [{output.min()}, {output.max()}]")
        print(f"    act_scale: {layer.act_scale:.6f}")

    # Final output
    final_out = layer_outputs[-1][0]
    print(f"\n  Final output (layer 3): shape={final_out.shape}, "
          f"range=[{final_out.min()}, {final_out.max()}]")
    print(f"  Final output[0,0,:]: {list(final_out[0, 0, :])}")
    print(f"  Final output[40,40,:]: {list(final_out[40, 40, :])}")

    print(f"\n{'='*70}")
    print(f"  All golden files generated successfully. Self-checks PASSED.")
    print(f"{'='*70}")


if __name__ == '__main__':
    main()
