#!/usr/bin/env python3
"""Refuse a payload archive that holds hard-link entries.

xlings extracts a hard-link entry with link(2). Android's app sandbox refuses
link(2), and so do FAT and exFAT; an xlings older than 2026.10.10.2 then fails
the whole install ("write_header(...): Can't create"), and a newer one copies
the file instead. A payload therefore stores each file as itself: `tar
--hard-dereference`, or .agents/tools/dereference-hard-links.py on an archive
that already exists.

Checked: every tar archive (.tar.gz, .tgz, .tar.xz, .txz, .tar.bz2, .tar)
whose URL is a literal on a line this change adds under pkgs/. One URL per
archive name is read, preferring a mirror other than gitcode.com. Not checked:
zip (no hard-link entries exist in it), .tar.zst (no reader in Python's
standard library), and URLs built from a template (XLINGS_RES) -- listed as
such, so an unchecked archive is never mistaken for a checked one.

Usage: check-payload-hard-links.py --base <git-ref> [--head <git-ref>]
"""
import argparse
import re
import subprocess
import sys
import tarfile
import urllib.request

URL = re.compile(r'https?://[^\s"\']+')
TAR = ('.tar.gz', '.tgz', '.tar.xz', '.txz', '.tar.bz2', '.tar')


def added_lines(base, head):
    diff = subprocess.run(['git', 'diff', '--unified=0', base, head, '--', 'pkgs/'],
                          capture_output=True, text=True, check=True).stdout
    return [line[1:] for line in diff.splitlines()
            if line.startswith('+') and not line.startswith('+++')]


def hard_links(url):
    with urllib.request.urlopen(url, timeout=600) as response:
        with tarfile.open(fileobj=response, mode='r|*') as archive:
            return [member.name for member in archive if member.islnk()]


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--base', required=True)
    parser.add_argument('--head', default='HEAD')
    args = parser.parse_args()

    by_name, unchecked = {}, []
    for line in added_lines(args.base, args.head):
        if 'XLINGS_RES' in line:
            unchecked.append(f'template: {line.strip()}')
        for url in URL.findall(line):
            name = url.rsplit('/', 1)[-1]
            if name.endswith('.tar.zst'):
                unchecked.append(f'zstd: {url}')
                continue
            if not name.endswith(TAR):
                continue
            if name not in by_name or 'gitcode.com' in by_name[name]:
                by_name[name] = url

    failed = False
    for name, url in sorted(by_name.items()):
        links = hard_links(url)
        if links:
            failed = True
            shown = ', '.join(links[:5]) + (' ...' if len(links) > 5 else '')
            print(f'FAIL {name}: {len(links)} hard-link entries ({shown})')
        else:
            print(f'ok   {name}')
    for item in unchecked:
        print(f'not checked, {item}')
    if not by_name:
        print('no new tar payload URL in this change')
    if failed:
        print('\nRepack without hard links: tar --hard-dereference, or '
              '.agents/tools/dereference-hard-links.py IN OUT on an existing archive.')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
