"""
Custom YAML loader for hw_caps.yaml without depending on PyYAML.

We support only the small subset needed by hw_caps.yaml:
  - mappings (indented key: value)
  - sequences (- item)
  - scalars: int (decimal, 0x..., 0b...), float, true/false, null, quoted/bare strings, lists [..]

This avoids adding a runtime dependency for a static configuration file.
"""

from __future__ import annotations

import ast
import re
from typing import Any, List, Tuple


def _parse_scalar(s: str) -> Any:
    s = s.strip()
    if s == "" or s.lower() == "null" or s == "~":
        return None
    if s.lower() == "true":
        return True
    if s.lower() == "false":
        return False
    # bracketed inline list
    if s.startswith("[") and s.endswith("]"):
        inner = s[1:-1].strip()
        if not inner:
            return []
        out = []
        # support nested lists once: [[1,2],[3,4]]  → use ast.literal_eval first
        try:
            # ast accepts 0x.. / 0b.. via Python literal parsing
            return ast.literal_eval(s)
        except (SyntaxError, ValueError):
            # fall back: split by top-level commas
            depth = 0
            buf = ""
            parts = []
            for ch in inner:
                if ch == "," and depth == 0:
                    parts.append(buf)
                    buf = ""
                else:
                    if ch in "[(":
                        depth += 1
                    elif ch in "])":
                        depth -= 1
                    buf += ch
            if buf:
                parts.append(buf)
            return [_parse_scalar(p) for p in parts]
    # quoted
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        return s[1:-1]
    # int
    if re.fullmatch(r"[+-]?0x[0-9a-fA-F_]+", s):
        return int(s, 16)
    if re.fullmatch(r"[+-]?0b[01_]+", s):
        return int(s, 2)
    if re.fullmatch(r"[+-]?[0-9_]+", s):
        return int(s)
    # float
    if re.fullmatch(r"[+-]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?", s):
        return float(s)
    return s  # bare string


def _strip_comment(line: str) -> str:
    # remove `# ...` outside of any quoted region
    in_s = False
    quote = ""
    out = []
    for ch in line:
        if in_s:
            out.append(ch)
            if ch == quote:
                in_s = False
        else:
            if ch in ('"', "'"):
                in_s = True
                quote = ch
                out.append(ch)
            elif ch == "#":
                break
            else:
                out.append(ch)
    return "".join(out).rstrip()


def _tokenize(text: str) -> List[Tuple[int, str]]:
    lines = []
    for raw in text.splitlines():
        line = _strip_comment(raw)
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        lines.append((indent, line.strip()))
    return lines


def loads(text: str) -> Any:
    lines = _tokenize(text)
    pos = [0]

    def parse_block(indent: int) -> Any:
        if pos[0] >= len(lines):
            return None
        first_indent, first_content = lines[pos[0]]
        if first_indent < indent:
            return None
        if first_content.startswith("- "):
            return parse_list(indent)
        return parse_map(indent)

    def parse_map(indent: int):
        out = {}
        while pos[0] < len(lines):
            cur_indent, content = lines[pos[0]]
            if cur_indent < indent:
                break
            if cur_indent > indent:
                raise ValueError(f"unexpected indent {cur_indent} (expected {indent}): {content!r}")
            if ":" not in content:
                raise ValueError(f"map line lacks colon: {content!r}")
            # split key:value at first ":" not inside brackets
            depth = 0
            split_at = -1
            for i, ch in enumerate(content):
                if ch == "[":
                    depth += 1
                elif ch == "]":
                    depth -= 1
                elif ch == ":" and depth == 0:
                    split_at = i
                    break
            if split_at == -1:
                raise ValueError(f"no top-level ':' in map line: {content!r}")
            key = content[:split_at].strip()
            rest = content[split_at + 1 :].strip()
            pos[0] += 1
            if rest == "":
                # nested block
                if pos[0] < len(lines) and lines[pos[0]][0] > indent:
                    out[key] = parse_block(lines[pos[0]][0])
                else:
                    out[key] = None
            else:
                out[key] = _parse_scalar(rest)
        return out

    def parse_list(indent: int):
        items = []
        while pos[0] < len(lines):
            cur_indent, content = lines[pos[0]]
            if cur_indent < indent:
                break
            if cur_indent > indent or not content.startswith("- "):
                break
            payload = content[2:].strip()
            pos[0] += 1
            if ":" in payload and not payload.startswith("[") and not payload.startswith('"'):
                # list item is a map: simulate by re-injecting; require items to follow with same +2 indent
                # Simplest: parse the "- key: value" as a single-key map inline, then merge follow-up keys at >indent.
                # For our hw_caps.yaml usage, list items are simple scalars; we don't need full list-of-maps.
                items.append(_parse_scalar(payload))
            else:
                items.append(_parse_scalar(payload))
        return items

    if not lines:
        return {}
    return parse_block(lines[0][0])


def load_file(path: str) -> Any:
    with open(path) as f:
        return loads(f.read())
