"""Small, regex-based Lua table reader shared by the runtime-revision-gate
scripts. Not a Lua parser: it only balances braces well enough to find a
named table's body and a `["latest"] = { ref = "..." }` entry inside it,
the same convention .github/scripts/parse-xpkg-meta.py already relies on
for the same descriptors.
"""
from __future__ import annotations

import re

PLATFORMS = ("linux", "macosx", "windows")


def table_body(source: str, name: str) -> str:
    """Balanced-brace body of the first `name = {` or `["name"] = {` in
    `source`. Empty string when the key is absent."""
    marker = re.search(rf'(?:\["{re.escape(name)}"\]|\b{re.escape(name)}\b)\s*=\s*\{{', source)
    if not marker:
        return ""
    depth = 1
    index = marker.end()
    while index < len(source) and depth:
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
        index += 1
    return source[marker.end():index - 1] if depth == 0 else ""


def platform_body(source: str, platform: str) -> str:
    return table_body(table_body(source, "xpm"), platform)


def declares_runtime_abi(platform_src: str) -> bool:
    runtime = table_body(table_body(platform_src, "exports"), "runtime")
    return bool(re.search(r"\babi\s*=", runtime))


def latest_ref(platform_src: str) -> str | None:
    m = re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"', platform_src)
    return m.group(1) if m else None
