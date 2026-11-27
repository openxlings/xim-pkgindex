#!/usr/bin/env python3
"""Index CI orchestration; parsing and update semantics come from the pinned updater."""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

from xpkgindex_update.adapters import xim_pkgindex as xim
from xpkgindex_update.lua_edit import Invalid, parse, tokens
from xpkgindex_update.manifest import assert_preserved, descriptor_digest, ordered

ROOT = Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0, str(ROOT))
from tools.autoupdate_policy import rollout_reason


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def audit():
    files = sorted((ROOT / 'pkgs').glob('*/*.lua'))
    enabled, rows = [], []
    for path in files:
        text = path.read_text(encoding='utf-8')
        row = {'path': path.relative_to(ROOT).as_posix()}
        try:
            pkg = parse(text).fields
        except Invalid as exc:
            # Legacy expressions may be opaque, but a broken opt-in must not
            # silently fall back to manual maintenance. The lexer ignores comments.
            if any(t.kind in ('word', 'string') and t.value == 'autoupdate' for t in tokens(text)):
                raise
            rows.append({**row, 'status': 'manual', 'reason': f'unsupported literal metadata: {exc}'})
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
            reason = rollout_reason({}, info['autoupdate'])
            if reason:
                raise Invalid(f'{path}: {reason}')
            installation_targets, resource_only_targets = set(), set()
            for platform, arches in xim.matrix(info).items():
                for arch in arches:
                    hosts = shared_arches(info, info['platforms'][platform]['entries'][xim.latest_refs(info)[platform]], next(iter(arches[arch].values()))) if arch == 'shared' else {arch}
                    for host in hosts:
                        targets = installation_targets if native_runner(platform, host) else resource_only_targets
                        targets.add(f'{platform}/{host}')
            enabled.append(info['id'])
            rows.append({**row, 'id': info['id'], 'status': 'enabled',
                         'targets': list(info['autoupdate']['resources']),
                         'installation_targets': sorted(installation_targets),
                         'resource_only_targets': sorted(resource_only_targets)})
        else:
            rows.append({**row, 'status': 'manual', 'reason': 'no extensions.autoupdate declaration'})
    return {'total': len(files), 'enabled': enabled, 'manual': len(files) - len(enabled),
            'packages': rows}


def native_runner(platform, arch):
    # Upstream assets do not imply xlings release support. These known targets
    # retain resource verification, but must not create native installation jobs.
    if (platform, arch) in {('macosx', 'x86_64'), ('windows', 'aarch64')}:
        return None
    runner = {'linux': {'x86_64': 'ubuntu-latest', 'aarch64': 'ubuntu-24.04-arm'},
              'macosx': {'aarch64': 'macos-latest'},
              'windows': {'x86_64': 'windows-latest'}}.get(platform, {}).get(arch)
    if not runner:
        raise Invalid(f'no validated xlings execution environment for {platform}/{arch}')
    return runner


def shared_arches(info, entry, template=None):
    # One artifact named for its architectures (`sha256 = { x86_64 = h }`):
    # those, whatever its file name or `package.archs` say.
    named = xim.named_artifact(entry)
    if named:
        return set(named)
    try:
        resource = entry.plain()
    except Invalid:
        resource = {}
    resource = resource if isinstance(resource, dict) else {}
    url = template or resource.get('url', '')
    url = url.get('GLOBAL', '') if isinstance(url, dict) else url
    if re.search(r'(?:aarch64|arm64)', url):
        return {'aarch64'}
    if re.search(r'(?:x86_64|amd64|x64)', url):
        return {'x86_64'}
    declared = info['package'].get('archs')
    if not declared:
        raise Invalid('shared resource needs explicit supported host architectures')
    return {{'arm64': 'aarch64', 'amd64': 'x86_64', 'i386': 'x86'}.get(node.string(), node.string()) for node in declared.fields.values()}


def candidates(base):
    jobs = []
    # New descriptors use normal package CI; this matrix validates upgrades.
    changed = git('diff', '--name-only', '--diff-filter=M', base, 'HEAD', '--', 'pkgs').splitlines()
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
                    arches = shared_arches(info, entry)
                for arch in sorted(arches):
                    runner = native_runner(platform, arch)
                    if runner is None:
                        continue
                    jobs.append({'id': info['id'], 'path': filename, 'version': version,
                                 'platform': platform, 'arch': arch, 'os': runner})
    return {'include': jobs}


