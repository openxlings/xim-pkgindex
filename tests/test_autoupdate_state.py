"""Durable state survives runners and rejects stale writers instead of losing queued work."""
import base64
import copy
import importlib.util
import json
from pathlib import Path

import pytest

pytestmark = pytest.mark.static
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('autoupdate_state', ROOT / '.github/scripts/autoupdate-state.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


@pytest.fixture
def store(tmp_path, monkeypatch):
    remote = {'branch': False, 'file': None, 'writes': 0, 'calls': []}
    monkeypatch.setenv('GITHUB_SHA', 'a' * 40)
    def api(route, *, method='GET', payload=None, missing=False):
        remote['calls'].append((method, route, payload))
        if method == 'GET' and '/contents/' in route:
            return copy.deepcopy(remote['file'])
        if method == 'GET':
            return {'ref': 'state'} if remote['branch'] else None
        if method == 'POST':
            assert payload == {'ref': 'refs/heads/auto/update-state', 'sha': 'a' * 40}
            remote['branch'] = True
            return {'ref': 'state'}
        assert method == 'PUT'
        if remote['file']:
            assert payload['sha'] == remote['file']['sha']
        remote['writes'] += 1
        remote['file'] = {'sha': f"revision-{remote['writes']}", 'content': payload['content']}
        return {'content': {'sha': remote['file']['sha']}}
    monkeypatch.setattr(mod, 'api', api)
    return remote, tmp_path / 'state.json', tmp_path / 'metadata.json'


def test_cursor_and_queue_survive_a_fresh_runner(store, tmp_path):
    remote, path, metadata = store
    mod.load('acme/index', path, metadata)
    progress = {'cursor': 'xim:pnpm', 'queue': [{'record': {'id': 'xim:foo', 'candidate': '2.0'}}]}
    path.write_text(json.dumps(progress))
    assert mod.save('acme/index', path, metadata)['status'] == 'saved'
    next_path, next_meta = tmp_path / 'next.json', tmp_path / 'next-meta.json'
    mod.load('acme/index', next_path, next_meta)
    assert json.loads(next_path.read_text()) == progress
    assert remote['writes'] == 1
    assert mod.save('acme/index', next_path, next_meta)['status'] == 'unchanged'
    assert remote['writes'] == 1


def test_stale_writer_cannot_replace_a_newer_queue(store, tmp_path):
    remote, path, metadata = store
    mod.load('acme/index', path, metadata)
    stale_path, stale_meta = tmp_path / 'stale.json', tmp_path / 'stale-meta.json'
    mod.load('acme/index', stale_path, stale_meta)
    path.write_text(json.dumps({'cursor': 'xim:z', 'queue': []}))
    mod.save('acme/index', path, metadata)
    with pytest.raises(ValueError, match='changed during this run'):
        mod.save('acme/index', stale_path, stale_meta)
    assert remote['writes'] == 1
    assert json.loads(base64.b64decode(remote['file']['content']))['cursor'] == 'xim:z'


def test_legacy_cache_is_migrated_only_when_durable_state_is_absent(store):
    remote, path, metadata = store
    path.write_text(json.dumps({'cursor': 'xim:libxcb', 'waiting': {}}))
    mod.load('acme/index', path, metadata)
    assert json.loads(path.read_text())['cursor'] == 'xim:libxcb'
    mod.save('acme/index', path, metadata)
    path.write_text(json.dumps({'cursor': 'old-cache'}))
    mod.load('acme/index', path, metadata)
    assert json.loads(path.read_text())['cursor'] == 'xim:libxcb'
    assert remote['writes'] == 1


def test_malformed_or_wrong_branch_state_never_writes(store):
    remote, path, metadata = store
    mod.load('acme/index', path, metadata)
    path.write_text('[]')
    with pytest.raises(ValueError, match='invalid updater'):
        mod.save('acme/index', path, metadata)
    path.write_text('{}')
    metadata.write_text(json.dumps({'branch': 'main', 'sha': None}))
    with pytest.raises(ValueError, match='branch mismatch'):
        mod.save('acme/index', path, metadata)
    assert remote['writes'] == 0
