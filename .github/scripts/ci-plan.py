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
STRINGS = re.compile(r'["\']([\w:+.@-]+)["\']')


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


def affected(changed, before, after):
    """Reverse imports (including libs -> libs) and package dependencies.

    Read both trees so removing/renaming an import or provider cannot hide
    consumers. Literal package coordinates also cover legacy expression-based
    deps; an extra match is safe, whereas a missing consumer is not.
    """
    sources = {k: '\n'.join(d[k] for d in (before, after) if k in d) for k in before.keys() | after.keys()}
    names = {Path(p).stem: p for p in sources if p.startswith('pkgs/')}
    reverse = {}
    for path, source in sources.items():
        for module in IMPORT.findall(source):
            reverse.setdefault('libs/' + module.replace('.', '/') + '.lua', set()).add(path)
        if path.startswith('pkgs/'):
            for token in STRINGS.findall(source):
                name = token.split(':')[-1].split('@')[0]
                if name in names and names[name] != path:
                    reverse.setdefault(names[name], set()).add(path)
    visited, todo = set(changed), list(changed)
    while todo:
        for consumer in reverse.get(todo.pop(), ()):
            if consumer not in visited:
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
            entry = {'platform': platform, 'os': runner, 'files': ' '.join(files[i::shards])}
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
