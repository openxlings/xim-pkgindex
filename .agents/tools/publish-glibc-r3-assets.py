#!/usr/bin/env python3
"""Publish only the reviewed, natively admitted revision 3 glibc archives."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


reuse = load('native_reuse', ROOT/'.agents/tools/reuse-linux-aarch64-assets.py')
upload = load('native_upload', ROOT/'.agents/tools/upload-linux-aarch64-assets.py')
inventory = load('glibc_inventory', ROOT/'.agents/tools/check-glibc-data-inventory.py')


def source(run_id):
    ledger = json.loads((ROOT/'.agents/docs/2026-10-08-glibc-r3-source-build.json').read_text())
    if run_id != ledger['source_run_id']:
        raise ValueError('only the reviewed successful revision 3 source run may be published')
    repository = os.environ['GITHUB_REPOSITORY']
    run = json.loads(upload.gh('api', f'repos/{repository}/actions/runs/{run_id}'))
    sha = reuse.validate(run, repository, '.github/workflows/glibc-root-runtime.yml')
    if sha != ledger['source_commit']:
        raise ValueError('source commit differs from the reviewed ledger')
    subprocess.run(['git', 'merge-base', '--is-ancestor', sha, 'HEAD'], check=True)
    subprocess.run(['git', 'diff', '--exit-code', sha, 'HEAD', '--',
                    '.agents/tools/graphics/build-glibc.sh', '.agents/tools/graphics/patches'], check=True)
    jobs = json.loads(upload.gh('api', f'repos/{repository}/actions/runs/{run_id}/jobs'))['jobs']
    for name, job_id in ledger['native_jobs'].items():
        job = next(j for j in jobs if j['name'] == name)
        if (job['id'], job['status'], job['conclusion']) != (job_id, 'completed', 'success'):
            raise ValueError(f'original native architecture gate has not passed: {name}')
    return ledger


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_run_id')
    parser.add_argument('directory', type=Path)
    parser.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    ledger = source(args.source_run_id)
    if not args.publish:
        print(json.dumps(ledger, indent=2))
        return
    files = []
    for name, digest in ledger['archives'].items():
        matches = list(args.directory.rglob(name))
        if len(matches) != 1:
            raise ValueError(f'exactly one source archive required: {name}')
        archive = matches[0]
        with archive.open('rb') as stream:
            if hashlib.file_digest(stream, 'sha256').hexdigest() != digest:
                raise ValueError(f'archive differs from original native build: {name}')
        sidecar = archive.parent/(name+'.sha256')
        if sidecar.read_text().split() != [digest, name]:
            raise ValueError(f'source sidecar differs: {name}')
        if (archive.parent/'SHA256SUMS').read_text().split() != [digest, name]:
            raise ValueError(f'source SHA256SUMS differs: {name}')
        architecture = 'aarch64' if '-aarch64.' in name else 'x86_64'
        if inventory.inspect(archive, architecture, 3)['status'] != 'passed':
            raise ValueError(f'required runtime data inventory missing: {name}')
        files.extend((archive, sidecar))
    tag = '2.44.3-r3'
    endpoint = f'repos/xlings-res/glibc/releases/tags/{tag}'
    result = subprocess.run(['gh', 'api', endpoint], capture_output=True, text=True)
    if result.returncode:
        if json.loads(result.stdout).get('status') != '404':
            raise RuntimeError(result.stderr)
        body = args.directory/'release-notes.md'
        body.write_text('GNU libc 2.44, package 2.44.3 revision 3.\n\n'
            'Preserves revision 2 logical-root cache/preload isolation and adds pinned IANA 2026e, '
            'compiled C.utf8, managed conversion data, licenses and payload provenance.\n\n'
            f'Both native architectures passed runtime data, NSS policy, logical-root cache/preload '
            f'and archive inventory in source run {ledger["source_run_id"]}, '
            f'commit {ledger["source_commit"]}.\n\n'
            'Publication does not activate any package index default.\n')
        subprocess.run(['gh', 'release', 'create', tag, '--repo', 'xlings-res/glibc',
                        '--title', tag, '--notes-file', str(body)], check=True)
    release = json.loads(upload.gh('api', endpoint))
    for file in files:
        if not upload.ensure_immutable(file, 'xlings-res/glibc', release):
            subprocess.run(['gh', 'release', 'upload', tag, str(file), '--repo', 'xlings-res/glibc'], check=True)
        release = json.loads(upload.gh('api', endpoint))
        if not upload.ensure_immutable(file, 'xlings-res/glibc', release):
            raise ValueError(f'published asset missing: {file.name}')
    print(json.dumps({'scope':'GLOBAL glibc r3 only; package index inactive',
                      'source': ledger, 'assets': release['assets']}, indent=2))


if __name__ == '__main__':
    main()
