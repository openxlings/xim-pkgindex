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
    parser.add_argument('--max-dispatches', type=int, choices=range(1, 21), default=20, metavar='1..20')
    parser.add_argument('--retry-failed', action='store_true',
                        help='explicitly retry completed unsuccessful runs for an unchanged PR head')
    args = parser.parse_args()
    repo = os.environ['GITHUB_REPOSITORY']
    outcomes = []
    dispatched = 0
    for record in json.loads(Path(args.proposals).read_text())['packages']:
        if record['status'] not in ('created', 'updated', 'pending') or not record.get('url'):
            continue
        number = record['url'].rstrip('/').rsplit('/', 1)[-1]
        if not number.isdigit():
            raise ValueError('unexpected PR URL')
        pr = json.loads(gh('api', f'repos/{repo}/pulls/{number}'))
        expected = 'auto/bump-' + re.sub(r'[^a-zA-Z0-9._-]', '-', record['id'])
        if pr['user']['login'] != 'github-actions[bot]' or not (pr['head']['ref'] == expected or pr['head']['ref'].startswith(expected + '-')):
            outcomes.append({'id': record['id'], 'status': 'manual-pr-pending'})
            continue
        if pr['base']['ref'] != args.base or pr['head']['repo']['full_name'] != repo:
            raise ValueError('bot PR repository/base mismatch')
        branch, sha = pr['head']['ref'], pr['head']['sha']
        workflows = ['ci.yml']
        for workflow in workflows:
            listing = json.loads(gh('api', f'repos/{repo}/actions/workflows/{workflow}/runs?branch={branch}&per_page=100'))
            matching = [run for run in listing['workflow_runs'] if run['head_sha'] == sha]
            latest = max(matching, key=lambda run: run.get('id', 0), default=None)
            protected = any(run.get('status') != 'completed' or run.get('conclusion') == 'success'
                            for run in matching)
            retry = (args.retry_failed and not protected and latest and latest.get('status') == 'completed'
                     and latest.get('conclusion') in ('failure', 'cancelled', 'timed_out', 'startup_failure'))
            if latest and not retry:
                outcomes.append({'id': record['id'], 'workflow': workflow, 'sha': sha, 'status': 'already-dispatched'})
                continue
            if dispatched >= args.max_dispatches:
                outcomes.append({'id': record['id'], 'workflow': workflow, 'sha': sha,
                                 'status': 'dispatch-deferred', 'reason': 'per-run CI dispatch limit reached'})
                continue
            fresh = json.loads(gh('api', f'repos/{repo}/pulls/{number}'))
            if fresh['head']['sha'] != sha:
                outcomes.append({'id': record['id'], 'workflow': workflow, 'sha': sha, 'status': 'head-moved'})
                continue
            for previous in listing['workflow_runs']:
                if (previous['head_sha'] != sha and previous.get('event') in ('pull_request', 'workflow_dispatch')
                        and previous.get('status') in ('queued', 'in_progress', 'pending', 'waiting')):
                    try:
                        gh('api', '--method', 'POST', f"repos/{repo}/actions/runs/{previous['id']}/cancel")
                    except subprocess.CalledProcessError:
                        # The run may have completed between listing and cancellation.
                        current = json.loads(gh('api', f"repos/{repo}/actions/runs/{previous['id']}"))
                        if current['status'] != 'completed':
                            raise
            payload = {'ref': branch}
            payload['inputs'] = {'base_sha': pr['base']['sha'], 'head_sha': sha}
            # Request JSON through stdin; no credential or shell interpolation in payloads.
            subprocess.run(['gh', 'api', '--method', 'POST', f'repos/{repo}/actions/workflows/{workflow}/dispatches',
                            '--input', '-'], input=json.dumps(payload), text=True, check=True)
            dispatched += 1
            outcomes.append({'id': record['id'], 'workflow': workflow, 'sha': sha, 'status': 'dispatched'})
    Path(args.output).write_text(json.dumps({'dispatches': outcomes}, indent=2) + '\n')


if __name__ == '__main__':
    main()
