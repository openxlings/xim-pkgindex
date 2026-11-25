#!/usr/bin/env python3
"""A corrective revision of a published archive, derived from that archive.

    revision.py zip <from.zip> <to.zip> <from-top> <to-top> [--same <member>=<new>]... [--add <name>=<file>]...
    revision.py tar <from.tar.xz> <to.tar.xz> <from-top> <to-top> [--add <name>=<file>]...
    revision.py digest <archive.zip> <member>
    revision.py tar-digests <member>... < <tar stream>

A revision whose change is confined to the archive -- its directory renamed to
the new asset's (`<name>-<version>-r<N>`, the index's install convention), a
file added -- is made from the published archive of the revision before it,
so every file it does not name is that archive's, byte for byte.

`zip` copies each entry's compressed bytes unchanged under its new name, and
`--same` adds an entry whose bytes are an existing entry's (its compressed
bytes, its CRC, its time); `--add` stores a file of ours uncompressed. Nothing
is recompressed, so the output is the same bytes on every machine.

`tar` writes every member again under its new name with its metadata, and
compresses with xz at preset 9; `--add` writes a file of ours with the
metadata of the archive's top directory.

`digest` prints the sha256 of one member of a zip, `tar-digests` that of each
member of a tar stream whose path below the stream's top directory is named
(upstream's archive, to tie an added file to the release it comes from).

Each derivation reads its output back and fails (exit 1) unless every member
of the input is there with the same content under its new name, and nothing
else is but what was added.
"""
from __future__ import annotations

import hashlib
import lzma
import struct
import sys
import tarfile
import zipfile
from pathlib import Path

LOCAL, CENTRAL, END = 0x04034B50, 0x02014B50, 0x06054B50
DESCRIPTOR = 1 << 3


def fail(message: str) -> None:
    print(f"revision.py: {message}", file=sys.stderr)
    sys.exit(1)


def renamed(name: str, old: str, new: str) -> str:
    if name == old or name == old + "/":
        return new + name[len(old):]
    if not name.startswith(old + "/"):
        fail(f"{name} is not under {old}/: the archive has another top directory")
    return new + name[len(old):]


def pairs(values: list[str], what: str) -> list[tuple[str, str]]:
    out = []
    for value in values:
        left, sep, right = value.partition("=")
        if not sep or not left or not right:
            fail(f"{what} takes <a>=<b>, not {value!r}")
        out.append((left, right))
    return out


# ── zip ─────────────────────────────────────────────────────────────────
def central_directory(data: bytes) -> list[dict]:
    at = data.rfind(struct.pack("<I", END), max(0, len(data) - 65557))
    if at < 0:
        fail("no end of central directory record")
    _, disk, _, _, count, size, offset, _ = struct.unpack_from("<IHHHHIIH", data, at)
    if disk != 0 or 0xFFFF in (count,) or 0xFFFFFFFF in (size, offset):
        fail("a multi-disk or zip64 archive: not supported")
    entries, p = [], offset
    for _ in range(count):
        (sig, made, need, flags, method, mtime, mdate, crc, csize, usize, nlen, xlen, clen,
         _, iattr, eattr, local) = struct.unpack_from("<IHHHHHHIIIHHHHHII", data, p)
        if sig != CENTRAL:
            fail("a damaged central directory")
        name = data[p + 46:p + 46 + nlen].decode("utf-8" if flags & 0x800 else "cp437")
        if 0xFFFFFFFF in (csize, usize, local):
            fail(f"{name}: a zip64 entry: not supported")
        lsig, _, _, _, _, _, _, _, _, lnlen, lxlen = struct.unpack_from("<IHHHHHIIIHH", data, local)
        if lsig != LOCAL:
            fail(f"{name}: no local header at its offset")
        start = local + 30 + lnlen + lxlen
        entries.append(dict(name=name, made=made, need=need, flags=flags & ~DESCRIPTOR, method=method,
                            mtime=mtime, mdate=mdate, crc=crc, csize=csize, usize=usize, iattr=iattr,
                            eattr=eattr, comment=data[p + 46 + nlen + xlen:p + 46 + nlen + xlen + clen],
                            payload=(start, start + csize)))
        p += 46 + nlen + xlen + clen
    return entries


