"""Only verified bot PR heads may request explicit CI dispatch; retries are idempotent."""
import importlib.util
import json
from pathlib import Path

import pytest

pytestmark = pytest.mark.static
PATH = Path(__file__).resolve().parents[1] / '.github/scripts/autoupdate-dispatch.py'
spec = importlib.util.spec_from_file_location('autoupdate_dispatch', PATH)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


@pytest.fixture
def context(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv('GITHUB_REPOSITORY', 'acme/index')
    Path('proposals.json').write_text(json.dumps({'packages': [
        {'id': 'xim:foo', 'status': 'created', 'url': 'https://github.com/acme/index/pull/12'}]}))
    monkeypatch.setattr('sys.argv', ['dispatch', '--proposals', 'proposals.json', '--base', 'validation'])
    pr = {'user': {'login': 'github-actions[bot]'}, 'base': {'ref': 'validation', 'sha': 'b' * 40},
          'head': {'ref': 'auto/bump-xim-foo-1.2.3', 'sha': 'a' * 40,
                   'repo': {'full_name': 'acme/index'}}}
    posts = []
    def gh(*args):
        if args[-1] == 'repos/acme/index/pulls/12':
            return json.dumps(pr)
        return json.dumps({'workflow_runs': []})
    monkeypatch.setattr(mod, 'gh', gh)
    monkeypatch.setattr(mod.subprocess, 'run', lambda command, **kwargs: posts.append(json.loads(kwargs['input'])))
    return pr, posts


def test_dispatches_only_the_verified_branch_and_candidate_base(context):
    _, posts = context
    mod.main()
    assert len(posts) == 5
    assert all(p['ref'] == 'auto/bump-xim-foo-1.2.3' for p in posts)
    assert posts[-1]['inputs'] == {'validation_base': 'b' * 40, 'package': 'xim:foo'}


def test_rejects_cross_repository_or_wrong_base(context):
    pr, posts = context
    pr['head']['repo']['full_name'] = 'other/index'
    with pytest.raises(ValueError, match='repository/base'):
        mod.main()
    assert posts == []


def test_never_dispatches_a_manual_package_pr(context):
    pr, posts = context
    pr['user']['login'] = 'maintainer'
    mod.main()
    assert posts == []
    assert json.loads(Path('dispatches.json').read_text())['dispatches'][0]['status'] == 'manual-pr-pending'


def test_resumes_only_missing_dispatches(context, monkeypatch):
    pr, posts = context
    def gh(*args):
        if args[-1] == 'repos/acme/index/pulls/12':
            return json.dumps(pr)
        return json.dumps({'workflow_runs': [{'head_sha': 'a' * 40}]})
    monkeypatch.setattr(mod, 'gh', gh)
    mod.main()
    assert posts == []
    assert all(r['status'] == 'already-dispatched' for r in json.loads(Path('dispatches.json').read_text())['dispatches'])
