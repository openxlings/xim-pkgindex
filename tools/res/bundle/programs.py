#!/usr/bin/env python3
"""The programs of a tree: every ELF that names an interpreter, by its path
relative to the tree, one a line -- what a recipe's config() points at the
tree's own loader where it is installed (tools/res/build.sh kde)."""
import struct
import sys
from pathlib import Path

PT_INTERP = 3
root = Path(sys.argv[1])
for f in sorted(root.rglob("*")):
    if not f.is_file() or f.is_symlink():
        continue
    with f.open("rb") as h:
        head = h.read(64)
        if len(head) < 64 or head[:4] != b"\x7fELF" or head[4] != 2 or head[5] != 1:
            continue
        phoff, = struct.unpack_from("<Q", head, 0x20)
        phentsize, phnum = struct.unpack_from("<HH", head, 0x36)
        for i in range(phnum):
            h.seek(phoff + i * phentsize)
            ptype, = struct.unpack("<I", h.read(4))
            if ptype == PT_INTERP:
                print(f.relative_to(root))
                break
