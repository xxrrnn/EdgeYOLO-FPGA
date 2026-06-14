#!/usr/bin/env python3
"""Read selected Verilog `define values from rtl/chip/chip_defines.vh.

Python golden/test/compiler utilities should import this file instead of
hard-coding DCIM geometry constants.  The parser intentionally supports the
simple macro forms used by chip_defines.vh: decimal integers, Verilog based
literals, aliases, and basic arithmetic expressions over previously parsed
macros.
"""
from __future__ import annotations

import ast
import operator
import os
import re
from typing import Dict, Mapping

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CHIP_DEFINES = os.path.join(REPO_ROOT, "rtl", "chip", "chip_defines.vh")

_DEFINE_RE = re.compile(r"^\s*`define\s+(\w+)\s+(.+?)\s*(?://.*)?$")
_BASED_RE = re.compile(r"(?P<bits>\d+)?'(?P<base>[bBoOdDhH])(?P<value>[0-9a-fA-F_xXzZ]+)")
_MACRO_RE = re.compile(r"`([A-Za-z_]\w*)")

_BIN_OPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.FloorDiv: operator.floordiv,
    ast.Div: operator.floordiv,
    ast.Mod: operator.mod,
    ast.LShift: operator.lshift,
    ast.RShift: operator.rshift,
    ast.BitOr: operator.or_,
    ast.BitAnd: operator.and_,
    ast.BitXor: operator.xor,
}
_UNARY_OPS = {
    ast.UAdd: operator.pos,
    ast.USub: operator.neg,
    ast.Invert: operator.invert,
}


def _convert_based_literals(expr: str) -> str:
    def repl(match: re.Match[str]) -> str:
        base = match.group("base").lower()
        value = match.group("value").replace("_", "")
        value = re.sub(r"[xXzZ]", "0", value)
        radix = {"b": 2, "o": 8, "d": 10, "h": 16}[base]
        return str(int(value, radix))

    return _BASED_RE.sub(repl, expr)


def _safe_eval(expr: str) -> int:
    tree = ast.parse(expr, mode="eval")

    def eval_node(node: ast.AST) -> int:
        if isinstance(node, ast.Expression):
            return eval_node(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, int):
            return int(node.value)
        if isinstance(node, ast.Num):
            return int(node.n)
        if isinstance(node, ast.BinOp) and type(node.op) in _BIN_OPS:
            return _BIN_OPS[type(node.op)](eval_node(node.left), eval_node(node.right))
        if isinstance(node, ast.UnaryOp) and type(node.op) in _UNARY_OPS:
            return _UNARY_OPS[type(node.op)](eval_node(node.operand))
        raise ValueError(f"unsupported expression node: {ast.dump(node)}")

    return eval_node(tree)


def _resolve_expr(expr: str, values: Mapping[str, int]) -> int:
    expr = expr.strip()
    expr = _convert_based_literals(expr)
    expr = _MACRO_RE.sub(lambda m: str(values[m.group(1)]), expr)
    expr = expr.replace("$clog2", "clog2")

    while "clog2" in expr:
        expr = re.sub(r"clog2\(([^()]+)\)", lambda m: str((int(_safe_eval(m.group(1))) - 1).bit_length()), expr)

    return int(_safe_eval(expr))


def load_chip_defines(path: str = CHIP_DEFINES) -> Dict[str, int]:
    values: Dict[str, int] = {}
    pending: Dict[str, str] = {}

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            match = _DEFINE_RE.match(line)
            if not match:
                continue
            name, expr = match.groups()
            expr = expr.strip()
            if not expr:
                continue
            try:
                values[name] = _resolve_expr(expr, values)
            except Exception:
                pending[name] = expr

    changed = True
    while pending and changed:
        changed = False
        for name, expr in list(pending.items()):
            try:
                values[name] = _resolve_expr(expr, values)
            except Exception:
                continue
            del pending[name]
            changed = True

    return values


_CFG = load_chip_defines()

MODE_INT4 = _CFG["MODE_INT4"]
MODE_INT8 = _CFG["MODE_INT8"]
MODE_INT16 = _CFG["MODE_INT16"]
MODE_UINT4 = _CFG["MODE_UINT4"]
MODE_UINT8 = _CFG["MODE_UINT8"]
MODE_UINT16 = _CFG["MODE_UINT16"]

DCIM_NUM_TILES = _CFG["DCIM_NUM_TILES"]
DCIM_WD1 = _CFG["DCIM_WD1"]
DCIM_CH_IN = _CFG["DCIM_CH_IN"]
DCIM_CH_OUT = _CFG["DCIM_CH_OUT"]
DCIM_SRAM_DP = _CFG["DCIM_SRAM_DP"]
DCIM_CYCLE = _CFG["DCIM_CYCLE"]
DCIM_ACC_MAX = _CFG["DCIM_ACC_MAX"]
DCIM_BUF_DATA_WIDTH = _CFG["DCIM_BUF_DATA_WIDTH"]
DCIM_IBUF_ADDR_WIDTH = _CFG["DCIM_IBUF_ADDR_WIDTH"]
DCIM_OBUF_ADDR_WIDTH = _CFG["DCIM_OBUF_ADDR_WIDTH"]

