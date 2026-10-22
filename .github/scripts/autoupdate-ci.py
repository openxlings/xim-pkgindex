#!/usr/bin/env python3
"""Index CI orchestration; parsing and update semantics come from the pinned updater."""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path

from xpkgindex_update.adapters import xim_pkgindex as xim
from xpkgindex_update.lua_edit import Invalid, parse
from xpkgindex_update.manifest import ordered

ROOT = Path(__file__).resolve().parents[2]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def audit():
    snapshot = json.loads((ROOT / '.agents/docs/2026-10-22-autoupdate-package-audit.json').read_text())
    rows = {r['path']: r for r in snapshot['packages']}
    files = sorted((ROOT / 'pkgs').glob('*/*.lua'))
    if set(rows) != {p.relative_to(ROOT).as_posix() for p in files}:
        raise Invalid('coverage inventory does not cover the complete index')
    enabled = []
    for path in files:
        row = rows[path.relative_to(ROOT).as_posix()]
        try:
            pkg = parse(path.read_text()).fields
        except Invalid:
            if row['status'] != 'manual' or not row.get('reason'):
                raise
            continue
        ci = pkg.get('ci')
        if ci and 'update' in ci.table():
            raise Invalid(f'legacy ci.update remains: {path}')
        xpm = pkg.get('xpm')
        if xpm and xpm.kind == 'table':
            for platform in xpm.fields.values():
                if platform.kind == 'table' and {'url_template', 'res_versioned'} & platform.fields.keys():
                    raise Invalid(f'legacy update marker remains: {path}')
        extension = pkg.get('extensions')
        auto = extension.fields.get('autoupdate') if extension else None
        if auto:
            info = xim.package_info(path, ROOT)
            xim.validate_config(info)
            if row['status'] != 'enabled' or row.get('stars', 0) <= 50 or info['autoupdate'] != row['autoupdate']:
                raise Invalid(f'declaration differs from approved coverage inventory: {path}')
            enabled.append(info['id'])
        elif row['status'] != 'manual' or not row.get('reason'):
            raise Invalid(f'unclassified package or missing update support: {path}')
    return {'total': len(files), 'enabled': enabled, 'manual': len(files) - len(enabled)}


def candidates(base):
    jobs = []
    changed = git('diff', '--name-only', base, 'HEAD', '--', 'pkgs').splitlines()
    for filename in changed:
        if not filename.endswith('.lua') or not (ROOT / filename).exists():
            continue
        try:
            info = xim.package_info(ROOT / filename, ROOT)
        except Invalid:
            continue
        if not info['autoupdate']:
            continue
        try:
            before = parse(git('show', f'{base}:{filename}')).fields.get('xpm')
        except Invalid:
            before = None
        for platform, data in info['platforms'].items():
            previous = before.fields.get(platform) if before else None
            old = set(previous.fields) if previous else set()
            for version, entry in data['entries'].items():
                if version in old or not ordered(version):
                    continue
                arches = xim.entry_arches(entry)
                if not arches:
                    resource = entry.plain()
                    url = resource.get('url', '')
                    url = url.get('GLOBAL', '') if isinstance(url, dict) else url
                    if re.search(r'aarch64|arm64', url):
                        arches = {'aarch64'}
                    else:
                        arches = {'x86_64'}
                for arch in sorted(arches):
                    runner = {'linux': {'x86_64': 'ubuntu-latest', 'aarch64': 'ubuntu-24.04-arm',
                                        'x86': 'ubuntu-latest'},
                              'macosx': {'x86_64': 'macos-15-intel', 'aarch64': 'macos-latest'},
                              'windows': {'x86_64': 'windows-latest', 'aarch64': 'windows-11-arm',
                                          'x86': 'windows-latest'}}.get(platform, {}).get(arch)
                    if not runner:
                        raise Invalid(f'no validated runner for {info["id"]} {platform}/{arch}')
                    jobs.append({'id': info['id'], 'path': filename, 'version': version,
                                 'platform': platform, 'arch': arch, 'os': runner})
    return {'include': jobs}


def run_candidate(identity, filename, version):
    path = ROOT / filename
    info = xim.package_info(path, ROOT)
    if info['id'] != identity:
        raise Invalid('candidate identity differs from its descriptor')
    xlings = 'xlings'
    subprocess.run([xlings, 'update'], check=True)
    subprocess.run([xlings, 'config', '--add-xpkg', str(path)], check=True)
    name = identity.split(':', 1)[-1]
    # Overlay registration uses the local namespace; this is a clean runner home.
    target = 'local:' + name + '@' + version
    subprocess.run([xlings, 'install', target, '-y'], check=True)
    home = Path(os.environ.get('XLINGS_HOME', Path.home() / '.xlings'))
    installs = list((home / 'data/xpkgs').glob('*-x-' + name + '/' + version))
    if not installs or not any((d / '.xpkg.lua').exists() for d in installs):
        raise Invalid('candidate installation metadata not found')
    if not any(len(list(d.iterdir())) > 1 for d in installs):
        raise Invalid('candidate installation has metadata but no payload')
    programs = info['package'].get('programs')
    outputs = {}
    for node in (programs.fields.values() if programs else []):
        program = node.string()
        # Only flags explicitly supported by the package's own verification are used below.
        # Generic smoke checks prove registered executable presence; package tests prove behavior.
        import shutil
        executable = shutil.which(program)
        if not executable:
            raise Invalid('candidate executable is not registered: ' + program)
        if name == 'uv':
            probe = subprocess.run([executable, '--version'], check=True, capture_output=True, text=True)
            if version not in probe.stdout:
                raise Invalid('registered executable reports the wrong candidate version')
            outputs[program] = probe.stdout.strip()
    test_file = ROOT / 'tests' / path.parent.name / ('test_' + name.replace('-', '_').replace('.', '_') + '.py')
    if test_file.exists():
        subprocess.run(['python', '-m', 'pytest', str(test_file), '-m', 'verify', '-q'], check=True)
    evidence = {'id': identity, 'version': version, 'descriptor': filename,
                'descriptor_sha256': __import__('hashlib').sha256(path.read_bytes()).hexdigest(),
                'install_dirs': [str(d) for d in installs], 'program_versions': outputs, 'status': 'installed'}
    write('candidate-evidence.json', evidence)
    subprocess.run([xlings, 'remove', target, '-y'], check=True)
    if any(d.exists() for d in installs):
        raise Invalid('candidate payload survived uninstall')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['audit', 'matrix', 'candidate'])
    parser.add_argument('--base', default='origin/main')
    parser.add_argument('--output', default='autoupdate-report.json')
    parser.add_argument('--package')
    parser.add_argument('--path')
    parser.add_argument('--version')
    args = parser.parse_args()
    if args.command == 'candidate':
        run_candidate(args.package, args.path, args.version)
    else:
        write(args.output, audit() if args.command == 'audit' else candidates(args.base))


if __name__ == '__main__':
    main()