def write_zip(data: bytes, entries: list[dict], out: Path) -> None:
    central = bytearray()
    with out.open("wb") as f:
        for e in entries:
            name = e["name"].encode("utf-8")
            flags = e["flags"] | (0x800 if not e["name"].isascii() else 0)
            offset = f.tell()
            f.write(struct.pack("<IHHHHHIIIHH", LOCAL, e["need"], flags, e["method"], e["mtime"],
                                e["mdate"], e["crc"], e["csize"], e["usize"], len(name), 0))
            f.write(name)
            body = e.get("body")
            f.write(body if body is not None else data[e["payload"][0]:e["payload"][1]])
            central += struct.pack("<IHHHHHHIIIHHHHHII", CENTRAL, e["made"], e["need"], flags, e["method"],
                                   e["mtime"], e["mdate"], e["crc"], e["csize"], e["usize"], len(name), 0,
                                   len(e["comment"]), 0, e["iattr"], e["eattr"], offset)
            central += name + e["comment"]
        start = f.tell()
        if len(entries) > 0xFFFF or start + len(central) > 0xFFFFFFFF:
            fail("the derived archive needs zip64: not supported")
        f.write(central)
        f.write(struct.pack("<IHHHHIIH", END, 0, 0, len(entries), len(entries), len(central), start, 0))


def derive_zip(src: Path, dst: Path, old: str, new: str, same: list[tuple[str, str]],
               add: list[tuple[str, str]]) -> None:
    data = src.read_bytes()
    entries = central_directory(data)
    by_name = {e["name"]: e for e in entries}
    for e in entries:
        e["name"] = renamed(e["name"], old, new)
    aliases: dict[str, list[dict]] = {}
    for member, alias in same:
        source = by_name.get(f"{old}/{member}")
        if source is None:
            fail(f"{old}/{member} is not in {src.name}")
        if f"{old}/{alias}" in by_name:
            fail(f"{old}/{alias} is already in {src.name}")
        aliases.setdefault(id(source), []).append(dict(source, name=f"{new}/{alias}"))
    out = []
    for e in entries:
        out.append(e)
        out.extend(aliases.get(id(e), []))
    stamp = next((e for e in entries if e["name"] == new + "/"), entries[0])
    for name, file in add:
        body = Path(file).read_bytes()
        out.append(dict(name=f"{new}/{name}", made=stamp["made"], need=10, flags=0, method=0,
                        mtime=stamp["mtime"], mdate=stamp["mdate"], crc=zipfile.crc32(body) & 0xFFFFFFFF,
                        csize=len(body), usize=len(body), iattr=0, eattr=(0o100644 << 16), comment=b"",
                        body=body))
    write_zip(data, out, dst)
    check_zip(src, dst, old, new, same, add)


def check_zip(src: Path, dst: Path, old: str, new: str, same: list[tuple[str, str]],
              add: list[tuple[str, str]]) -> None:
    with zipfile.ZipFile(src) as a, zipfile.ZipFile(dst) as b:
        before = {renamed(i.filename, old, new): i for i in a.infolist()}
        after = {i.filename: i for i in b.infolist()}
        expected = set(before) | {f"{new}/{n}" for _, n in same} | {f"{new}/{n}" for n, _ in add}
        if set(after) != expected:
            fail(f"the derived archive holds {sorted(set(after) ^ expected)[:5]} unexpectedly")
        for name, info in before.items():
            got = after[name]
            if (got.CRC, got.file_size, got.compress_type, got.date_time) != \
                    (info.CRC, info.file_size, info.compress_type, info.date_time):
                fail(f"{name} differs from the archive it is derived from")
        for member, alias in same:
            if after[f"{new}/{alias}"].CRC != after[f"{new}/{member}"].CRC:
                fail(f"{alias} is not {member}'s bytes")
        bad = b.testzip()
        if bad is not None:
            fail(f"{bad}: its bytes do not match its CRC")


# ── tar ─────────────────────────────────────────────────────────────────
def header_format(src: Path) -> int:
    """The format of the archive's first header: GNU tar writes `ustar  \\0`,
    POSIX `ustar\\0` + `00`. The derived archive is written in the same one."""
    with lzma.open(src) as f:
        magic = f.read(512)[257:265]
    if magic == b"ustar  \x00":
        return tarfile.GNU_FORMAT
    if magic == b"ustar\x0000":
        return tarfile.PAX_FORMAT
    fail(f"{src.name}: not a GNU or POSIX tar archive")


