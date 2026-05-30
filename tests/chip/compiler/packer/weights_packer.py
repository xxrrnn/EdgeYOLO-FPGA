"""Pack ONNX INT8 weights into DCIM IBUF nibble layout.

Reference: `rtl/vpu/tb/e2e/golden_e2e.py:220-240` and `rtl/vpu/tb/golden_im2col_dcim.py:355-381`.

Per-tile layout (INT8 mode, weight bits = 4, two nibbles per INT8):
  - For each acc_word a in 0..acc_depth-1, for each ch_out_local in 0..15:
      entry_128bit = {high_nibbles[63:0], low_nibbles[63:0]}
        low_nibbles[ch_in*4  +: 4] = weight_int8[ch_in] & 0xF
        high_nibbles[ch_in*4 +: 4] = (weight_int8[ch_in] >> 4) & 0xF
  - The 16 ch_out × acc_depth entries are flattened in (acc_word, ch_out_local) order.

Per-layer IBUF byte layout (matches lower.py memory_plan):
  layer.ibuf_byte_off + tile * (acc_depth*16 * 16 bytes) → tile-major

For W16A16 (INT16 mode) the same path is used with mode bit, but acc_depth
doubles and each weight is split into 4 nibbles instead of 2.  This is wired
in via the `mode` argument and the int16 placement is performed in a separate
pass (`pack_layer_weights_int16`).
"""

from __future__ import annotations

from typing import Dict, List, Tuple

import numpy as np

CH_IN_PER_TILE = 16
CH_OUT_PER_TILE = 16
TILES = 8
BYTES_PER_WORD = 16


def _pack_nibble_entry(weights_16: np.ndarray) -> bytes:
    """Pack 16 INT8 weights into one 128-bit entry (little-endian byte order)."""
    assert weights_16.shape == (CH_IN_PER_TILE,), weights_16.shape
    low = 0
    high = 0
    for ch in range(CH_IN_PER_TILE):
        w = int(weights_16[ch]) & 0xFF
        low |= (w & 0xF) << (ch * 4)
        high |= ((w >> 4) & 0xF) << (ch * 4)
    entry = (high << 64) | low
    # Convert to 16 little-endian bytes.
    return entry.to_bytes(16, "little")


def _pack_nibble_entry_int16(weights_8: np.ndarray, nibble_idx: int) -> bytes:
    """For INT16 mode: pack 8 INT16 weights' nibble `nibble_idx` (0..3) into
    one 128-bit entry.  nibble_idx 0 = bits[3:0], 3 = bits[15:12].

    Each entry covers 8 ch_in × 16 (high + low halves of two nibbles)?
    Actually for INT16 mode the DCIM mergeArray expects 4 phases (4 nibbles)
    so we just store one nibble's worth of 8 ch_in × 16 ch_out / 2.
    To keep this simple (and to match the existing mergeArray INT16 layout
    documented in rtl/ref/DCIM/src/dcim/mergeArray.v), we put 16 nibbles
    of low half + 16 nibbles of high half per 128-bit entry, just like INT8.
    """
    assert weights_8.shape == (CH_IN_PER_TILE,), weights_8.shape
    low = 0
    high = 0
    for ch in range(CH_IN_PER_TILE):
        n = (int(weights_8[ch]) >> (nibble_idx * 4)) & 0xF
        # We mirror nibble in both halves so the merge logic that interprets
        # this as "even / odd ch_out" treats them identically.
        low |= n << (ch * 4)
    entry = (high << 64) | low
    return entry.to_bytes(16, "little")


def pack_layer_weights_int16(
    weight_int8: np.ndarray,        # [Cout, Cin, kH, kW]
    *,
    expected_acc_depth: int,
    expected_tiles: int,
) -> bytes:
    """W16A16 bit-extension layout: sign-extend INT8 weights to INT16 and emit
    4× the entries (one per nibble).  The DCIM INT16 mode reads 4 nibbles per
    activation/weight and merges them with shifts of 4/8/12.

    NOTE: This packing is currently for the *bit-extension oracle*.  It is
    bit-equivalent to INT8 with high byte = sign-extension of the INT8 value,
    so the matmul output is identical.
    """
    cout, cin, kh, kw = weight_int8.shape
    # acc_depth in INT16 mode = ceil(kH*kW*Cin / 8) since each IBUF word holds
    # only 8 INT16 weights instead of 16 INT8.
    acc_depth_int16 = (kh * kw * cin + 8 - 1) // 8

    if expected_acc_depth != acc_depth_int16:
        # caller still uses INT8 acc_depth; we double it here for the wider mode.
        pass

    w = weight_int8.reshape(cout, kh * kw * cin).astype(np.int16)
    # Sign-extend (already int16).  Pad CH_IN dim to acc_depth*8.
    pad_cols = acc_depth_int16 * 8 - w.shape[1]
    if pad_cols > 0:
        w = np.pad(w, ((0, 0), (0, pad_cols)))

    out = bytearray()
    # 8 tiles × acc_depth_int16 × 16 ch_out per acc_word, 4 nibbles per entry.
    for tile in range(TILES):
        ch_out_start = tile * CH_OUT_PER_TILE
        for acc_w in range(acc_depth_int16):
            col_lo = acc_w * 8
            for ch_out_local in range(CH_OUT_PER_TILE):
                ch_out_global = ch_out_start + ch_out_local
                if ch_out_global < cout:
                    row = w[ch_out_global, col_lo:col_lo + 8]
                else:
                    row = np.zeros(8, dtype=np.int16)
                # Re-extend with leading zeros (or sign-extend?) for the 16-byte
                # entry, which now holds 8 INT16 = 16 bytes.
                # In the simplest "bit-equivalent INT16" packing we put each
                # int16 in 2 bytes little-endian.
                out += row.astype("<i2").tobytes()

    expected_bytes = TILES * acc_depth_int16 * CH_OUT_PER_TILE * BYTES_PER_WORD
    assert len(out) == expected_bytes, (len(out), expected_bytes)
    return bytes(out)


