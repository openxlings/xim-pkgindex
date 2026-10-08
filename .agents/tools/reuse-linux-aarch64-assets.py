#!/usr/bin/env python3
"""Reuse a successful same-repository native run with identical source builders."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

UNCHANGED_BUILDERS = ['.agents/tools/build-linux-aarch64-deps.sh', '.agents/tools/build-llvm-subpkg.sh']
BUILDERS = ['.agents/tools/build-linux-aarch64-deps.sh', '.agents/tools/build-llvm-subpkg.sh',
            '.agents/tools/graphics/build-glibc.sh', '.agents/tools/graphics/patches']


def validate(run, repository, workflow='.github/workflows/llvm-linux-aarch64.yml'):
    if run.get('conclusion') != 'success' or run.get('status') != 'completed':
        raise ValueError('source native run has not completed successfully')
    if run.get('repository', {}).get('full_name') != repository or run.get('head_repository', {}).get('full_name') != repository:
        raise ValueError('source native run must belong to the same repository, including its head')
    if run.get('path') != workflow:
        raise ValueError('source run does not use the native closure workflow')
    sha = run.get('head_sha', '')
    if not re.fullmatch('[0-9a-f]{40}', sha):
        raise ValueError('invalid source commit')
    return sha


def ensure_commit(sha):
    if not re.fullmatch('[0-9a-f]{40}', sha):
        raise ValueError('invalid provenance commit')
    if subprocess.run(['git', 'cat-file', '-e', sha + '^{commit}'],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        # Exact objects only; no branch/tag ref is rewritten. A bounded
        # history is sufficient for the reviewed source chain; otherwise
        # ancestry cannot be established and admission fails closed.
        subprocess.run(['git', 'fetch', '--no-tags', '--no-write-fetch-head',
                        '--depth=256', 'origin', sha], check=True, timeout=120)


def ancestor(source, target):
    return subprocess.run(['git', 'merge-base', '--is-ancestor', source, target],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def validate_source_history(source_sha, repository):
    ensure_commit(source_sha)
    if ancestor(source_sha, 'HEAD'):
        return
    associated = json.loads(subprocess.check_output(['gh', 'api',
        f'repos/{repository}/commits/{source_sha}/pulls'], text=True))
    for summary in associated:
        number = summary.get('number')
        if not isinstance(number, int) or isinstance(number, bool) or number <= 0:
            continue
        pr = json.loads(subprocess.check_output(['gh', 'api',
            f'repos/{repository}/pulls/{number}'], text=True))
        if (pr.get('merged') is not True
                or pr.get('base', {}).get('repo', {}).get('full_name') != repository
                or pr.get('head', {}).get('repo', {}).get('full_name') != repository):
            continue
        head_sha = pr.get('head', {}).get('sha', '')
        merge_sha = pr.get('merge_commit_sha', '')
        if not all(re.fullmatch('[0-9a-f]{40}', value) for value in (head_sha, merge_sha)):
            continue
        ensure_commit(head_sha)
        ensure_commit(merge_sha)
        if not ancestor(source_sha, head_sha) or not ancestor(merge_sha, 'HEAD'):
            continue
        source_tree = subprocess.check_output(['git', 'rev-parse', head_sha + '^{tree}'], text=True).strip()
        merged_tree = subprocess.check_output(['git', 'rev-parse', merge_sha + '^{tree}'], text=True).strip()
        if source_tree != merged_tree:
            continue
        print(f'Validated source history through merged {repository}#{number}: '
              f'head {head_sha}, equivalent merge tree {merge_sha}.', flush=True)
        return
    raise ValueError('source is neither a HEAD ancestor nor a tree-equivalent authenticated merged PR source')



# Exact archived identities from the successful native source closure. This
# exception permits replacement of glibc only, never a builder mismatch for
# LLVM/dependencies or an arbitrary previously successful artifact.
UNCHANGED_ARCHIVES = {'gcc-runtime-15.1.0-linux-aarch64.tar.gz': '86aed3a2f78f623c48fa0dffa0eb377d405343ee5c733ee96f38f598e87d8b6e', 'libxml2-2.13.5-linux-aarch64.tar.gz': '723f97d01c6a7618ace30842e1a03cfbd99965a340c1df263d31ba217cfd1cee', 'linux-headers-5.11.1-linux-aarch64.tar.gz': 'ffb294cc183e9ddb87af3411364ba09c9724390494c2f271a81e98a3d6ccfbd7', 'llvm-23.1.3-linux-aarch64.tar.gz': '8a4697b6f22703c1fb8d808a0ef6022f3a9e9111a70e7a02009b7814bdbe46a9', 'llvm-tools-23.1.3-linux-aarch64.tar.gz': 'e9c3675a170d6f1aaa21ee2fd9c8ba7c67813aab4721d87772f45a83c0c89ad2', 'zlib-1.3.1-linux-aarch64.tar.gz': '84605519e53f272c998a92bf806abace459b10937037f27e4b993d9d161546b5', 'llvm-23.1.3-linux-aarch64.tar.xz': 'fb763a21041d27ea6058df64e42dfb26456517e51f943e7caff8bed5310aa4c3', 'llvm-tools-23.1.3-linux-aarch64.tar.xz': '39357154fcfaec5e8a12ab649814d1e05c167389311feff70c8c2a0bf30d0282'}

def verify_unchanged_archives(directory):
    archives = {p.name for p in directory.iterdir() if p.name.endswith(('.tar.gz', '.tar.xz'))}
    if archives != set(UNCHANGED_ARCHIVES) | {'glibc-2.44.3-r1-linux-aarch64.tar.gz'}:
        raise ValueError('source archive set is not the exact nine-archive closure')
    for name, expected in UNCHANGED_ARCHIVES.items():
        file = directory / name
        with file.open('rb') as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        if actual != expected:
            raise ValueError(f'unchanged source archive identity differs: {name}')


def replace_published_glibc(directory, source_run, source_sha):
    # Execute the actual recipe metadata contract, rather than approximating
    # Lua or release URL expansion in a second parser.
    values = subprocess.check_output(['lua5.4', 'tests/lua/glibc_metadata_harness.lua',
        'pkgs/g/glibc.lua', 'aarch64'], text=True).strip().split('\t')
    loader, abi, revision, version, digest, global_url, cn_url, _ = values
    if revision != '3':
        raise ValueError('only the admitted published glibc revision 3 is supported')
    name = f'glibc-2.44.3-r{revision}-linux-aarch64.tar.gz'
    if (loader, abi, revision, version) != ('lib64/ld-linux-aarch64.so.1',
            'linux-aarch64-glibc', revision, '2.44.3'):
        raise ValueError('published glibc replacement requires the exact ARM64 runtime contract')
    tag = f'2.44.3-r{revision}'
    expected_url = f'https://github.com/xlings-res/glibc/releases/download/{tag}/{name}'
    if global_url != expected_url or cn_url != expected_url.replace('github.com', 'gitcode.com'):
        raise ValueError('unexpected published glibc route')
    release = json.loads(subprocess.check_output(['gh', 'api',
        f'repos/xlings-res/glibc/releases/tags/{tag}'], text=True))
    asset = next(a for a in release['assets'] if a['name'] == name)
    if asset.get('digest') != 'sha256:' + digest:
        raise ValueError('published glibc recipe and release digest differ')
    proof_path = '.agents/docs/2026-10-08-glibc-r3-resource-admission.json'
    proof = json.loads(Path(proof_path).read_text())
    ledger = json.loads(Path('.agents/docs/2026-10-08-glibc-r3-source-build.json').read_text())
    if (proof.get('status') != 'native-build-and-mirrors-passed'
            or proof.get('archives', {}).get(name) != digest
            or ledger.get('archives', {}).get(name) != digest
            or (proof.get('source_run_id'), proof.get('source_commit')) != (
                ledger.get('source_run_id'), ledger.get('source_commit'))):
        raise ValueError('published glibc identity differs from the native source ledger')
    origin_id, origin_sha = str(proof['source_run_id']), proof['source_commit']
    if not re.fullmatch('[0-9]+', origin_id) or not re.fullmatch('[0-9a-f]{40}', origin_sha):
        raise ValueError('invalid published glibc source identity')
    origin = json.loads(subprocess.check_output(['gh', 'api',
        f'repos/openxlings/xim-pkgindex/actions/runs/{origin_id}'], text=True))
    if (origin.get('conclusion'), origin.get('status'), origin.get('path'), origin.get('head_sha'),
            origin.get('repository', {}).get('full_name'), origin.get('head_repository', {}).get('full_name')) != (
            'success', 'completed', '.github/workflows/glibc-root-runtime.yml', origin_sha,
            'openxlings/xim-pkgindex', 'openxlings/xim-pkgindex'):
        raise ValueError('published glibc source build evidence differs')
    validate_source_history(origin_sha, 'openxlings/xim-pkgindex')
    subprocess.run(['git', 'diff', '--exit-code', origin_sha, 'HEAD', '--',
                    '.agents/tools/graphics/build-glibc.sh', '.agents/tools/graphics/patches'], check=True)
    checks = []
    for mirror, url in [('GLOBAL', global_url), ('CN', cn_url)]:
        target = directory / (name + '.' + mirror + '.verified')
        subprocess.run(['curl', '-fL', '--retry', '3', '-o', str(target), url], check=True)
        with target.open('rb') as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        if actual != digest or target.stat().st_size != asset['size']:
            raise ValueError(f'published glibc {mirror} bytes differ')
        checks.append({'mirror': mirror, 'url': url, 'sha256': actual, 'size': target.stat().st_size})
    # Preserve original provenance outside the new active nine-archive closure.
    history = directory / 'source-history'
    history.mkdir()
    for file in list(directory.iterdir()):
        if file.name.startswith('glibc-2.44.3-r1-linux-aarch64.tar.gz') or file.name in ('SHA256SUMS', 'BUILD-ADMISSION.json'):
            file.rename(history / file.name)
    (directory / (name + '.GLOBAL.verified')).rename(directory / name)
    (directory / (name + '.CN.verified')).unlink()
    subprocess.run(['python3', '.agents/tools/check-glibc-data-inventory.py', str(directory/name),
                    '--arch', 'aarch64', '--revision', revision], check=True)
    archives = dict(UNCHANGED_ARCHIVES, **{name: digest})
    for archive, checksum in archives.items():
        (directory / (archive + '.sha256')).write_text(f'{checksum}  {archive}\n')
    (directory / 'SHA256SUMS').write_text(''.join(f'{h}  {n}\n' for n,h in sorted(archives.items())))
    (directory / 'PUBLISHED-GLIBC-REUSE.json').write_text(json.dumps({
        'mode': 'published-glibc-only', 'source_run_id': source_run, 'source_commit': source_sha,
        'unchanged_archives': UNCHANGED_ARCHIVES,
        'published_glibc': {'archive': name, 'tag': release['tag_name'], 'release_id': release['id'],
            'source_commit': origin['head_sha'], 'source_run_id': origin['id'], 'mirror_checks': checks},
        'admission': 'fresh native gates required; this provenance is not admission',
    }, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run_id')
    parser.add_argument('directory', type=Path)
    parser.add_argument('--published-glibc-only', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch('[0-9]+', args.run_id):
        raise ValueError('source run id must contain only digits')
    repository = os.environ['GITHUB_REPOSITORY']
    run = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repository}/actions/runs/{args.run_id}'], text=True))
    sha = validate(run, repository)
    validate_source_history(sha, repository)
    builders = UNCHANGED_BUILDERS if args.published_glibc_only else BUILDERS
    subprocess.run(['git', 'diff', '--exit-code', sha, 'HEAD', '--', *builders], check=True)
    print(f'Reusing successful native run {args.run_id}, commit {sha}; mode='
          f'{"published-glibc-only" if args.published_glibc_only else "identical-builders"}.', flush=True)
    args.directory.mkdir(parents=True, exist_ok=True)
    subprocess.run(['gh', 'run', 'download', args.run_id, '--repo', repository,
                    '--name', 'llvm2313-linux-aarch64-assets', '--dir', str(args.directory)], check=True)
    subprocess.run(['sha256sum', '-c', 'SHA256SUMS'], cwd=args.directory, check=True)
    if args.published_glibc_only:
        verify_unchanged_archives(args.directory)
        replace_published_glibc(args.directory, args.run_id, sha)
    with open(os.environ['GITHUB_ENV'], 'a') as env:
        env.write(f'ADMISSION_SOURCE_COMMIT={sha}\nADMISSION_SOURCE_RUN_ID={args.run_id}\n')
    # The current native runner repeats all admission gates, including default
    # G1 data. Source-run hashes/provenance alone never authorize publication.


if __name__ == '__main__':
    main()
