#!/usr/bin/env python3
"""Reuse a successful same-repository native run with identical source builders."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

BUILDERS = ['.agents/tools/build-linux-aarch64-deps.sh', '.agents/tools/build-llvm-subpkg.sh',
            '.agents/tools/graphics/build-glibc.sh', '.agents/tools/graphics/patches']


def validate(run, repository):
    if run.get('conclusion') != 'success' or run.get('status') != 'completed':
        raise ValueError('source native run has not completed successfully')
    if run.get('repository', {}).get('full_name') != repository or run.get('head_repository', {}).get('full_name') != repository:
        raise ValueError('source native run must belong to the same repository, including its head')
    if run.get('path') != '.github/workflows/llvm-linux-aarch64.yml':
        raise ValueError('source run does not use the native closure workflow')
    sha = run.get('head_sha', '')
    if not re.fullmatch('[0-9a-f]{40}', sha):
        raise ValueError('invalid source commit')
    return sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run_id')
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    if not re.fullmatch('[0-9]+', args.run_id):
        raise ValueError('source run id must contain only digits')
    repository = os.environ['GITHUB_REPOSITORY']
    run = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repository}/actions/runs/{args.run_id}'], text=True))
    sha = validate(run, repository)
    subprocess.run(['git', 'merge-base', '--is-ancestor', sha, 'HEAD'], check=True)
    subprocess.run(['git', 'diff', '--exit-code', sha, 'HEAD', '--', *BUILDERS], check=True)
    print(f'Reusing successful native run {args.run_id}, commit {sha}; builder and isolation-patch content unchanged.', flush=True)
    args.directory.mkdir(parents=True, exist_ok=True)
    subprocess.run(['gh', 'run', 'download', args.run_id, '--repo', repository,
                    '--name', 'llvm2313-linux-aarch64-assets', '--dir', str(args.directory)], check=True)
    subprocess.run(['sha256sum', '-c', 'SHA256SUMS'], cwd=args.directory, check=True)
    with open(os.environ['GITHUB_ENV'], 'a') as env:
        env.write(f'ADMISSION_SOURCE_COMMIT={sha}\nADMISSION_SOURCE_RUN_ID={args.run_id}\n')
    # The current native runner repeats all admission gates, including default
    # G1 data. Source-run hashes/provenance alone never authorize publication.


if __name__ == '__main__':
    main()
