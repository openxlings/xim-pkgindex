#!/usr/bin/env python3
"""Plan CI before allocating platform runners; unknown Lua stays conservative."""
from __future__ import annotations
import argparse
import os
import fnmatch
import json
import re
import subprocess
from pathlib import Path

PLATFORMS = {'linux': 'ubuntu-latest', 'windows': 'windows-latest', 'macosx': 'macos-latest'}
# Recipes per install job. A change to glibc plans its reverse closure, about
# 190 recipes on linux; one job tested 120 of them in its 60-minute limit
# (openxlings/xim-pkgindex#1044). Forty fit with room to spare.
INSTALL_SHARD_SIZE = 40
IMPORT = re.compile(r'\bimport\s*\(\s*["\']xim\.pkgindex\.([^"\']+)["\']')


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, text=True).strip()


def snapshot(root, ref):
    names = git(root, 'ls-tree', '-r', '--name-only', ref, '--', 'pkgs', 'libs').splitlines()
    return {name: git(root, 'show', f'{ref}:{name}') for name in names if name.endswith('.lua')}


# These root fields describe discovery/rendering, not installation. Identity,
# resources, architecture, dependencies, exports, expressions and hooks stay.
DISPLAY_FIELDS = {'description', 'homepage', 'repo', 'docs', 'authors',
                  'maintainers', 'categories', 'keywords', 'licenses', 'status'}


def runtime_inputs(signature):
    node, prefix, suffix = signature
    kind, fields = node
    if kind == 'table':
        node = (kind, {k: v for k, v in fields.items() if k not in DISPLAY_FIELDS})
    return node, prefix, suffix


def runtime_changed(before, after):
    if before is None or after is None:
        return True
    try:
        from xpkgindex_update.manifest import runtime_signature
        return runtime_inputs(runtime_signature(before)) != runtime_inputs(runtime_signature(after))
    except (ImportError, ValueError, RuntimeError):
        # Legacy opaque descriptors are install-tested, never silently dropped.
        return before != after


def supported_platforms(source):
    # Explicit xpm table keys are the common form. If evaluation is dynamic,
    # let each platform's existing recipe reader decide whether it supports it.
    try:
        from xpkgindex_update.lua_edit import parse
        xpm = parse(source).fields['xpm'].fields
        platforms = set(xpm) & set(PLATFORMS)
        if platforms:
            return platforms
    except (ImportError, ValueError, KeyError, AttributeError):
        pass
    return set(PLATFORMS)


# A dependency is named by its coordinate, `<namespace>:<name>[@<version or range>]`, anywhere in a
# recipe (a `deps` table, or an expression such as pkginfo.dep_install_dir("xim:jdk")); a bare name
# is one only inside a `deps` table. Other bare strings -- keywords, categories, program names,
# paths -- are not dependencies: "desktop" or "luban" in a keyword list planned seventy packages for
# one version of mcpp (openxlings/xim-pkgindex#1094).
COORDINATE = re.compile(r'["\']([\w+.-]+):([\w+.-]+)(?:@([^"\']*))?["\']')
DEPS_TABLE = re.compile(r'\bdeps\s*=\s*\{(.*?)\}', re.S)
BARE = re.compile(r'["\']([\w+.-]+)(?:@([^"\']*))?["\']')
EXACT = re.compile(r'^[\w.+-]+$')
VERSION_KEY = re.compile(r'\[\s*["\']([^"\']+)["\']\s*\]\s*=\s*\{')


def references(source):
    """The (name, exact version or None) a recipe depends on."""
    found = {(name, version if version and EXACT.match(version) else None)
             for _, name, version in COORDINATE.findall(source)}
    for table in DEPS_TABLE.findall(source):
        found |= {(name, version if version and EXACT.match(version) else None)
                  for name, version in BARE.findall(table) if ':' not in name}
    return found


def _block_end(source, start):
    """The index after the brace that closes the one opened at `start`, strings and comments skipped."""
    depth, i, n = 0, start, len(source)
    while i < n:
        c = source[i]
        if c in '"\'':
            i += 1
            while i < n and source[i] != c:
                i += 2 if source[i] == '\\' else 1
        elif source.startswith('--', i):
            i = source.find('\n', i)
            if i < 0:
                return n
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


def version_entries(source):
    """Each version entry's text by its version (every platform's, joined), and the recipe without them."""
    entries, rest, last = {}, [], 0
    for m in VERSION_KEY.finditer(source or ''):
        if m.start() < last:
            continue
        end = _block_end(source, m.end() - 1)
        entries.setdefault(m.group(1), []).append(source[m.start():end])
        separator = re.match(r'\s*,', source[end:])   # the entry's own separator
        if separator:
            end += separator.end()
        rest.append(source[last:m.start()])
        last = end
    rest.append((source or '')[last:])
    return {k: '\n'.join(v) for k, v in entries.items()}, ''.join(rest)


def changed_versions(before, after):
    """None when the recipe changed outside its version entries (every version is affected), else
    the versions whose entries changed. `latest` is a version entry: it moves unpinned consumers."""
    if before is None or after is None:
        return None
    b, b_rest = version_entries(before)
    a, a_rest = version_entries(after)
    if b_rest.split() != a_rest.split():   # layout aside
        return None
    return {v for v in b.keys() | a.keys() if b.get(v) != a.get(v)}


