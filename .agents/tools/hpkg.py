#!/usr/bin/env python3
"""Read a Haiku package (`.hpkg`): list its entries, or extract them.

A reader of the container format of Haiku's package kit (format version 2,
docs/develop/packages/FileFormat.rst in Haiku's tree), written from that
description; Haiku's own `package` tool runs on Haiku or from a Haiku build
tree only. The file is a header, a heap and nothing else:

    header   big-endian; the heap's compression and sizes, the lengths of the sections
    heap     the data in chunks (64 KiB before compression), each stored compressed
             unless that saves nothing, followed by a table of the stored sizes of
             all chunks but the last; the uncompressed heap ends with the table of
             contents and then the package attributes
    TOC      a table of shared strings, then attribute trees: `dir:entry' holding
             `file:type', `file:permissions', `symlink:path', `data' and children

Compression is zlib or Zstandard. Zstandard is read by the `compression.zstd`
module where Python has it (3.14), otherwise by the `zstd` program.

usage: hpkg.py list <package.hpkg>
       hpkg.py extract <package.hpkg> <directory> [<path prefix> ...]
"""
import os, shutil, struct, subprocess, sys, zlib
from pathlib import Path

NONE, ZLIB, ZSTD = 0, 1, 2
INT, UINT, STRING, RAW = 1, 2, 3, 4
DIR_ENTRY, FILE_TYPE, FILE_PERMISSIONS, FILE_MTIME, DATA, SYMLINK_PATH = 0, 1, 2, 6, 13, 14
FILE, DIRECTORY, SYMLINK = 0, 1, 2
DEFAULT_PERMISSIONS = {FILE: 0o644, DIRECTORY: 0o755, SYMLINK: 0o777}


def unzstd(frames: bytes) -> bytes:
    """Zstandard frames, one after another, decompressed."""
    try:
        from compression import zstd
    except ImportError:
        program = shutil.which("zstd")
        if not program:
            raise SystemExit("a Zstandard package needs Python 3.14 or the `zstd' program")
        return subprocess.run([program, "-dc"], input=frames, stdout=subprocess.PIPE, check=True).stdout
    out, rest = [], frames
    while rest:
        d = zstd.ZstdDecompressor()
        out.append(d.decompress(rest))
        rest = d.unused_data
    return b"".join(out)


class Heap:
    """The uncompressed heap of a package file, read once."""
    def __init__(self, path):
        raw = Path(path).read_bytes()
        if raw[:4] not in (b"hpkg", b"hpkr"):
            raise SystemExit(f"{path}: not a Haiku package (no `hpkg' magic)")
        self.header_size, version, total = struct.unpack_from(">HHQ", raw, 4)
        if version != 2:
            raise SystemExit(f"{path}: format version {version}; this reader reads version 2")
        if total != len(raw):
            raise SystemExit(f"{path}: the header states {total} bytes, the file has {len(raw)}")
        _, compression, chunk, stored, size = struct.unpack_from(">HHIQQ", raw, 16)
        self.header = raw[:self.header_size]
        heap = raw[self.header_size:self.header_size + stored]
        if compression == NONE:
            self.data = heap
        else:
            count = (size + chunk - 1) // chunk
            table = len(heap) - 2 * (count - 1)
            sizes = [n + 1 for n in struct.unpack_from(f">{count - 1}H", heap, table)] if count > 1 else []
            sizes.append(table - sum(sizes))
            parts, pending, at = [], [], 0

            def flush():
                if pending:
                    parts.append(unzstd(b"".join(pending)))
                    pending.clear()
            for i, n in enumerate(sizes):
                plain = chunk if i < count - 1 else size - chunk * (count - 1)
                piece = heap[at:at + n]
                at += n
                if n == plain:                  # stored as it is: compression saved nothing
                    flush()
                    parts.append(piece)
                elif compression == ZLIB:
                    parts.append(zlib.decompress(piece))
                elif compression == ZSTD:
                    pending.append(piece)
                else:
                    raise SystemExit(f"{path}: heap compression {compression} is not known")
            flush()
            self.data = b"".join(parts)
        if len(self.data) != size:
            raise SystemExit(f"{path}: the heap is {len(self.data)} bytes, the header states {size}")


