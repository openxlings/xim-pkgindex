"""A QEMU machine driven through its monitor: lines typed on its keyboard.

For the builders of disk images whose system is prepared by itself, booted once
(build-hurd-disk-image.py, build-haiku-disk-image.py): what a console shows is
not read; what the system answers is written by it to a serial line, to a file.

A system whose installer speaks on the screen only (build-svr4-disk-image.py:
UNIX System V/386 Release 4.0, installed from floppies) is read on the screen:
the display adapter's text memory, through the same monitor; and its floppies
are changed in the drive as it asks for them.
"""
import os, subprocess, tempfile, time
from pathlib import Path

KEY = {' ': 'spc', '\n': 'ret', '-': 'minus', '=': 'equal', '.': 'dot', '/': 'slash', ',': 'comma', ';': 'semicolon',
       "'": 'apostrophe', '\\': 'backslash', '[': 'bracket_left', ']': 'bracket_right', '`': 'grave_accent'}
SHIFT = {'>': 'dot', '<': 'comma', '_': 'minus', '|': 'backslash', '&': '7', '*': '8', '(': '9', ')': '0', '!': '1',
         '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '+': 'equal', ':': 'semicolon', '"': 'apostrophe',
         '?': 'slash', '{': 'bracket_left', '}': 'bracket_right', '~': 'grave_accent'}


class Machine:
    pace = 0.03      # seconds after each monitor command: a slower console is given more

    def __init__(self, argv):
        self.p = subprocess.Popen(argv + ["-monitor", "stdio"], stdin=subprocess.PIPE,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)

    def monitor(self, command):
        self.p.stdin.write((command + "\n").encode())
        self.p.stdin.flush()
        time.sleep(self.pace)

    def key(self, name):
        """One key or chord, by QEMU's name for it (`ret', `alt-meta_l-t')."""
        self.monitor("sendkey " + name)

    def type(self, line):
        """A line, and Enter."""
        for ch in line + "\n":
            self.key(KEY.get(ch) or ("shift-" + SHIFT[ch] if ch in SHIFT else
                                     ("shift-" + ch.lower() if ch.isupper() else ch)))

    def screen(self) -> str:
        """The 80x25 text screen (VGA text mode, 0xb8000), as lines, the empty ones at its end dropped."""
        dump = Path(tempfile.gettempdir()) / f"qemu-keyboard-screen-{os.getpid()}.bin"
        dump.unlink(missing_ok=True)
        self.monitor(f'pmemsave 0xb8000 4000 "{dump}"')
        end = time.time() + 5
        while time.time() < end and not (dump.exists() and dump.stat().st_size == 4000):
            time.sleep(0.05)
        cells = dump.read_bytes() if dump.exists() else b""
        dump.unlink(missing_ok=True)
        rows = []
        for r in range(25):
            text = cells[r * 160:(r + 1) * 160:2].decode("cp437", "replace")
            rows.append("".join(c if c.isprintable() else " " for c in text).rstrip())
        while rows and not rows[-1]:
            rows.pop()
        return "\n".join(rows)

    def shown(self, text, within, tail=4):
        """Waits until the last `tail' lines of the screen hold `text' and the screen has settled: a
        question is read only once it is asked, and the answer typed a second after."""
        end = time.time() + within
        last = None
        while time.time() < end:
            s = self.screen()
            if text in "\n".join(s.splitlines()[-tail:]) and s == last:
                time.sleep(1)
                return s
            last = s
            time.sleep(1.5)
        raise SystemExit(f"the screen did not come to show {text!r} within {within:.0f} s; it shows:\n{self.screen()}")

    def insert(self, drive, image):
        """A medium in a removable drive (`floppy0'), as a person would put it in."""
        self.monitor(f'change {drive} "{image}" raw')
        time.sleep(0.5)

    def eject(self, drive):
        self.monitor(f"eject -f {drive}")
        time.sleep(0.5)

    def stop(self):
        if self.p.poll() is None:
            self.p.kill()
            self.p.wait()


def said(log: Path, text: str, within: float) -> bool:
    """Whether `text` comes to be in the file within so many seconds."""
    end = time.time() + within
    while time.time() < end:
        if log.exists() and text in log.read_text(errors="replace"):
            return True
        time.sleep(1)
    return False
