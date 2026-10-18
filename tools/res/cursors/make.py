#!/usr/bin/env python3
"""Make the Luban pointer theme from luban.cursors (the one source).

    tools/res/cursors/make.py <out dir> [--preview <file.png>]

Writes, under <out dir>:
  share/icons/Luban/cursors/<name>      Xcursor files, 24/48/72 px nominal
  share/icons/Luban/cursors/<x11 name>  links to the CSS names
  share/icons/Luban/index.theme
  share/icons/default/index.theme       Inherits=Luban: what a client naming no theme gets
  share/luban/cursors/<name>-<px>.png   the host's (luban-os) images, straight alpha
  share/luban/cursors/cursors.json      name -> hotspot per size, and the aliases

The standard library only: it runs in the factory's container and in CI.
"""
import json
import os
import struct
import sys
import zlib

GRID = 12
SCALES = (2, 4, 6)            # density 1, 2, 3 -> 24, 48, 72 px
PALETTE = {                   # ARGB, straight alpha
    "K": 0xFF1A1C2C,
    "W": 0xFFF4F4F4,
    "A": 0xFFEF7D57,
    "R": 0xFFB13E53,
    "G": 0xFF94B0C2,
}
# opensal kCursors (luban/specs/opensal/src/opensal.cppm) minus "none", which
# has no image. The check below keeps the theme and the spec the same set.
REQUIRED = ["default", "text", "pointer", "grab", "grabbing", "move", "ew-resize", "ns-resize",
            "nwse-resize", "nesw-resize", "crosshair", "wait", "progress", "not-allowed", "help"]


def die(msg):
    sys.exit(f"make.py: {msg}")


def parse(path):
    cursors, aliases, order = {}, [], []
    lines = open(path, encoding="utf-8").read().splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        i += 1
        if not line or line.startswith("#"):
            continue
        word = line.split()
        if word[0] == "alias" and len(word) == 3:
            aliases.append((word[1], word[2]))
        elif word[0] == "cursor" and len(word) == 4:
            name, hx, hy = word[1], int(word[2]), int(word[3])
            rows = [r.rstrip("\n") for r in lines[i:i + GRID]]
            i += GRID
            if len(rows) != GRID or any(len(r) != GRID for r in rows):
                die(f"{name}: needs {GRID} rows of {GRID} characters")
            bad = {c for r in rows for c in r} - set(PALETTE) - {"."}
            if bad:
                die(f"{name}: unknown pixels {sorted(bad)}")
            if not (0 <= hx < GRID and 0 <= hy < GRID):
                die(f"{name}: hotspot outside the grid")
            if name in cursors:
                die(f"{name}: twice")
            cursors[name] = (hx, hy, rows)
            order.append(name)
        else:
            die(f"line {i}: {line!r}")
    missing = [n for n in REQUIRED if n not in cursors]
    if missing:
        die(f"missing {missing}")
    for legacy, css in aliases:
        if css not in cursors:
            die(f"alias {legacy} -> {css}: no such cursor")
        if legacy in cursors:
            die(f"alias {legacy}: a cursor of that name exists")
    return cursors, aliases, order


def pixels(rows, scale):
    """Rows of ARGB values, scaled by nearest neighbour."""
    out = []
    for r in rows:
        line = []
        for c in r:
            line += [0 if c == "." else PALETTE[c]] * scale
        out += [line] * scale
    return out


def premultiply(argb):
    a = argb >> 24
    if a in (0, 255):
        return argb if a else 0
    ch = lambda s: ((argb >> s) & 0xFF) * a // 255
    return (a << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0)


def xcursor(hx, hy, rows):
    """An Xcursor file: one image per scale (Xcursor(3))."""
    images = []
    for s in SCALES:
        px = pixels(rows, s)
        size = GRID * s
        body = struct.pack("<9I", 36, 0xFFFD0002, size, 1, size, size, hx * s, hy * s, 0)
        body += b"".join(struct.pack("<I", premultiply(v)) for line in px for v in line)
        images.append((size, body))
    header = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(images))
    pos = 16 + 12 * len(images)
    toc, data = b"", b""
    for size, body in images:
        toc += struct.pack("<III", 0xFFFD0002, size, pos + len(data))
        data += body
    return header + toc + data


def png(px):
    h, w = len(px), len(px[0])
    raw = b"".join(b"\0" + b"".join(struct.pack(">I", ((v & 0xFFFFFF) << 8) | (v >> 24)) for v in line)
                   for line in px)
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def write(path, data, mode="wb"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, mode) as f:
        f.write(data)


def preview(cursors, order, path, scale=4):
    """Every shape on a checkered sheet, hotspot marked: the visual baseline."""
    cell = GRID * scale + 8
    cols = 5
    rows_n = (len(order) + cols - 1) // cols
    sheet = [[0xFFC8C8C8 if ((x // 8) + (y // 8)) % 2 else 0xFFE8E8E8 for x in range(cols * cell)]
             for y in range(rows_n * cell)]
    for n, name in enumerate(order):
        hx, hy, rows = cursors[name]
        ox, oy = (n % cols) * cell + 4, (n // cols) * cell + 4
        for y, line in enumerate(pixels(rows, scale)):
            for x, v in enumerate(line):
                if v:
                    sheet[oy + y][ox + x] = v
        sheet[oy + hy * scale][ox + hx * scale] = 0xFF00FF00
    write(path, png(sheet))


def main(argv):
    if len(argv) < 2:
        die(__doc__)
    out = argv[1]
    here = os.path.dirname(os.path.abspath(__file__))
    cursors, aliases, order = parse(os.path.join(here, "luban.cursors"))
    theme = os.path.join(out, "share", "icons", "Luban")
    host = os.path.join(out, "share", "luban", "cursors")
    manifest = {"grid": GRID, "sizes": [GRID * s for s in SCALES], "cursors": {}, "aliases": dict(aliases)}
    for name in order:
        hx, hy, rows = cursors[name]
        write(os.path.join(theme, "cursors", name), xcursor(hx, hy, rows))
        manifest["cursors"][name] = {"hotspot": [hx, hy]}
        for s in SCALES:
            write(os.path.join(host, f"{name}-{GRID * s}.png"), png(pixels(rows, s)))
    for legacy, css in aliases:
        link = os.path.join(theme, "cursors", legacy)
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(css, link)
    write(os.path.join(host, "cursors.json"), json.dumps(manifest, indent=1, sort_keys=True) + "\n", "w")
    write(os.path.join(theme, "index.theme"),
          "[Icon Theme]\nName=Luban\nComment=The Luban pointer theme: pixel art, 24 px logical\n", "w")
    write(os.path.join(out, "share", "icons", "default", "index.theme"),
          "[Icon Theme]\nName=Default\nInherits=Luban\n", "w")
    if "--preview" in argv:
        preview(cursors, order, argv[argv.index("--preview") + 1])


if __name__ == "__main__":
    main(sys.argv)
