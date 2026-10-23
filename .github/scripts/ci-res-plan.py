#!/usr/bin/env python3
"""Filter native resource builds before GitHub expands their runner matrix."""
import argparse
import json
from pathlib import Path


def select(entries, only):
    selected = [e for e in entries if not only or e['what'] == only]
    if not selected:
        raise ValueError('Unknown resource: ' + only)
    return {'include': selected}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--only', default='')
    ap.add_argument('--github-output', type=Path, required=True)
    args = ap.parse_args()
    result = select(json.loads(Path('.github/res-build-matrix.json').read_text()), args.only)
    print(json.dumps(result, indent=2))
    with args.github_output.open('a') as f:
        f.write('matrix=' + json.dumps(result, separators=(',', ':')) + '\n')