def affected(changed, before, after):
    """Reverse imports (including libs -> libs) and package dependencies.

    Read both trees so removing/renaming an import or provider cannot hide
    consumers. A consumer pinned to an exact version is affected only when that
    version's entry changed or the recipe changed outside its entries; one that
    names a range or no version is affected by any change. A consumer reached
    through another counts as wholly changed.
    """
    sources = {k: '\n'.join(d[k] for d in (before, after) if k in d) for k in before.keys() | after.keys()}
    # A name can be two recipes' (xim:xdesk and luban:xdesk), and a namespace's directory is not its
    # name (subos:luban-core is pkgs/luban/): a reference reaches every recipe of its name.
    names = {}
    for p in sources:
        if p.startswith('pkgs/'):
            names.setdefault(Path(p).stem, set()).add(p)
    reverse = {}
    for path, source in sources.items():
        for module in IMPORT.findall(source):
            reverse.setdefault('libs/' + module.replace('.', '/') + '.lua', set()).add((path, None))
        if path.startswith('pkgs/'):
            for name, version in references(source):
                for provider in names.get(name, ()):
                    if provider != path:
                        reverse.setdefault(provider, set()).add((path, version))
    versions = {p: changed_versions(before.get(p), after.get(p)) for p in changed if p.startswith('pkgs/')}
    visited, todo = set(changed), list(changed)
    while todo:
        provider = todo.pop()
        touched = versions.get(provider)
        for consumer, pin in reverse.get(provider, ()):
            if consumer in visited or (pin is not None and touched is not None and pin not in touched):
                continue
            visited.add(consumer)
            todo.append(consumer)
    return sorted(p for p in visited if p.startswith('pkgs/') and p in after)


def matches(paths, patterns):
    return any(fnmatch.fnmatchcase(p, pattern) for p in paths for pattern in patterns)


def plan(changed, before, after, profiles, *, force=False):
    changed = sorted(set(changed))
    runtime = [p for p in changed if p.startswith('libs/') or
               (p.startswith('pkgs/') and runtime_changed(before.get(p), after.get(p)))]
    packages = affected(runtime, before, after)
    framework = matches(changed, ['.github/workflows/ci.yml', '.github/workflows/ci-test.yml',
        '.github/scripts/ci-plan.py', '.github/scripts/ci-required.py', '.github/actions/setup-xlings/*',
        '.github/scripts/posix-test.sh', '.github/scripts/windows-test.ps1',
        '.github/scripts/dep-closure-check.sh', '.github/scripts/parse-xpkg-meta.py',
        'tests/lib/*', 'tests/test_ci_architecture.py'])
    if framework:
        # Small real payloads exercise desktop layouts and data/group cleanup
        # on every host. This does not replace affected-package expansion.
        packages = sorted(set(packages) | {p for p in ('pkgs/e/eden.lua', 'pkgs/e/eden-android.lua') if p in after})
    if force:
        packages = sorted(p for p in after if p.startswith('pkgs/'))
    matrix = []
    for platform, runner in PLATFORMS.items():
        files = [p for p in packages if platform in supported_platforms(after[p])]
        shards = -(-len(files) // INSTALL_SHARD_SIZE)
        for i in range(shards):
            # Each shard installs its own files, and places all of the platform's first: a
            # dependency the PR changes or adds may sit in another shard.
            entry = {'platform': platform, 'os': runner, 'files': ' '.join(files[i::shards]),
                     'overlay': ' '.join(files)}
            if shards > 1:
                entry['shard'] = f'{i + 1}/{shards}'
            matrix.append(entry)
    flags = {name: force or matches(changed + packages, config['paths']) for name, config in profiles.items()}
    if framework:
        flags.update(ci_xpkg_test=True, ci_tools=True, eden_smoke=True)
    if '.github/ci-profiles.json' in changed:
        flags = {name: True for name in profiles}
    flags['ci_candidates'] = force or matches(changed, ['pkgs/*', 'tests/test_autoupdate*',
        '.github/scripts/autoupdate*', 'tools/autoupdate_policy.py', '.github/xpkgindex-update.yml',
        '.github/workflows/ci-candidates.yml', '.github/workflows/xpkgindex-update.yml'])
    closure = force or bool(set(packages) & {'pkgs/n/ncurses.lua', 'pkgs/g/glibc.lua', 'pkgs/g/gcc-runtime.lua'}) or framework
    # Only resource declarations require a remote archive probe. Script changes
    # still select the profile and its unit tests through the route registry.
    return {'changed': changed, 'packages': packages, 'install_matrix': {'include': matrix},
            'flags': flags, 'closure': closure, 'framework': framework}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--base', required=True)
    ap.add_argument('--head', default='HEAD')
    ap.add_argument('--output', default='ci-plan.json')
    ap.add_argument('--github-output', type=Path)
    ap.add_argument('--force', action='store_true')
    args = ap.parse_args()
    root = Path.cwd()
    base = git(root, 'rev-parse', '--verify', args.base + '^{commit}')
    head = git(root, 'rev-parse', '--verify', args.head + '^{commit}')
    changed = git(root, 'diff', '--name-only', '--no-renames', base, head).splitlines()
    profiles = json.loads((root / '.github/ci-profiles.json').read_text())
    result = plan(changed, snapshot(root, base), snapshot(root, head), profiles, force=args.force)
    result.update(base_sha=base, head_sha=head)
    Path(args.output).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if args.github_output:
        values = {k: str(v).lower() for k,v in result['flags'].items()}
        values.update(base_sha=base, head_sha=head, install=str(bool(result['install_matrix']['include'])).lower(),
                      matrix=json.dumps(result['install_matrix'], separators=(',', ':')), closure=str(result['closure']).lower(),
                      files=' '.join(sorted(set(result['changed'] + result['packages']))))
        with args.github_output.open('a') as f:
            for key, value in values.items(): f.write(f'{key}={value}\n')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a') as f:
            f.write('## CI plan\n\nComparison: `' + base + '` → `' + head + '`\n\n')
            f.write('```json\n' + json.dumps(result, indent=2) + '\n```\n')


if __name__ == '__main__':
    main()
