#!/usr/bin/env python3
"""Use the updater's structural runtime comparison to select installation tests."""
import json
import os
import subprocess
from pathlib import Path

base = os.environ['BASE']
if not base or set(base) == {'0'}:
    base = 'HEAD^'
subprocess.run(['python', '-m', 'xpkgindex_update', 'runtime-diff', '--base', base,
                '--output', 'runtime-diff.json'], check=True)
records = json.loads(Path('runtime-diff.json').read_text())['packages']
files = [r['path'] for r in records if r['status'] == 'runtime-changed']
print(json.dumps(records, indent=2))
with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
    output.write('files=' + ' '.join(files) + '\n')
    output.write('any_changed=' + str(bool(files)).lower() + '\n')
