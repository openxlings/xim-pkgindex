#!/usr/bin/env python3
"""Upload build-admitted immutable archives to GLOBAL, without activating index."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROUTES = {
    'llvm-23.1.3': ('llvm', '23.1.3'),
    'llvm-tools-23.1.3': ('llvm', '23.1.3'),
    'glibc-2.44.3-r2': ('glibc', '2.44.3-r2'),
    'gcc-runtime-15.1.0': ('gcc-runtime', '15.1.0'),
    'linux-headers-5.11.1': ('linux-headers', '5.11.1'),
    'zlib-1.3.1': ('zlib', '1.3.1'),
    'libxml2-2.13.5': ('libxml2', '2.13.5'),
}


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True)


def validate(directory, expected_commit):
    report = json.loads((directory / 'BUILD-ADMISSION.json').read_text())
    if report.get('status') != 'passed' or report.get('architecture') != 'aarch64':
        raise ValueError('native build admission has not passed')
    if report.get('commit') != expected_commit or not expected_commit:
        raise ValueError('build admission does not match the dispatched commit')
    required_gates = {'managed-process-libraries', 'default-timezone-locale-gconv-host-nss-policy',
                      'managed-uapi-crt', 'host-header-negative', 'std-and-std.compat', 'cxx-compile-link-run'}
    if not required_gates.issubset(set(report.get('gates', []))):
        raise ValueError('native build admission is missing required gates')
    records = []
    for stem, (repo, tag) in ROUTES.items():
        name = f'{stem}-linux-aarch64.tar.gz'
        file = directory / name
        digest = hashlib.file_digest(file.open('rb'), 'sha256').hexdigest()
        if report.get('archives', {}).get(name) != digest:
            raise ValueError(f'archive changed after admission: {name}')
        sidecar = directory / f'{name}.sha256'
        if sidecar.read_text().split() != [digest, name]:
            raise ValueError(f'invalid archive sidecar: {name}')
        records.append((file, sidecar, repo, tag, digest))
    # Preserve both compression formats of LLVM, with independent real hashes.
    for stem in ('llvm-23.1.3', 'llvm-tools-23.1.3'):
        name = f'{stem}-linux-aarch64.tar.xz'
        file = directory / name
        digest = hashlib.file_digest(file.open('rb'), 'sha256').hexdigest()
        if report.get('archives', {}).get(name) != digest:
            raise ValueError(f'archive changed after admission: {name}')
        sidecar = directory / f'{name}.sha256'
        if sidecar.read_text().split() != [digest, name]:
            raise ValueError(f'invalid archive sidecar: {name}')
        records.append((file, sidecar, 'llvm', '23.1.3', digest))
    return records


def ensure_immutable(file, repo, release):
    existing = next((a for a in release['assets'] if a['name'] == file.name), None)
    if existing is None:
        return False
    digest = hashlib.file_digest(file.open('rb'), 'sha256').hexdigest()
    # Query API asset bytes if the server omits its digest, including sidecars.
    remote_digest = existing.get('digest')
    if remote_digest != f'sha256:{digest}':
        content = subprocess.check_output([
            'gh', 'api', '-H', 'Accept: application/octet-stream',
            f'repos/{repo}/releases/assets/{existing["id"]}',
        ])
        if hashlib.sha256(content).hexdigest() != digest:
            raise ValueError(f'immutable remote asset differs: {repo}/{file.name}')
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--commit', default=os.environ.get('GITHUB_SHA', ''))
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    records = validate(args.directory, args.commit)
    for file, sidecar, package, tag, digest in records:
        repo = f'xlings-res/{package}'
        print(f'{repo}@{tag} {file.name} sha256:{digest}', flush=True)
        if not args.execute:
            continue
        # Repositories must be prepared deliberately; do not auto-create them.
        gh('api', f'repos/{repo}')
        result = subprocess.run(['gh', 'api', f'repos/{repo}/releases/tags/{tag}'],
                                text=True, capture_output=True)
        if result.returncode:
            if 'HTTP 404' not in result.stderr:
                raise RuntimeError(result.stderr)
            gh('release', 'create', tag, '--repo', repo, '--title', tag,
               '--notes', 'Immutable native Linux aarch64 build-admitted resources. Index activation requires separate consumer acceptance.',
               '--latest=false')
        release = json.loads(gh('api', f'repos/{repo}/releases/tags/{tag}'))
        for asset in (file, sidecar):
            if not ensure_immutable(asset, repo, release):
                gh('release', 'upload', tag, str(asset), '--repo', repo)
        # Re-read server state and bytes/digests after upload.
        release = json.loads(gh('api', f'repos/{repo}/releases/tags/{tag}'))
        assert ensure_immutable(file, repo, release)
        assert ensure_immutable(sidecar, repo, release)
    print('GLOBAL resources verified; CN identity and installed consumers remain required before index activation.')


if __name__ == '__main__':
    main()
