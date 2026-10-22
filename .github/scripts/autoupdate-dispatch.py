#!/usr/bin/env python3
"""Dispatch read-only CI for verified bot PR heads when using GITHUB_TOKEN."""
import argparse
import json
import os
import re
import subprocess
from pathlib import Path


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--proposals', required=True)
    parser.add_argument('--base', required=True)
    parser.add_argument('--output', default='dispatches.json')
    args = parser.parse_args()
    repo = os.environ['GITHUB_REPOSITORY']
    outcomes = []
    for record in json.loads(Path(args.proposals).read_text())['packages']:
        if record['status'] not in ('created', 'pending') or not record.get('url'):
            continue
        number = record['url'].rstrip('/').rsplit('/', 1)[-1]
        if not number.isdigit():
            raise ValueError('unexpected PR URL')
        pr = json.loads(gh('api', f'repos/{repo}/pulls/{number}'))
        expected = 'auto/bump-' + re.sub(r'[^a-zA-Z0-9._-]', '-', record['id']) + '-'
        if pr['user']['login'] != 'github-actions[bot]' or not pr['head']['ref'].startswith(expected):
            outcomes.append({'id': record['id'], 'status': 'manual-pr-pending'})
            continue
        if pr['base']['ref'] != args.base or pr['head']['repo']['full_name'] != repo:
            raise ValueError('bot PR repository/base mismatch')
        branch, sha = pr['head']['ref'], pr['head']['sha']
        workflows = ['ci-test.yml', 'ci-xpkg-test.yml', 'site-check.yml',
                     'runtime-revision-gate.yml', 'xpkgindex-update.yml']
        for workflow in workflows:
            listing = json.loads(gh('api', f'repos/{repo}/actions/workflows/{workflow}/runs?branch={branch}&event=workflow_dispatch&per_page=100'))
            if any(run['head_sha'] == sha for run in listing['workflow_runs']):
                outcomes.append({'id': record['id'], 'workflow': workflow, 'sha': sha, 'status': 'already-dispatched'})
                continue
            payload = {'ref': branch}
            if workflow == 'xpkgindex-update.yml':
                payload['inputs'] = {'validation_base': pr['base']['sha'], 'package': record['id']}
            # Request JSON through stdin; no credential or shell interpolation in payloads.
            subprocess.run(['gh', 'api', '--method', 'POST', f'repos/{repo}/actions/workflows/{workflow}/dispatches',
                            '--input', '-'], input=json.dumps(payload), text=True, check=True)
            outcomes.append({'id': record['id'], 'workflow': workflow, 'sha': sha, 'status': 'dispatched'})
    Path(args.output).write_text(json.dumps({'dispatches': outcomes}, indent=2) + '\n')


if __name__ == '__main__':
    main()
