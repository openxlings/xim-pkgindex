#!/usr/bin/env python3
"""Turn each ELF's PT_INTERP into PT_NULL: a program here is run by the
tree's own loader (`ld-musl --library-path <lib> <program>`), which ignores
it, and with it the file names no loader outside its tree -- what a root
checks of every ELF it holds. Prints how many it changed."""
import struct
import sys
from pathlib import Path

PT_INTERP, PT_NULL = 3, 0
changed = 0
for root in sys.argv[1:]:
    for f in sorted(Path(root).rglob("*")):
        if not f.is_file() or f.is_symlink():
            continue
        with f.open("r+b") as h:
            head = h.read(64)
            if len(head) < 64 or head[:4] != b"\x7fELF" or head[4] != 2 or head[5] != 1:
                continue    # 64-bit little-endian only (x86_64, aarch64)
            phoff, = struct.unpack_from("<Q", head, 0x20)
            phentsize, phnum = struct.unpack_from("<HH", head, 0x36)
            for i in range(phnum):
                h.seek(phoff + i * phentsize)
                ptype, = struct.unpack("<I", h.read(4))
                if ptype == PT_INTERP:
                    h.seek(phoff + i * phentsize)
                    h.write(struct.pack("<I", PT_NULL))
                    changed += 1
print(changed)
