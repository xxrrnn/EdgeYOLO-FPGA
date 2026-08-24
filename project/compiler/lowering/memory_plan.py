"""Static memory planner for VPU_BUF / IBUF / WB allocations (chip-v2).

In chip-v2:
  - vpu_buf (8MB): VPU local read/write buffer, exclusively used by each layer
  - tile_obuf (256KB × 8): per-tile DCIM output buffers

Because layers execute sequentially (not concurrently), each layer is free to
use the entire VPU_BUF.  There is no need to carve out fixed ping/pong slots.

VPU_BUF layout per layer (all offsets relative to VPU_BUF_BASE = 0x1_0200_0000):
  [0x000000 .. in_end)    -- input activation (FP32, INT8, or INT32 depending on stage)
  [0x400000 .. out_end)   -- output activation (always starts at 4MB boundary)
  [0x400000 .. im2_end)   -- im2col scratch (overlaps with output half; safe because
                             im2col finishes writing before DCIM output is DMA'd in)
  skip connections are allocated from the upper half at alloc_skip() call time.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Tuple

from ..errors import OutOfBuffer


# ---------------------------------------------------------------------------
# Half-size of VPU_BUF: each "slot" (input or output) gets this many bytes.
# Largest single-layer tensor in YOLOv5n (320×320 input):
#   model.0 out: 160×160×16×4B = 1,638,400 B  → fits in 4MB
#   model.3 in:  160×160×32×4B = 3,276,800 B  → fits in 4MB   (largest FP32 input)
#   im2col scratch for model.0: 160×160×3×6×6×1B = 2,764,800 B → fits in 4MB
# So 4MB per slot is sufficient for all YOLOv5n layers at 320×320 input.
_HALF = 0x400000  # 4MB

# Skip connections (residual saves) live at the top of VPU_BUF to avoid
# colliding with input/output.  We give them the upper 4MB minus small guard.
_SKIP_BASE = 0x400000   # skip connections borrow the output slot between layers
                         # (safe: saved before next layer overwrites it)


@dataclass
class Region:
    name: str
    lo: int
    hi: int
    cursor: int = 0  # next free byte (relative to lo)

    def __post_init__(self):
        if self.hi <= self.lo:
            raise ValueError(f"region {self.name}: hi must be > lo")

    @property
    def free(self) -> int:
        return (self.hi - self.lo) - self.cursor

    def alloc(self, n_bytes: int, align: int = 16) -> int:
        """Bump-pointer allocate; returns byte offset relative to region lo."""
        if align <= 0:
            align = 1
        cur = (self.cursor + align - 1) & ~(align - 1)
        if cur + n_bytes > (self.hi - self.lo):
            raise OutOfBuffer(
                f"region {self.name!r}: requested {n_bytes}B at offset 0x{cur:x}, "
                f"only {self.free}B free of {self.hi - self.lo}B"
            )
        self.cursor = cur + n_bytes
        return cur

    def reset(self):
        self.cursor = 0


class MemoryPlanner:
    """VPU_BUF, IBUF, WB allocator.

    VPU_BUF (8MB) is divided into two 4MB halves that alternate each layer:
      - "A" half: 0x000000..0x3FFFFF  (input of even layers / output of odd layers)
      - "B" half: 0x400000..0x7FFFFF  (output of even layers / input of odd layers)

    im2col scratch always lives in the *output* half (B or A depending on
    toggle) because im2col writes finish before the DCIM→VPU_BUF CDMA fills
    the same region with INT32 output — they do not race.

    Skip connections (for residual saves) are bump-allocated from the *input*
    half at save time, as they are written before the layer overwrites them.
    The caller is responsible for not overflowing the 4MB half.
    """

    def __init__(self, address_map: Dict[str, int]):
        obuf_size = int(address_map.get("vpu_buf_size", address_map.get("obuf_size", _HALF * 2)))
        ibuf_size = int(address_map["ibuf_size"])
        wb_size   = int(address_map["wb_size"])

        self._vpu_buf_size = obuf_size
        self._half = min(_HALF, obuf_size // 2)

        # IBUF / WB per-layer bump allocators
        self.ibuf = Region("ibuf", 0, ibuf_size)
        self.wb   = Region("wb",   0, wb_size)

        self._ping_pong_toggle = 0   # 0: in=A(0), out=B(half); 1: in=B(half), out=A(0)

        # Skip-connection allocator: bump from the *top* of VPU_BUF downward.
        # We keep it simple: allocate from 0x600000 upward (third quadrant of 8MB buf).
        self._skip_base  = (obuf_size * 3) // 4   # starts at 6MB offset in 8MB buf
        self._skip_cursor = self._skip_base

    # ------------------------------------------------------------------
    # VPU_BUF feature-map allocation
    # ------------------------------------------------------------------

    def assign_layer_ping_pong(self, in_bytes: int, out_bytes: int) -> Tuple[int, int]:
        """Return (in_off, out_off) relative to VPU_BUF_BASE for one layer.

        Each half is self._half bytes (4MB).  Alternates A/B each call so
        consecutive layers chain without host-side copies.
        """
        half = self._half
        if in_bytes > half:
            raise OutOfBuffer(
                f"layer input {in_bytes}B ({in_bytes/1e6:.2f}MB) exceeds "
                f"VPU_BUF half {half}B ({half/1e6:.1f}MB); reduce input resolution"
            )
        if out_bytes > half:
            raise OutOfBuffer(
                f"layer output {out_bytes}B ({out_bytes/1e6:.2f}MB) exceeds "
                f"VPU_BUF half {half}B ({half/1e6:.1f}MB); reduce output channels"
            )
        if self._ping_pong_toggle == 0:
            in_off, out_off = 0, half
        else:
            in_off, out_off = half, 0
        self._ping_pong_toggle ^= 1
        return in_off, out_off

    def alloc_im2col(self, nbytes: int) -> int:
        """im2col scratch lives at the START of the current output half.

        This is safe: im2col finishes writing before DCIM output is DMA'd into
        the same region (DCIM runs AFTER im2col in the ISA sequence).
        The im2col region resets each layer (no accumulation across layers).
        """
        half = self._half
        # Current output half: same logic as assign_layer_ping_pong but we
        # read back what the LAST call chose.  The toggle was already flipped
        # after assign_layer_ping_pong, so current output is the OLD toggle's out.
        cur_out = half if (self._ping_pong_toggle == 1) else 0
        if nbytes > half:
            raise OutOfBuffer(
                f"im2col scratch {nbytes}B exceeds VPU_BUF half {half}B; "
                "tile the output H dimension"
            )
        return cur_out

    def alloc_skip(self, nbytes: int) -> int:
        """Allocate a skip-connection save slot in the upper region of VPU_BUF."""
        off = self._skip_cursor
        if off + nbytes > self._vpu_buf_size:
            raise OutOfBuffer(
                f"skip allocation overflow: {nbytes}B at 0x{off:x} exceeds "
                f"VPU_BUF 0x{self._vpu_buf_size:x}"
            )
        self._skip_cursor += (nbytes + 15) & ~15
        return off

    def reset_skip(self):
        """Call between networks to reclaim skip-connection slots."""
        self._skip_cursor = self._skip_base

    # ------------------------------------------------------------------
    # IBUF / WB (reset per layer)
    # ------------------------------------------------------------------

    def reset_ibuf(self):
        self.ibuf.reset()

    def alloc_ibuf(self, nbytes: int, align: int = 16) -> int:
        return self.ibuf.alloc(nbytes, align)

    def reset_wb(self):
        self.wb.reset()

    def alloc_wb(self, nbytes: int, align: int = 16) -> int:
        return self.wb.alloc(nbytes, align)
