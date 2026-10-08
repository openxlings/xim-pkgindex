#!/usr/bin/env python3
"""Check the required managed glibc runtime-data inventory without executing ELF."""
import argparse
import hashlib
import json
import posixpath
from pathlib import Path
import tarfile

REQUIRED = ('share/zoneinfo/Asia/Tokyo', 'share/zoneinfo/Etc/UTC',
            'lib/locale/C.utf8/LC_CTYPE', 'lib/gconv/GBK.so',
            'LICENSE', 'TZDATA-LICENSE', 'PROVENANCE.txt', 'ELF-MANIFEST.txt')


def inspect(archive, architecture, revision):
    root = f'glibc-2.44.3-r{revision}-linux-{architecture}'
    with tarfile.open(archive) as stream:
        members = {m.name.rstrip('/'): m for m in stream.getmembers()}
        def owned_nonempty_file(name):
            seen = set()
            while name not in seen:
                seen.add(name)
                if not name.startswith(root + '/'):
                    return False
                item = members.get(name)
                if item is None:
                    return False
                if item.isfile():
                    return item.size > 0
                if item.islnk():
                    name = posixpath.normpath(item.linkname)
                elif item.issym() and not item.linkname.startswith('/'):
                    name = posixpath.normpath(posixpath.join(posixpath.dirname(name), item.linkname))
                else:
                    return False
            return False
        missing = [name for name in REQUIRED if not owned_nonempty_file(root + '/' + name)]
        loader = 'ld-linux-aarch64.so.1' if architecture == 'aarch64' else 'ld-linux-x86-64.so.2'
        for name in ('lib/' + loader, 'lib/libc.so.6'):
            if root + '/' + name not in members:
                missing.append(name)
        alias = members.get(root + '/lib64')
        if not alias or not alias.issym() or alias.linkname != 'lib':
            missing.append('lib64 -> lib')
    with Path(archive).open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    return {'scope': 'offline archive inventory; native runtime gates remain required',
            'archive': Path(archive).name, 'architecture': architecture,
            'revision': revision, 'sha256': digest,
            'status': 'failed' if missing else 'passed', 'missing': missing}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--arch', choices=('x86_64', 'aarch64'), required=True)
    parser.add_argument('--revision', type=int, required=True)
    args = parser.parse_args()
    report = inspect(args.archive, args.arch, args.revision)
    print(json.dumps(report, indent=2))
    raise SystemExit(1 if report['status'] != 'passed' else 0)


if __name__ == '__main__':
    main()