class Entry:
    def __init__(self, path):
        self.path, self.type, self.permissions, self.mtime, self.link, self.data = path, FILE, None, 0, None, b""

    @property
    def mode(self):
        return DEFAULT_PERMISSIONS[self.type] if self.permissions is None else self.permissions


class Package:
    """The entries of a package, in the order of its table of contents."""
    def __init__(self, path):
        self.heap = Heap(path)
        h = self.heap.header
        attributes_length, = struct.unpack_from(">I", h, 40)
        toc_length, strings_length, strings_count = struct.unpack_from(">QQQ", h, 56)
        self.toc = self.heap.data[len(self.heap.data) - attributes_length - toc_length:][:toc_length]
        self.strings = self.toc[:strings_length].split(b"\0")[:strings_count]
        self.at = strings_length
        self.entries = []
        self._children(None)

    def _leb(self):
        value = shift = 0
        while True:
            b = self.toc[self.at]
            self.at += 1
            value |= (b & 0x7f) << shift
            shift += 7
            if not b & 0x80:
                return value

    def _value(self, kind, encoding):
        if kind in (INT, UINT):
            n = 1 << encoding
            v = int.from_bytes(self.toc[self.at:self.at + n], "big", signed=kind == INT)
            self.at += n
            return v
        if kind == STRING:
            if encoding == 1:
                return self.strings[self._leb()].decode()
            end = self.toc.index(b"\0", self.at)
            s = self.toc[self.at:end].decode()
            self.at = end + 1
            return s
        if kind == RAW:
            size = self._leb()
            if encoding == 1:
                offset = self._leb()
                return self.heap.data[offset:offset + size]
            v = self.toc[self.at:self.at + size]
            self.at += size
            return v
        raise SystemExit(f"an attribute of type {kind} is not known")

    def _children(self, parent):
        while True:
            tag = self._leb()
            if tag == 0:
                return
            tag -= 1
            ident, kind, has_children, encoding = tag & 0x7f, (tag >> 7) & 7, (tag >> 10) & 1, tag >> 11
            value = self._value(kind, encoding)
            entry = None
            if ident == DIR_ENTRY:
                entry = Entry(f"{parent.path}/{value}" if parent else value)
                self.entries.append(entry)
            elif parent is not None:
                if ident == FILE_TYPE:
                    parent.type = value
                elif ident == FILE_PERMISSIONS:
                    parent.permissions = value
                elif ident == FILE_MTIME:
                    parent.mtime = value
                elif ident == SYMLINK_PATH:
                    parent.link = value
                elif ident == DATA:
                    parent.data = value
            if has_children:
                # the children of an attribute that is not an entry (a file attribute) are read past
                self._children(entry if entry else Entry(""))

    def extract(self, directory, prefixes=()):
        """Write the entries beneath `directory`; with prefixes, only the paths beneath them."""
        directory = Path(directory)
        count = 0
        for e in self.entries:
            parts = e.path.split("/")
            if e.path.startswith("/") or ".." in parts or "" in parts:
                raise SystemExit(f"an entry leaves the package's root: {e.path!r}")
            if prefixes and not any(e.path == p or e.path.startswith(p.rstrip("/") + "/") for p in prefixes):
                continue
            to = directory / e.path
            to.parent.mkdir(parents=True, exist_ok=True)
            if e.type == DIRECTORY:
                to.mkdir(exist_ok=True)
                continue
            if to.is_symlink() or to.exists():
                to.unlink()
            if e.type == SYMLINK:
                os.symlink(e.link or "", to)
            else:
                to.write_bytes(e.data)
                to.chmod(e.mode & 0o777)
                os.utime(to, (e.mtime, e.mtime))
            count += 1
        return count


def main() -> int:
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == "list":
        for e in Package(a[1]).entries:
            what = "dl-"[(DIRECTORY, SYMLINK, FILE).index(e.type)]
            tail = f" -> {e.link}" if e.type == SYMLINK else ""
            print(f"{what} {e.mode:04o} {len(e.data):>10} {e.path}{tail}")
        return 0
    if len(a) >= 3 and a[0] == "extract":
        print(Package(a[1]).extract(a[2], a[3:]), "entries")
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