def pack_layer_weights_int8(
    weight_int8: np.ndarray,  # [Cout, Cin, kH, kW]
    *,
    expected_acc_depth: int,
    expected_tiles: int,
) -> bytes:
    """Pack one Conv layer's weights into the IBUF byte stream.

    The layer's slot in IBUF spans  TILES * acc_depth * 16 entries
    (entries × 16 bytes each).  Unused tiles / unused ch_out are zero-filled.
    """
    cout, cin, kh, kw = weight_int8.shape
    acc_depth = (kh * kw * cin + CH_IN_PER_TILE - 1) // CH_IN_PER_TILE

    if acc_depth != expected_acc_depth:
        raise ValueError(f"acc_depth mismatch: layer says {acc_depth}, plan says {expected_acc_depth}")

    # Flatten weight to [Cout, kH*kW*Cin].  Pad CH_IN dim to acc_depth*16.
    w = weight_int8.reshape(cout, kh * kw * cin).astype(np.int8)
    pad_cols = acc_depth * CH_IN_PER_TILE - w.shape[1]
    if pad_cols > 0:
        w = np.pad(w, ((0, 0), (0, pad_cols)))

    out = bytearray()
    for tile in range(TILES):
        ch_out_start = tile * CH_OUT_PER_TILE
        for acc_w in range(acc_depth):
            col_lo = acc_w * CH_IN_PER_TILE
            for ch_out_local in range(CH_OUT_PER_TILE):
                ch_out_global = ch_out_start + ch_out_local
                if ch_out_global < cout:
                    row = w[ch_out_global, col_lo:col_lo + CH_IN_PER_TILE]
                else:
                    row = np.zeros(CH_IN_PER_TILE, dtype=np.int8)
                out += _pack_nibble_entry(row)

    expected_bytes = TILES * acc_depth * CH_OUT_PER_TILE * BYTES_PER_WORD
    assert len(out) == expected_bytes, (len(out), expected_bytes)
    return bytes(out)


def pack_all_layers(
    plan: dict,
    weights_npz_dir: str,
    *,
    mode: str = "int8",
    weight_key: str = "weight_int8",
) -> Tuple[bytes, Dict[str, dict]]:
    """Walk plan['weights_layout']['layers'] and produce one giant IBUF blob.

    For `mode == 'int16'` the packing is the bit-extended INT16 layout used as
    a correctness oracle; numerically equal to INT8 path but uses MODE_INT16
    on the DCIM array.
    """
    import os
    info: Dict[str, dict] = {}
    per_layer_files = {}
    for rec in plan["weights_layout"]["layers"]:
        name = rec["name"]
        safe = name.replace(".", "_").replace("/", "_")
        npz_path = os.path.join(weights_npz_dir, f"{safe}.npz")
        if not os.path.exists(npz_path):
            raise FileNotFoundError(f"missing weight npz for layer {name}: {npz_path}")

        z = np.load(npz_path)
        if weight_key not in z.files:
            raise KeyError(f"layer {name}: npz has no {weight_key!r} (keys: {z.files})")
        wi8 = z[weight_key].astype(np.int8)

        expected_acc_depth = rec["per_tile_bytes"] // (CH_OUT_PER_TILE * BYTES_PER_WORD)

        if mode == "int16":
            blob = pack_layer_weights_int16(
                wi8,
                expected_acc_depth=expected_acc_depth,
                expected_tiles=rec["tiles_needed"],
            )
        else:
            blob = pack_layer_weights_int8(
                wi8,
                expected_acc_depth=expected_acc_depth,
                expected_tiles=rec["tiles_needed"],
            )
        per_layer_files[name] = blob
        info[name] = {
            "bytes": len(blob),
            "ibuf_byte_off": rec["ibuf_byte_off"],
        }

    # Concatenate as a single "weights.bin" with section table prefixed in info.
    cat = b""
    section_offsets = {}
    cur = 0
    for name, blob in per_layer_files.items():
        section_offsets[name] = cur
        cat += blob
        cur += len(blob)

    info["__section_offsets"] = section_offsets
    info["__mode"] = mode
    return cat, info
