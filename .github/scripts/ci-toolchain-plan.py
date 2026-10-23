#!/usr/bin/env python3
"""Each affected toolchain is tested on its real consumer platforms."""
import argparse
import json
from pathlib import Path

RECIPES = {'llvm': 'pkgs/l/llvm.lua', 'gcc': 'pkgs/g/gcc.lua', 'musl-gcc': 'pkgs/m/musl-gcc.lua'}


def select(files):
    tools = [tool for tool, recipe in RECIPES.items() if recipe in files]
    # Executor-only changes exercise the LLVM baseline on both supported hosts.
    tools = tools or ['llvm']
    return {'include': [dict(tool=tool, recipe=RECIPES[tool], os=runner, platform=platform)
                        for tool in tools for platform, runner in [('linux','ubuntu-latest'), ('macos','macos-latest')]
                        if tool == 'llvm' or platform == 'linux']}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--files', default='')
    ap.add_argument('--github-output', type=Path, required=True)
    args = ap.parse_args()
    with args.github_output.open('a') as f:
        f.write('matrix=' + json.dumps(select(args.files.split()), separators=(',',':')) + '\n')