def summarize_coverage(report):
    """Make the installation boundary visible alongside the full JSON audit."""
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if not summary:
        return
    enabled = [row for row in report['packages'] if row['status'] == 'enabled']
    native = sorted({target for row in enabled for target in row['installation_targets']})
    resource_only = sorted({target for row in enabled for target in row['resource_only_targets']})
    with Path(summary).open('a', encoding='utf-8') as output:
        output.write('### Automatic update validation coverage\n\n')
        output.write('Native installation targets: ' + ', '.join(native) + '.\n\n')
        output.write('Resource verification only (no installation validation): '
                     + (', '.join(resource_only) or 'none') + '.\n\n')
        output.write('Every added candidate resource is verified independently of the native job matrix. '
                     'See coverage.json for each package and candidate-evidence.json for actual installations.\n')


def run_candidate(identity, filename, version, expected_arch=None):
    path = ROOT / filename
    info = xim.package_info(path, ROOT)
    if info['id'] != identity:
        raise Invalid('candidate identity differs from its descriptor')
    if expected_arch:
        import platform
        actual = {'amd64': 'x86_64', 'arm64': 'aarch64'}.get(platform.machine().lower(), platform.machine().lower())
        if actual != expected_arch:
            raise Invalid(f'candidate runner architecture differs: {actual} != {expected_arch}')
    xlings = 'xlings'
    subprocess.run([xlings, 'update', '--yes', '--agent'], check=True)
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
    os.environ['PATH'] = str(home / 'subos/default/bin') + os.pathsep + os.environ['PATH']
    programs = info['package'].get('programs')
    outputs = {}
    for node in (programs.fields.values() if programs else []):
        program = node.string()
        # Only flags explicitly supported by the package's own verification are used below.
        # Generic smoke checks prove registered executable presence; package tests prove behavior.
        import shutil
        executable = shutil.which(program)
        if not executable or not Path(executable).absolute().is_relative_to(home):
            raise Invalid('candidate executable is not registered in the isolated home: ' + program)
        probe_args = ['version'] if (name, program) == ('go', 'go') else ['--version'] if name in ('uv', 'oh-my-pi') else None
        if probe_args:
            probe = subprocess.run([executable, *probe_args], check=True, capture_output=True, text=True)
            if version not in probe.stdout:
                raise Invalid('registered executable reports the wrong candidate version')
            outputs[program] = probe.stdout.strip()
    test_file = ROOT / 'tests' / path.parent.name / ('test_' + name.replace('-', '_').replace('.', '_') + '.py')
    if test_file.exists():
        subprocess.run([sys.executable, '-m', 'pytest', str(test_file), '-m', 'verify', '-q'], check=True,
                       env={**os.environ, 'XLINGS_TEST_SUBOS': 'default', 'XLINGS_TEST_VERSION': version})
    evidence = {'id': identity, 'version': version, 'descriptor': filename,
                'descriptor_sha256': descriptor_digest(path.read_bytes().decode('utf-8')),
                'checkout_commit': git('rev-parse', 'HEAD'), 'runner_arch': expected_arch,
                'install_dirs': [str(d) for d in installs], 'program_versions': outputs, 'status': 'installed'}
    write('candidate-evidence.json', evidence)
    subprocess.run([xlings, 'remove', target, '-y'], check=True)
    if any(d.exists() for d in installs):
        raise Invalid('candidate payload survived uninstall')
    evidence.update(status='verified-and-removed', removed=True)
    write('candidate-evidence.json', evidence)


# The revision gate: it loads each recipe as the clients of each architecture
# did, so it is what can tell a change of form from a change of resource.
CHECK_REVISION = Path(__file__).resolve().parent / 'check-revision.lua'


def _lua():
    for name in ('lua5.4', 'lua5.3', 'lua'):
        path = shutil.which(name)
        if path and subprocess.run([path, '-e', 'os.exit(math.type ~= nil and 0 or 1)'],
                                   capture_output=True).returncode == 0:
            return path
    return None


def equivalent_entries(base):
    """Published entries whose text changed while every architecture still
    installs the same resource at the same revision and floor (check-revision.lua
    --equivalent): a digest written per architecture, a URL a recipe picked with
    os.arch() written as a template. Empty without Lua 5.3+, and then a changed
    text is a changed entry, as before."""
    lua = _lua()
    if not lua:
        return set()
    result = subprocess.run([lua, str(CHECK_REVISION), '--base', base, '--equivalent', str(ROOT)],
                            capture_output=True, text=True)
    found = set()
    for line in result.stdout.splitlines():
        parts = line.split('\t')
        if len(parts) == 4 and parts[0] == 'equivalent':
            found.add((parts[1], parts[2], parts[3]))
    return found


