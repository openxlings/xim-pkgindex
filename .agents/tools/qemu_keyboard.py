"""A QEMU machine driven through its monitor: lines typed on its keyboard.

For the builders of disk images whose system is prepared by itself, booted once
(build-hurd-disk-image.py, build-haiku-disk-image.py): what a console shows is
not read; what the system answers is written by it to a serial line, to a file.
"""
import subprocess, time
from pathlib import Path

KEY = {' ': 'spc', '\n': 'ret', '-': 'minus', '=': 'equal', '.': 'dot', '/': 'slash', ',': 'comma', ';': 'semicolon',
       "'": 'apostrophe', '\\': 'backslash', '[': 'bracket_left', ']': 'bracket_right', '`': 'grave_accent'}
SHIFT = {'>': 'dot', '<': 'comma', '_': 'minus', '|': 'backslash', '&': '7', '*': '8', '(': '9', ')': '0', '!': '1',
         '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '+': 'equal', ':': 'semicolon', '"': 'apostrophe',
         '?': 'slash', '{': 'bracket_left', '}': 'bracket_right', '~': 'grave_accent'}


class Machine:
    def __init__(self, argv):
        self.p = subprocess.Popen(argv + ["-monitor", "stdio"], stdin=subprocess.PIPE,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)

    def monitor(self, command):
        self.p.stdin.write((command + "\n").encode())
        self.p.stdin.flush()
        time.sleep(0.03)

    def key(self, name):
        """One key or chord, by QEMU's name for it (`ret', `alt-meta_l-t')."""
        self.monitor("sendkey " + name)

    def type(self, line):
        """A line, and Enter."""
        for ch in line + "\n":
            self.key(KEY.get(ch) or ("shift-" + SHIFT[ch] if ch in SHIFT else
                                     ("shift-" + ch.lower() if ch.isupper() else ch)))

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