BYTES_PER_WORD = DCIM_BUF_DATA_WIDTH // 8
RESULTS_PER_WORD = DCIM_BUF_DATA_WIDTH // 32
DCIM_INT8_OUT_CH_PER_TILE = DCIM_CH_OUT // 2
DCIM_INT16_OUT_CH_PER_TILE = DCIM_CH_OUT // 4
DCIM_INT8_OUT_WORDS_PER_TILE = (DCIM_INT8_OUT_CH_PER_TILE + RESULTS_PER_WORD - 1) // RESULTS_PER_WORD
DCIM_INT16_OUT_WORDS_PER_TILE = (DCIM_INT16_OUT_CH_PER_TILE + RESULTS_PER_WORD - 1) // RESULTS_PER_WORD
DCIM_INT8_ACT_WORDS = (DCIM_CH_IN + BYTES_PER_WORD - 1) // BYTES_PER_WORD
DCIM_INT16_ACT_WORDS = (DCIM_CH_IN * 2 + BYTES_PER_WORD - 1) // BYTES_PER_WORD

DCIM_IBUF_AXI_BRAM_READ_LATENCY = _CFG["DCIM_IBUF_AXI_BRAM_READ_LATENCY"]
DCIM_OBUF_AXI_BRAM_READ_LATENCY = _CFG["DCIM_OBUF_AXI_BRAM_READ_LATENCY"]


def _cfg(name: str) -> int:
    return _CFG[name]


def require_consistent() -> None:
    sram_wd = DCIM_CH_IN * DCIM_CH_OUT * DCIM_WD1 // DCIM_CYCLE
    if sram_wd != DCIM_BUF_DATA_WIDTH:
        raise ValueError(
            f"DCIM SRAM_WD mismatch: CH_IN*CH_OUT*WD1/CYCLE={sram_wd}, "
            f"BUF_DATA_WIDTH={DCIM_BUF_DATA_WIDTH}"
        )

    col_w = _cfg("DCIM_BUF_COL_WIDTH")
    num_col = _cfg("DCIM_BUF_NUM_COL")
    bpw = _cfg("DCIM_BUF_BYTES_PER_WORD")
    if DCIM_BUF_DATA_WIDTH != num_col * col_w:
        raise ValueError("DCIM_BUF_DATA_WIDTH != NUM_COL * COL_WIDTH (bits)")
    if bpw != DCIM_BUF_DATA_WIDTH // col_w:
        raise ValueError("DCIM_BUF_BYTES_PER_WORD != DATA_WIDTH / COL_WIDTH")
    if bpw != num_col:
        raise ValueError("DCIM_BUF_BYTES_PER_WORD != NUM_COL (1 byte per column)")

    ibuf_bpw = _cfg("DCIM_BUF_BYTES_PER_WORD")
    # chip-v3: tile_ibuf per-tile XPM，IBUF_SIZE_BYTES 指向 TILE_IBUF_SIZE_BYTES
    if _cfg("DCIM_IBUF_SIZE_BYTES") != (1 << DCIM_IBUF_ADDR_WIDTH) * ibuf_bpw:
        raise ValueError("DCIM_IBUF_SIZE_BYTES formula mismatch")
    # chip-v3: tile_obuf per-tile XPM，TILE_OBUF_SIZE_BYTES
    if _cfg("DCIM_TILE_OBUF_SIZE_BYTES") != (1 << DCIM_OBUF_ADDR_WIDTH) * ibuf_bpw:
        raise ValueError("DCIM_TILE_OBUF_SIZE_BYTES formula mismatch")

    # chip-v3: tile_ibuf XPM 无 bank 结构，直接校验 RD_LATENCY 与 AXI_BRAM_READ_LATENCY 一致
    tile_ibuf_rd_lat = _cfg("DCIM_TILE_IBUF_RD_LATENCY")
    if DCIM_IBUF_AXI_BRAM_READ_LATENCY != tile_ibuf_rd_lat:
        raise ValueError("DCIM_IBUF_AXI_BRAM_READ_LATENCY != DCIM_TILE_IBUF_RD_LATENCY")

    # chip-v3: tile_obuf XPM 无 bank 结构，直接校验 RD_LATENCY 与 AXI_BRAM_READ_LATENCY 一致
    tile_obuf_rd_lat = _cfg("DCIM_TILE_OBUF_RD_LATENCY")
    if DCIM_OBUF_AXI_BRAM_READ_LATENCY != tile_obuf_rd_lat:
        raise ValueError("DCIM_OBUF_AXI_BRAM_READ_LATENCY != DCIM_TILE_OBUF_RD_LATENCY")
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="chip_defines.vh utilities")
    parser.add_argument("--get", metavar="NAME", help="print one resolved macro value")
    args = parser.parse_args()
    require_consistent()
    if args.get:
        name = args.get
        if name not in _CFG:
            raise SystemExit(f"unknown define: {name}")
        print(_CFG[name])
    else:
        for key in sorted(_CFG):
            if key.startswith("DCIM_") or key.startswith("MODE_"):
                print(f"{key}={_CFG[key]}")