def derive_tar(src: Path, dst: Path, old: str, new: str, add: list[tuple[str, str]]) -> None:
    form = header_format(src)
    with tarfile.open(src, "r:xz") as a:
        members = a.getmembers()
        top = next((m for m in members if m.name == old), None)
        if top is None or not top.isdir():
            fail(f"{src.name} has no top directory {old}")
        with lzma.open(dst, "wb", preset=9) as raw, tarfile.open(fileobj=raw, mode="w", format=form) as b:
            for m in members:
                info = m.replace(name=renamed(m.name, old, new), deep=False)
                if m.islnk():
                    info.linkname = renamed(m.linkname, old, new)
                b.addfile(info, a.extractfile(m) if m.isfile() else None)
            for name, file in add:
                info = tarfile.TarInfo(f"{new}/{name}")
                info.size, info.mode, info.mtime = Path(file).stat().st_size, 0o644, top.mtime
                info.uid, info.gid, info.uname, info.gname = top.uid, top.gid, top.uname, top.gname
                with open(file, "rb") as body:
                    b.addfile(info, body)
    check_tar(src, dst, old, new, add)


def tar_index(path: Path, old: str | None = None, new: str | None = None) -> dict:
    out = {}
    with tarfile.open(path, "r:xz") as t:
        for m in t:
            name = renamed(m.name, old, new) if old else m.name
            body = hashlib.sha256(t.extractfile(m).read()).hexdigest() if m.isfile() else None
            out[name] = (m.type, m.mode, m.uid, m.gid, m.mtime, m.linkname if m.issym() else "", body)
    return out


def check_tar(src: Path, dst: Path, old: str, new: str, add: list[tuple[str, str]]) -> None:
    before = tar_index(src, old, new)
    after = tar_index(dst)
    expected = set(before) | {f"{new}/{n}" for n, _ in add}
    if set(after) != expected:
        fail(f"the derived archive holds {sorted(set(after) ^ expected)[:5]} unexpectedly")
    for name, value in before.items():
        if after[name] != value:
            fail(f"{name} differs from the archive it is derived from")


# ── digests ─────────────────────────────────────────────────────────────
def zip_digest(src: Path, member: str) -> str:
    with zipfile.ZipFile(src) as z, z.open(member) as f:
        h = hashlib.sha256()
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
        return h.hexdigest()


def tar_digests(names: list[str]) -> int:
    found = {}
    with tarfile.open(fileobj=sys.stdin.buffer, mode="r|*") as t:
        for m in t:
            below = m.name.split("/", 1)[1] if "/" in m.name else ""
            if below not in names or below in found:
                continue
            if not m.isfile():
                fail(f"{m.name} is not a regular file in the stream")
            h, f = hashlib.sha256(), t.extractfile(m)
            for block in iter(lambda: f.read(1 << 20), b""):
                h.update(block)
            found[below] = h.hexdigest()
    missing = [n for n in names if n not in found]
    if missing:
        fail(f"not in the stream: {', '.join(missing)}")
    for name in names:
        print(f"{found[name]}  {name}")
    return 0


def options(argv: list[str], *known: str) -> tuple[list[str], dict[str, list[str]]]:
    positional, named = [], {k: [] for k in known}
    i = 0
    while i < len(argv):
        if argv[i] in named:
            if i + 1 >= len(argv):
                fail(f"{argv[i]} needs a value")
            named[argv[i]].append(argv[i + 1])
            i += 2
        elif argv[i].startswith("--"):
            fail(f"unknown option {argv[i]}")
        else:
            positional.append(argv[i])
            i += 1
    return positional, named


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    command, rest = argv[0], argv[1:]
    if command == "zip":
        args, named = options(rest, "--same", "--add")
        if len(args) != 4:
            fail("zip takes <from.zip> <to.zip> <from-top> <to-top>")
        derive_zip(Path(args[0]), Path(args[1]), args[2], args[3],
                   pairs(named["--same"], "--same"), pairs(named["--add"], "--add"))
    elif command == "tar":
        args, named = options(rest, "--add")
        if len(args) != 4:
            fail("tar takes <from.tar.xz> <to.tar.xz> <from-top> <to-top>")
        derive_tar(Path(args[0]), Path(args[1]), args[2], args[3], pairs(named["--add"], "--add"))
    elif command == "digest":
        if len(rest) != 2:
            fail("digest takes <archive.zip> <member>")
        print(zip_digest(Path(rest[0]), rest[1]))
    elif command == "tar-digests":
        if not rest:
            fail("tar-digests takes the members to hash")
        return tar_digests(rest)
    else:
        fail(f"unknown command {command}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