def adopt_equivalent(before, after, filename, equivalent):
    """`before` with the entries `equivalent` names for `filename` written as
    `after` writes them, so that the updater's guard -- which compares a
    published entry as text -- sees what did not change as unchanged. Every
    other entry, and everything else the guard checks, is left to it."""
    wanted = sorted((plat, version) for name, plat, version in equivalent if name == filename)
    if not wanted:
        return before
    old_xpm, new_xpm = parse(before).fields.get('xpm'), parse(after).fields.get('xpm')
    if not old_xpm or not new_xpm:
        return before
    edits = []
    for plat, version in wanted:
        old_plat, new_plat = old_xpm.fields.get(plat), new_xpm.fields.get(plat)
        old_node = old_plat.fields.get(version) if old_plat else None
        new_node = new_plat.fields.get(version) if new_plat else None
        if old_node is not None and new_node is not None:
            edits.append((old_node.start, old_node.end, after[new_node.start:new_node.end]))
    for start, end, text in sorted(edits, reverse=True):
        before = before[:start] + text + before[end:]
    return before


def declares_autoupdate(text):
    ext = parse(text).fields.get('extensions')
    return bool(ext and ext.fields.get('autoupdate'))


def guard(base, reviewed=False):
    """A pull request's recipes against its base. Published versions are kept in
    every recipe -- a change of form the revision gate proves to install the same
    bytes on every architecture is no change (equivalent_entries). A recipe declaring extensions.autoupdate also keeps its latest
    policy: latest moves only by advance, to a newly appended version. What only
    an automatic update must leave alone -- dependencies, other metadata, hooks --
    is frozen unless the change is reviewed (anything but an updater branch,
    ci-candidates.yml): a reviewed change may correct a hook, and package CI
    installs it. One nobody's bot writes (a hand-kept edition, a package xlings'
    release writes: tests/test_release_owned.py) moves its latest by review."""
    files = git('ls-tree', '-r', '--name-only', base, '--', 'pkgs').splitlines()
    changed = []
    equivalent = equivalent_entries(base)
    for filename in files:
        if not filename.endswith('.lua'):
            continue
        path = ROOT / filename
        if not path.exists():
            raise Invalid(f'existing descriptor was removed: {filename}')
        before = subprocess.check_output(['git', 'show', f'{base}:{filename}'], cwd=ROOT, text=True, encoding='utf-8')
        after = path.read_text(encoding='utf-8')
        if before == after:
            continue
        before = adopt_equivalent(before, after, filename, equivalent)
        try:
            if declares_autoupdate(after):
                xim.guard(before, after, reviewed=reviewed)
            else:
                assert_preserved(before, after)
        except Invalid as e:
            raise Invalid(f'{filename}: {e}') from e
        changed.append({'path': filename, 'rules': 'automatic' if declares_autoupdate(after) else 'preserved'})
    return {'checked_descriptors': len(files), 'status': 'preserved', 'changed': changed}


def verify(base, reviewed=False, output=None):
    """The updater's verification of the versions a change adds to a recipe that
    declares autoupdate (`python -m xpkgindex_update verify`: each resource
    downloaded and hashed, no release discovered), whose own guard reads the
    base as guard() does: the entries the revision gate proves equivalent are
    written as the head writes them."""
    from xpkgindex_update.cli import config as updater_config, write_report
    from xpkgindex_update.github import GitHub
    policy = updater_config(ROOT)
    github = GitHub(None, request_budget=policy['request_budget'], resource_bytes=policy['resource_bytes'],
                    download_bytes=policy['download_bytes'])
    equivalent = equivalent_entries(base)
    records = []
    for filename in git('diff', '--name-only', '--diff-filter=M', base, 'HEAD', '--', 'pkgs').splitlines():
        path = ROOT / filename
        if not filename.endswith('.lua') or not path.exists():
            continue
        info = xim.package_info(path, ROOT)
        if not info['autoupdate']:
            continue
        before = subprocess.check_output(['git', 'show', f'{base}:{filename}'], cwd=ROOT, text=True, encoding='utf-8')
        try:
            records.extend(xim.verify_candidates(info, adopt_equivalent(before, info['text'], filename, equivalent),
                                                 github, reviewed=reviewed))
        except Invalid as e:
            raise Invalid(f'{filename}: {e}') from e
    write_report({'packages': records, 'requests': github.requests, 'downloaded_bytes': github.downloaded}, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['audit', 'matrix', 'candidate', 'guard', 'verify'])
    parser.add_argument('--base', default='origin/main')
    parser.add_argument('--output', default='autoupdate-report.json')
    parser.add_argument('--package')
    parser.add_argument('--path')
    parser.add_argument('--version')
    parser.add_argument('--arch')
    parser.add_argument('--reviewed', action='store_true',
                        help='a reviewed change may correct dependencies, metadata and hooks')
    args = parser.parse_args()
    if args.command == 'candidate':
        run_candidate(args.package, args.path, args.version, args.arch)
    elif args.command == 'audit':
        report = audit()
        write(args.output, report)
        summarize_coverage(report)
    elif args.command == 'verify':
        verify(args.base, args.reviewed, args.output)
    else:
        write(args.output, guard(args.base, args.reviewed) if args.command == 'guard'
              else candidates(args.base))


if __name__ == '__main__':
    main()
