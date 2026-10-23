#!/usr/bin/env python3
"""Scheduled/manual publication must not bypass the same main CI source gate."""
import argparse
import json
import re
import subprocess


def verified(run, repository, sha):
    return (run.get('head_sha') == sha and run.get('head_branch') == 'main'
            and run.get('event') == 'push' and run.get('status') == 'completed'
            and run.get('conclusion') == 'success'
            and run.get('head_repository', {}).get('full_name') == repository)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repository', required=True)
    args = ap.parse_args()
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', args.repository):
        raise ValueError('invalid repository')
    sha = subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip()
    endpoint = f'repos/{args.repository}/actions/workflows/ci.yml/runs?head_sha={sha}&event=push&branch=main&per_page=100'
    runs = json.loads(subprocess.check_output(['gh','api',endpoint], text=True))['workflow_runs']
    if not any(verified(run, args.repository, sha) for run in runs):
        raise SystemExit(f'No successful main CI push run for exact publication source {sha}')
    print('Verified publication source:', sha)
