"""Static memory planner for OBUF / IBUF / WB allocations."""

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
    """OBUF, IBUF, WB byte-region allocator.

    Strategy (from plan §4):
      OBUF: ping (0..4MB) / pong (4..8MB) / im2col scratch (8..12MB) / skip (12..15.9375MB) /
            wb_scratch (15.9375..16MB)
      IBUF: bump-pointer for current-layer weights (reset before each layer)
      WB:   bump-pointer per layer (reset before each layer)
    """

    def __init__(self, address_map: Dict[str, int]):
        obuf_size = int(address_map["obuf_size"])
        ibuf_size = int(address_map["ibuf_size"])
        wb_size = int(address_map["wb_size"])

        # OBUF regions (byte offsets relative to obuf_base)
        self.obuf_ping = Region("obuf_ping", 0x000000, 0x400000)
        self.obuf_pong = Region("obuf_pong", 0x400000, 0x800000)
        self.obuf_im2col = Region("obuf_im2col", 0x800000, 0xC00000)
        self.obuf_skip = Region("obuf_skip", 0xC00000, 0xFF0000)
        self.obuf_wb_scratch = Region("obuf_wb_scratch", 0xFF0000, obuf_size)

        # IBUF whole region (byte offset relative to ibuf_base)
        self.ibuf = Region("ibuf", 0x000000, ibuf_size)

        # WB whole region (byte offset relative to wb_base)
        self.wb = Region("wb", 0x000000, wb_size)

        self._ping_pong_toggle = 0    # 0 → input from ping output to pong; 1 → swap

        # per-tensor allocation table for the IR
        self.tensor_offset: Dict[str, Tuple[str, int, int]] = {}

    # -- OBUF feature buffer (double-buffered) --
    def assign_layer_ping_pong(self, in_bytes: int, out_bytes: int) -> Tuple[int, int]:
        """Return (in_offset_in_obuf, out_offset_in_obuf) for one layer.

        The two halves alternate so that consecutive layers can be chained
        without copying.  Sizes must fit in 4MB each.
        """
        if in_bytes > (self.obuf_ping.hi - self.obuf_ping.lo):
            raise OutOfBuffer(
                f"layer input {in_bytes} bytes exceeds OBUF ping/pong region "
                f"{self.obuf_ping.hi - self.obuf_ping.lo} bytes"
            )
        if out_bytes > (self.obuf_ping.hi - self.obuf_ping.lo):
            raise OutOfBuffer(
                f"layer output {out_bytes} bytes exceeds OBUF ping/pong region"
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

    def alloc_wb_scratch(self, nbytes: int) -> int:
        self.obuf_wb_scratch.reset()
        return self.obuf_wb_scratch.lo + self.obuf_wb_scratch.alloc(nbytes)

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
