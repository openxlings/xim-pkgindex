#!/usr/bin/env python3
"""Persist the updater cursor/queue on a dedicated branch with compare-and-swap."""
import argparse
import base64
import json
import os
import re
import subprocess
from pathlib import Path
from urllib.parse import quote

BRANCH = 'auto/update-state'


def api(route, *, method='GET', payload=None, missing=False):
    command = ['gh', 'api', '--method', method, route]
    if payload is not None:
        command += ['--input', '-']
    result = subprocess.run(command, input=json.dumps(payload) if payload is not None else None,
                            text=True, capture_output=True)
    if result.returncode:
        if missing and 'HTTP 404' in result.stderr:
            return None
        raise RuntimeError(f'GitHub state {method} failed: {result.stderr.strip()}')
    return json.loads(result.stdout) if result.stdout.strip() else None


def validate(state):
    if (not isinstance(state, dict) or not isinstance(state.get('cursor', ''), str)
            or not isinstance(state.get('waiting', {}), dict)
            or not isinstance(state.get('queue', []), list)):
        raise ValueError('invalid updater progress/queue; refusing to replace durable state')
    return state


def stored_file(repo, branch):
    stored = api(f'repos/{repo}/contents/state.json?ref={quote(branch, safe="")}', missing=True)
    if stored and stored.get('encoding') == 'none':
        blob = api(f"repos/{repo}/git/blobs/{stored['sha']}")
        stored = {**stored, 'content': blob['content']}
    return stored


def load(repo, path, metadata, branch=BRANCH):
    stored = stored_file(repo, branch)
    if stored:
        state = validate(json.loads(base64.b64decode(stored['content'], validate=False)))
        path.write_text(json.dumps(state), encoding='utf-8')
    elif path.exists():
        validate(json.loads(path.read_text(encoding='utf-8')))  # One-time legacy cache migration.
    else:
        path.write_text(json.dumps({'version': 1, 'queue': []}), encoding='utf-8')
    metadata.write_text(json.dumps({'branch': branch, 'sha': stored['sha'] if stored else None}), encoding='utf-8')
    return {'status': 'loaded' if stored else 'initialized', 'branch': branch}


def save(repo, path, metadata, branch=BRANCH):
    state = validate(json.loads(path.read_text(encoding='utf-8')))
    expected = json.loads(metadata.read_text(encoding='utf-8'))
    if expected.get('branch') != branch:
        raise ValueError('durable state branch mismatch')
    current = stored_file(repo, branch)
    if (current['sha'] if current else None) != expected.get('sha'):
        raise ValueError('durable state changed during this run; refusing to overwrite')
    data = (json.dumps(state, ensure_ascii=False, sort_keys=True) + '\n').encode()
    if current and base64.b64decode(current['content']) == data:
        return {'status': 'unchanged', 'branch': branch}
    if not current and api(f'repos/{repo}/git/ref/heads/{branch}', missing=True) is None:
        sha = os.environ['GITHUB_SHA']
        if not re.fullmatch(r'[0-9a-f]{40}', sha):
            raise ValueError('expected a full source commit for the state branch')
        api(f'repos/{repo}/git/refs', method='POST', payload={'ref': 'refs/heads/' + branch, 'sha': sha})
    payload = {'message': 'chore: persist updater queue and cursor', 'branch': branch,
               'content': base64.b64encode(data).decode()}
    if expected.get('sha'):
        payload['sha'] = expected['sha']
    result = api(f'repos/{repo}/contents/state.json', method='PUT', payload=payload)
    metadata.write_text(json.dumps({'branch': branch, 'sha': result['content']['sha']}), encoding='utf-8')
    return {'status': 'saved', 'branch': branch}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['load', 'save'])
    parser.add_argument('--state', type=Path, default=Path('.update-state.json'))
    parser.add_argument('--metadata', type=Path, default=Path('.update-state-store.json'))
    args = parser.parse_args()
    print(json.dumps(globals()[args.command](os.environ['GITHUB_REPOSITORY'], args.state, args.metadata)))


if __name__ == '__main__':
    main()
