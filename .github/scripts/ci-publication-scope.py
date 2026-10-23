#!/usr/bin/env python3
"""Publish only content relevant to this destination, from the verified SHA."""
import argparse
import fnmatch
import subprocess
from pathlib import Path

INDEX = ['pkgs/**', 'libs/**', 'xim-indexrepos.lua', 'index-compat.json', '.xpkgindex.json',
         'tools/build_xim_index_artifact.sh', 'tools/publish_xim_index.sh',
         'tools/push_index_pointers.sh', '.github/workflows/publish-artifact.yml',
         '.github/scripts/ci-publication-scope.py', '.github/scripts/ci-verified-source.py']
SITE = ['pkgs/**', 'docs/**', 'README.md', 'README.zh.md', '.xpkgindex/**', '.xpkgindex.json', '.github/workflows/pkgindex-deloy.yml',
        '.github/scripts/ci-publication-scope.py', '.github/scripts/ci-verified-source.py']


def selected(paths, target):
    return any(fnmatch.fnmatchcase(p, pattern) for p in paths for pattern in (INDEX if target == 'index' else SITE))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--target', choices=['index','site'], required=True)
    ap.add_argument('--event', required=True)
    ap.add_argument('--github-output', type=Path, required=True)
    args = ap.parse_args()
    # Scheduled/manual runs retain their explicit catch-up / repair semantics.
    paths = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD^', 'HEAD'], text=True).splitlines()
    changed = args.event != 'workflow_run' or selected(paths, args.target)
    print(f'{args.target}: changed={changed}; {paths}')
    with args.github_output.open('a') as f:
        f.write('changed=' + str(changed).lower() + '\n')
