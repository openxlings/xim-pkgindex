"""Source admission retains actual Git ancestry or authentic equal-tree squash history."""
import importlib.util
import json
from pathlib import Path
import subprocess
import pytest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('native_reuse_history', ROOT/'.agents/tools/reuse-linux-aarch64-assets.py')
reuse = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reuse)
pytestmark = pytest.mark.static
REPOSITORY = 'openxlings/xim-pkgindex'


@pytest.fixture
def history(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    def git(*args, input=None):
        return subprocess.check_output(['git', *args], input=input, text=True).strip()
    git('init', '-q')
    git('config', 'user.name', 'Owned fixture')
    git('config', 'user.email', 'fixture@example.invalid')
    (tmp_path/'payload').write_text('base\n'); git('add', 'payload'); git('commit', '-qm', 'base')
    base = git('rev-parse', 'HEAD')
    (tmp_path/'payload').write_text('source-built payload\n'); git('commit', '-qam', 'source')
    source = git('rev-parse', 'HEAD')
    (tmp_path/'metadata').write_text('reviewed metadata\n'); git('add', 'metadata'); git('commit', '-qm', 'reviewed head')
    head = git('rev-parse', 'HEAD'); tree = git('rev-parse', 'HEAD^{tree}')
    squash = git('commit-tree', tree, '-p', base, input='authorized squash\n')
    git('checkout', '-q', '--detach', squash)
    assert not reuse.ancestor(source, 'HEAD')
    assert reuse.ancestor(source, head)
    assert git('rev-parse', head+'^{tree}') == git('rev-parse', squash+'^{tree}')
    pr = {'number': 938, 'merged': True, 'merge_commit_sha': squash,
          'head': {'sha': head, 'repo': {'full_name': REPOSITORY}},
          'base': {'repo': {'full_name': REPOSITORY}}}
    return git, source, head, base, squash, tree, pr


def mock_api(monkeypatch, pr):
    original = subprocess.check_output
    def command(args, **kwargs):
        if args[0] != 'gh': return original(args, **kwargs)
        if '/commits/' in args[-1]: return json.dumps([{'number':938}])
        assert args[-1] == f'repos/{REPOSITORY}/pulls/938'
        return json.dumps(pr)
    monkeypatch.setattr(reuse.subprocess, 'check_output', command)


def test_real_equal_tree_squash_is_admitted(history, monkeypatch):
    git, source, head, base, squash, tree, pr = history
    mock_api(monkeypatch, pr)
    reuse.validate_source_history(source, REPOSITORY)


def test_real_normal_ancestry_needs_no_pr_mapping(history, monkeypatch):
    git, source, head, base, squash, tree, pr = history
    git('checkout', '-q', '--detach', head)
    original = subprocess.check_output
    def command(args, **kwargs):
        assert args[0] != 'gh', 'ordinary ancestry must not depend on API availability'
        return original(args, **kwargs)
    monkeypatch.setattr(reuse.subprocess, 'check_output', command)
    reuse.validate_source_history(source, REPOSITORY)


@pytest.mark.parametrize('change', ['open', 'foreign_head', 'foreign_base', 'unrelated_head',
                                    'unrelated_merge', 'tampered_tree'])
def test_real_git_rejects_unauthenticated_or_non_equivalent_mapping(history, monkeypatch, tmp_path, change):
    git, source, head, base, squash, tree, pr = history
    if change == 'open': pr['merged'] = False
    elif change == 'foreign_head': pr['head']['repo']['full_name'] = 'foreign/index'
    elif change == 'foreign_base': pr['base']['repo']['full_name'] = 'foreign/index'
    elif change == 'unrelated_head': pr['head']['sha'] = git('commit-tree', tree, input='unrelated head\n')
    elif change == 'unrelated_merge': pr['merge_commit_sha'] = git('commit-tree', tree, '-p', base, input='not in HEAD history\n')
    elif change == 'tampered_tree':
        (tmp_path/'metadata').write_text('different merged content\n'); git('commit', '-qam', 'different tree')
        pr['merge_commit_sha'] = git('rev-parse', 'HEAD')
    mock_api(monkeypatch, pr)
    with pytest.raises(ValueError, match='tree-equivalent authenticated merged PR'):
        reuse.validate_source_history(source, REPOSITORY)
