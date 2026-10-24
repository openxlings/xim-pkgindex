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
    assert len(posts) == 1
    assert all(p['ref'] == 'auto/bump-xim-foo-1.2.3' for p in posts)
    assert posts[-1]['inputs'] == {'base_sha': 'b' * 40, 'head_sha': 'a' * 40}


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


@pytest.mark.parametrize('status,conclusion,expected', [
    ('completed', 'failure', 1), ('completed', 'timed_out', 1),
    ('completed', 'success', 0), ('in_progress', None, 0), ('queued', None, 0),
])
def test_explicit_retry_keeps_successful_and_active_heads(context, monkeypatch, status, conclusion, expected):
    pr, posts = context
    monkeypatch.setattr('sys.argv', ['dispatch', '--proposals', 'proposals.json', '--base', 'validation', '--retry-failed'])
    def gh(*args):
        if args[-1] == 'repos/acme/index/pulls/12':
            return json.dumps(pr)
        return json.dumps({'workflow_runs': [{'head_sha': pr['head']['sha'], 'id': 10,
                                             'status': status, 'conclusion': conclusion}]})
    monkeypatch.setattr(mod, 'gh', gh)
    mod.main()
    assert len(posts) == expected


def test_dispatch_budget_is_shared_by_all_proposals(context, monkeypatch):
    pr, posts = context
    Path('proposals.json').write_text(json.dumps({'packages': [
        {'id': 'xim:foo', 'status': 'pending', 'url': f'https://github.com/acme/index/pull/{n}'}
        for n in range(12, 37)]}))
    monkeypatch.setattr(mod, 'gh', lambda *args: json.dumps(pr if '/pulls/' in args[-1] else {'workflow_runs': []}))
    mod.main()
    assert len(posts) == 20
    records = json.loads(Path('dispatches.json').read_text())['dispatches']
    assert sum(r['status'] == 'dispatch-deferred' for r in records) == 5


def test_retry_does_not_duplicate_an_existing_success_or_active_run(context, monkeypatch):
    pr, posts = context
    monkeypatch.setattr('sys.argv', ['dispatch', '--proposals', 'proposals.json', '--base', 'validation', '--retry-failed'])
    def gh(*args):
        if args[-1] == 'repos/acme/index/pulls/12':
            return json.dumps(pr)
        return json.dumps({'workflow_runs': [
            {'head_sha': pr['head']['sha'], 'id': 11, 'status': 'completed', 'conclusion': 'failure'},
            {'head_sha': pr['head']['sha'], 'id': 10, 'status': 'completed', 'conclusion': 'success'}]})
    monkeypatch.setattr(mod, 'gh', gh)
    mod.main()
    assert posts == []


@pytest.mark.parametrize('status', ['created', 'updated', 'pending'])
def test_fixed_package_branch_dispatches_its_current_head(context, status):
    pr, posts = context
    pr['head']['ref'] = 'auto/bump-xim-foo'
    Path('proposals.json').write_text(json.dumps({'packages': [
        {'id': 'xim:foo', 'status': status, 'url': 'https://github.com/acme/index/pull/12'}]}))
    mod.main()
    assert len(posts) == 1
    assert posts[0]['ref'] == 'auto/bump-xim-foo'
    assert posts[0]['inputs']['head_sha'] == pr['head']['sha']


def test_refresh_cancels_obsolete_ci_and_dispatches_only_the_new_head(context, monkeypatch):
    pr, posts = context
    pr['head']['ref'] = 'auto/bump-xim-foo'
    cancelled = []
    def gh(*args):
        if '/pulls/' in args[-1]:
            return json.dumps(pr)
        if args[-1].endswith('/cancel'):
            cancelled.append(args[-1])
            return ''
        assert '&event=' not in args[-1]  # PR-triggered CI counts for idempotency too.
        return json.dumps({'workflow_runs': [{'id': 99, 'head_sha': 'old', 'status': 'in_progress',
                                             'event': 'workflow_dispatch'}]})
    monkeypatch.setattr(mod, 'gh', gh)
    mod.main()
    assert cancelled == ['repos/acme/index/actions/runs/99/cancel']
    assert len(posts) == 1 and posts[0]['inputs']['head_sha'] == 'a' * 40


def test_head_race_never_cancels_newer_ci_or_dispatches_a_stale_head(context, monkeypatch):
    pr, posts = context
    pr['head']['ref'] = 'auto/bump-xim-foo'
    reads = []
    def gh(*args):
        if '/pulls/' in args[-1]:
            reads.append(True)
            value = json.loads(json.dumps(pr))
            if len(reads) > 1:
                value['head']['sha'] = 'newer'
            return json.dumps(value)
        assert not args[-1].endswith('/cancel')
        return json.dumps({'workflow_runs': []})
    monkeypatch.setattr(mod, 'gh', gh)
    mod.main()
    assert posts == []
    assert json.loads(Path('dispatches.json').read_text())['dispatches'][0]['status'] == 'head-moved'
