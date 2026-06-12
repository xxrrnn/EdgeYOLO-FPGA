"""Static memory planner for VPU_BUF / IBUF / WB allocations (chip-v2).

In chip-v2, the shared 16MB OBUF is replaced by:
  - vpu_buf (4MB): VPU local read/write buffer
  - tile_obuf (256KB × 4): per-tile DCIM output buffers

VPU operations (im2col, dqa, qa, mp, us, ad) use vpu_buf exclusively.
DCIM results land in tile_obuf and are copied to vpu_buf via CDMA.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from ..errors import OutOfBuffer


@dataclass
class Region:
    name: str
    lo: int
    hi: int
    cursor: int = 0  # next free byte (relative to lo)

    def __post_init__(self):
        if self.cursor == 0:
            self.cursor = 0
        if self.hi <= self.lo:
            raise ValueError(f"region {self.name}: hi must be > lo")

    @property
    def free(self) -> int:
        return (self.hi - self.lo) - self.cursor

    def alloc(self, n_bytes: int, align: int = 16) -> int:
        """Bump-pointer allocate n_bytes within the region.  Returns BYTE offset
        relative to the region's lo address."""
        if align <= 0:
            align = 1
        # round cursor up to alignment
        cur = (self.cursor + align - 1) & ~(align - 1)
        if cur + n_bytes > (self.hi - self.lo):
            raise OutOfBuffer(
                f"region {self.name!r}: requested {n_bytes} bytes at offset {cur}, "
                f"but only {self.free} bytes free of {self.hi - self.lo}"
            )
        self.cursor = cur + n_bytes
        return cur

    def reset(self):
        self.cursor = 0


@dataclass
class Allocation:
    region: str
    offset: int     # byte offset INSIDE the region (0-based)
    nbytes: int


class MemoryPlanner:
    """VPU_BUF, IBUF, WB byte-region allocator.

    Strategy (chip-v2, 4MB vpu_buf):
      VPU_BUF: ping (0..1.5MB) / pong (1.5..3MB) / im2col scratch (3..3.75MB) / skip (3.75..4MB)
      IBUF: bump-pointer for current-layer weights (reset before each layer)
      WB:   bump-pointer per layer (reset before each layer)
    """

    def __init__(self, address_map: Dict[str, int]):
        obuf_size = int(address_map.get("vpu_buf_size", address_map.get("obuf_size")))
        ibuf_size = int(address_map["ibuf_size"])
        wb_size = int(address_map["wb_size"])

        # VPU_BUF regions (byte offsets relative to vpu_buf_base)
        # 4MB = 0x400000: split into ping/pong/im2col/skip
        self.obuf_ping = Region("vpu_buf_ping", 0x000000, 0x180000)       # 1.5MB
        self.obuf_pong = Region("vpu_buf_pong", 0x180000, 0x300000)       # 1.5MB
        self.obuf_im2col = Region("vpu_buf_im2col", 0x300000, 0x3C0000)   # 768KB
        self.obuf_skip = Region("vpu_buf_skip", 0x3C0000, obuf_size)      # 256KB

        # IBUF whole region (byte offset relative to ibuf_base)
        self.ibuf = Region("ibuf", 0x000000, ibuf_size)

        # WB whole region (byte offset relative to wb_base)
        self.wb = Region("wb", 0x000000, wb_size)

        self._ping_pong_toggle = 0    # 0 → input from ping output to pong; 1 → swap

        # per-tensor allocation table for the IR
        self.tensor_offset: Dict[str, Tuple[str, int, int]] = {}

    # -- VPU_BUF feature buffer (double-buffered) --
    def assign_layer_ping_pong(self, in_bytes: int, out_bytes: int) -> Tuple[int, int]:
        """Return (in_offset_in_vpu_buf, out_offset_in_vpu_buf) for one layer.

        The two halves alternate so that consecutive layers can be chained
        without copying.  Sizes must fit in 1.5MB each.
        """
        if in_bytes > (self.obuf_ping.hi - self.obuf_ping.lo):
            raise OutOfBuffer(
                f"layer input {in_bytes} bytes exceeds VPU_BUF ping/pong region "
                f"{self.obuf_ping.hi - self.obuf_ping.lo} bytes"
            )
        if out_bytes > (self.obuf_ping.hi - self.obuf_ping.lo):
            raise OutOfBuffer(
                f"layer output {out_bytes} bytes exceeds VPU_BUF ping/pong region"
            )
        if self._ping_pong_toggle == 0:
            in_off = self.obuf_ping.lo
            out_off = self.obuf_pong.lo
        else:
            in_off = self.obuf_pong.lo
            out_off = self.obuf_ping.lo
        self._ping_pong_toggle ^= 1
        return in_off, out_off

    def alloc_im2col(self, nbytes: int) -> int:
        self.obuf_im2col.reset()
        return self.obuf_im2col.lo + self.obuf_im2col.alloc(nbytes)

    def alloc_skip(self, nbytes: int) -> int:
        return self.obuf_skip.lo + self.obuf_skip.alloc(nbytes)

    # -- IBUF (weights for current layer) --
    def reset_ibuf(self):
        self.ibuf.reset()

    def alloc_ibuf(self, nbytes: int, align: int = 16) -> int:
        return self.ibuf.alloc(nbytes, align)

    # -- WB (scale/bias for current layer) --
    def reset_wb(self):
        self.wb.reset()

    def alloc_wb(self, nbytes: int, align: int = 16) -> int:
        return self.wb.alloc(nbytes, align)
