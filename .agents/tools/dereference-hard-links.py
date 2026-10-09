#!/usr/bin/env python3
"""Rewrite a payload archive with every hard-link entry replaced by the file it names.

A hard-link entry is extracted with link(2). Android's app sandbox refuses
link(2) (EACCES), and so do FAT and exFAT, so an xlings older than 2026.10.10.2
fails on such a payload with "write_header(...): Can't create". The rewritten
archive holds the same files with the same bytes, modes, owners and times; only
the entries that were links become regular files. Members keep their order,
and the output is deterministic (gzip header without a name or time).

--root-from/--root-to rename the archive's top-level directory, for a payload
whose top-level directory is its own stem (glibc-2.44.3-r3-... -> -r4-...).
--provenance FILE=TEXT appends TEXT to the member FILE (relative to the top-level
directory), so the payload states what was done to it.

Usage:
    dereference-hard-links.py IN.tar.gz OUT.tar.gz [--root-from A --root-to B]
                              [--provenance PROVENANCE.txt="..."]
"""
import argparse
import copy
import gzip
import hashlib
import io
from pathlib import Path
import tarfile


def rename(name, old, new):
    if not old:
        return name
    if name == old or name.startswith(old + '/'):
        return new + name[len(old):]
    raise ValueError(f'member outside the top-level directory {old}: {name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--root-from', default='')
    parser.add_argument('--root-to', default='')
    parser.add_argument('--provenance', action='append', default=[], metavar='FILE=TEXT')
    args = parser.parse_args()
    if bool(args.root_from) != bool(args.root_to):
        parser.error('--root-from and --root-to go together')
    appends = {}
    for item in args.provenance:
        name, _, text = item.partition('=')
        appends[name] = text

    copied = 0
    with tarfile.open(args.source) as src:
        members = src.getmembers()
        by_name = {m.name: m for m in members}
        top = args.root_to or args.root_from
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode='w', format=src.format) as out:
            for member in members:
                info = copy.copy(member)
                info.name = rename(member.name, args.root_from, args.root_to)
                data = None
                if member.islnk():
                    target = by_name.get(member.linkname)
                    if target is None or not target.isfile():
                        raise ValueError(f'{member.name}: links to {member.linkname}, '
                                         'which is not a regular file of this archive')
                    info.type = tarfile.REGTYPE
                    info.linkname = ''
                    info.size = target.size
                    data = src.extractfile(target).read()
                    copied += 1
                elif member.issym():
                    pass
                elif member.isfile():
                    data = src.extractfile(member).read()
                relative = info.name[len(top) + 1:] if top else info.name
                if relative in appends:
                    if data is None:
                        raise ValueError(f'--provenance names {relative}, which is not a file')
                    data = data.rstrip(b'\n') + b'\n\n' + appends.pop(relative).encode() + b'\n'
                    info.size = len(data)
                out.addfile(info, io.BytesIO(data) if data is not None else None)
        if appends:
            raise ValueError(f'--provenance names files the archive does not hold: {sorted(appends)}')

    with args.output.open('wb') as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0, compresslevel=9) as stream:
            stream.write(buffer.getvalue())
    with tarfile.open(args.output) as check:
        links = [m.name for m in check.getmembers() if m.islnk()]
    if links:
        raise ValueError(f'hard links remain: {links[:5]}')
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    args.output.with_name(args.output.name + '.sha256').write_text(f'{digest}  {args.output.name}\n')
    print(f'{args.output.name}: {len(members)} members, {copied} hard links replaced, sha256 {digest}')


if __name__ == '__main__':
    main()
