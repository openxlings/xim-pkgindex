#!/usr/bin/env python3
"""A desktop of a Luban system, seen as the Luban OS window sees it: run the
command given (it speaks opensal.wire on its standard input and output -- `luban
__desktop <session>` in the system), answer its hello as a window of WxH would,
and wait for a picture that is a desktop (more than a few colours) and, with
--panel, a band along the bottom unlike the area above it.

    luban-desktop-probe.py [--size 1280x720] [--timeout 150] [--panel] -- <command...>

Exit 0 when the desktop drew; 1 with what it saw otherwise.
"""
import argparse
import os
import select
import struct
import subprocess
import sys
import time


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--timeout", type=float, default=150)
    ap.add_argument("--panel", action="store_true")
    ap.add_argument("--settle", type=float, default=10, help="seconds before the picture counts")
    ap.add_argument("command", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.command[1:] if a.command[:1] == ["--"] else a.command
    w, h = (int(x) for x in a.size.split("x"))
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=sys.stderr)
    out_fd = p.stdout.fileno()

    def send(kind, payload):
        p.stdin.write(kind.encode() + struct.pack(">I", len(payload)) + payload)
        p.stdin.flush()

    buf = b""
    pixels = bytearray(w * h * 4)
    size = (0, 0)
    frames = 0
    seen = "nothing"
    start = time.time()
    deadline = start + a.timeout
    try:
        while time.time() < deadline:
            r, _, _ = select.select([out_fd], [], [], 1.0)
            if not r:
                continue
            chunk = os.read(out_fd, 1 << 20)
            if not chunk:
                seen = f"the desktop ended (exit {p.poll()}) after {frames} frames"
                break
            buf += chunk
            while len(buf) >= 5:
                kind = chr(buf[0])
                n = struct.unpack(">I", buf[1:5])[0]
                if len(buf) < 5 + n:
                    break
                body, buf = buf[5:5 + n], buf[5 + n:]
                if kind == "h":
                    send("H", b"%d %d %d 1 1" % (15, w, h))
                elif kind == "s":
                    size = tuple(int(x) for x in body.split()[:2])
                elif kind == "f":
                    nl = body.index(b"\n")
                    x, y, fw, fh, stride = (int(v) for v in body[:nl].split())
                    rows = body[nl + 1:]
                    for row in range(fh):
                        if y + row >= h or x + fw > w:
                            break
                        at = ((y + row) * w + x) * 4
                        pixels[at:at + fw * 4] = rows[row * stride:row * stride + fw * 4]
                    frames += 1
                    send("E", b"presented")
                    sw, sh = size if size != (0, 0) else (w, h)
                    colours = {bytes(pixels[i:i + 3]) for i in range(0, sw * sh * 4, 4 * 97)}
                    panel_ok = True
                    if a.panel:
                        # A panel along the bottom: flat across it, unlike what is above it.
                        def px(xx, yy):
                            at = (yy * w + xx) * 4
                            return pixels[at:at + 3]
                        xs = [sw // 4, sw // 2, sw * 3 // 4]
                        band = [px(xx, sh - 12) for xx in xs]
                        flat = all(max(abs(c1 - c2) for c1, c2 in zip(band[0], b)) <= 24 for b in band)
                        unlike = any(bytes(px(xx, sh - 12)) != bytes(px(xx, sh - 80)) for xx in xs)
                        panel_ok = flat and unlike
                    seen = f"{frames} frames at {sw}x{sh}, {len(colours)} colours, panel {'drawn' if panel_ok else 'not drawn'}"
                    if len(colours) > 8 and panel_ok and time.time() - start >= a.settle:
                        print(f"PASS: {seen}")
                        return 0
        print(f"FAIL: {seen}")
        return 1
    finally:
        try:
            p.stdin.close()
        except OSError:
            pass
        try:
            p.wait(timeout=20)
        except subprocess.TimeoutExpired:
            p.kill()


if __name__ == "__main__":
    sys.exit(main())
