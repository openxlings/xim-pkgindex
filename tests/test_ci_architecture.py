"""Scheduling is a safety boundary: prove coverage and reject false green gates."""
import importlib.util
import json
from pathlib import Path
import subprocess

import pytest
import yaml

pytestmark = pytest.mark.static
ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / '.github/scripts' / (name + '.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


planner = module('ci-plan')
gate = module('ci-required')
PROFILES = json.loads((ROOT / '.github/ci-profiles.json').read_text())


def pkg(deps='', imports=''):
    return 'package = {name="test", xpm = {linux = {["1"] = {}}}, deps = {' + deps + '}}\n' + imports


def test_docs_do_not_allocate_package_runners():
    p = planner.plan(['docs/guide.md'], {}, {}, PROFILES)
    assert p['install_matrix'] == {'include': []}
    assert p['flags']['site_check']
    assert not p['flags']['eden_smoke']


def test_shared_module_change_reaches_importers_and_consumers():
    files = {'libs/shell.lua': 'return {}',
             'libs/sysroot.lua': 'import("xim.pkgindex.shell")',
             'pkgs/a/a.lua': pkg(imports='import("xim.pkgindex.sysroot")'),
             'pkgs/b/b.lua': pkg('"xim:a@1"'),
             'pkgs/c/c.lua': pkg()}
    assert planner.affected(['libs/shell.lua'], files, files) == ['pkgs/a/a.lua', 'pkgs/b/b.lua']


def test_deleted_provider_keeps_its_consumers():
    before = {'pkgs/a/a.lua': pkg(), 'pkgs/b/b.lua': pkg('"xim:a"')}
    after = {'pkgs/b/b.lua': before['pkgs/b/b.lua']}
    assert planner.affected(['pkgs/a/a.lua'], before, after) == ['pkgs/b/b.lua']


def test_removed_import_does_not_hide_affected_package():
    before = {'libs/x.lua': '', 'pkgs/a/a.lua': pkg(imports='import("xim.pkgindex.x")')}
    after = {'pkgs/a/a.lua': pkg()}
    assert planner.affected(['libs/x.lua'], before, after) == ['pkgs/a/a.lua']


def test_metadata_only_still_checks_site_and_index(monkeypatch):
    monkeypatch.setattr(planner, 'runtime_changed', lambda before, after: False)
    p = planner.plan(['pkgs/a/a.lua'], {'pkgs/a/a.lua': 'before'}, {'pkgs/a/a.lua': 'after'}, PROFILES)
    assert p['packages'] == []
    assert p['flags']['site_check'] and p['flags']['ci_xpkg_test']


def test_only_supported_platform_allocated(monkeypatch):
    monkeypatch.setattr(planner, 'supported_platforms', lambda src: {'linux'})
    p = planner.plan(['pkgs/a/a.lua'], {}, {'pkgs/a/a.lua': pkg()}, PROFILES)
    assert [t['platform'] for t in p['install_matrix']['include']] == ['linux']


def test_framework_uses_real_cross_platform_canaries():
    files = {p: pkg() for p in ('pkgs/e/eden.lua', 'pkgs/e/eden-android.lua')}
    p = planner.plan(['.github/scripts/ci-plan.py'], files, files, PROFILES)
    assert p['packages'] == sorted(files)
    assert p['flags']['eden_smoke'] and p['closure']


def test_dependency_cycles_terminate():
    files = {'pkgs/a/a.lua': pkg('"xim:b"'), 'pkgs/b/b.lua': pkg('"xim:a"')}
    assert planner.affected(['pkgs/a/a.lua'], files, files) == sorted(files)


@pytest.mark.parametrize('state', ['failure', 'cancelled', 'skipped'])
def test_planned_job_must_succeed(state):
    assert gate.failures({'plan': {'result': 'success', 'outputs': {'install': 'true'}},
                          'install': {'result': state}})


def test_missing_planned_job_is_not_green():
    assert gate.failures({'plan': {'result': 'success', 'outputs': {'install': 'true'}}})


def test_planning_failure_is_not_green():
    assert gate.failures({'plan': {'result': 'failure'}})


def test_intentionally_unneeded_job_can_skip():
    assert gate.failures({'plan': {'result': 'success', 'outputs': {'install': 'false'}},
                          'install': {'result': 'skipped'}}) == []


def workflow(name):
    d = yaml.safe_load((ROOT / '.github/workflows' / name).read_text())
    return d, d.get('on', d.get(True, {}))


def test_one_pr_entry_and_no_feature_push_duplication():
    for profile in PROFILES.values():
        d, on = workflow(profile['workflow'])
        assert 'workflow_call' in on
        assert 'pull_request' not in on and 'push' not in on
    d, on = workflow('ci.yml')
    assert 'pull_request' in on and on['pull_request'] is None
    assert on['push']['branches'] == ['main']
    assert d['jobs']['required']['if'] == 'always()'
    expected = set(PROFILES) | {'ci_candidates', 'install', 'plan'}
    assert set(d['jobs']['required']['needs']) == expected
    assert expected <= set(d['jobs'])


def test_profile_routes_watch_their_own_executors():
    for profile in PROFILES.values():
        assert '.github/workflows/' + profile['workflow'] in profile['paths']
    assert '.github/scripts/check-payload-hard-links.py' in PROFILES['payload_hard_links']['paths']


def test_bot_dispatch_compares_complete_pr_not_last_commit():
    src = (ROOT / '.github/scripts/autoupdate-dispatch.py').read_text()
    assert "workflows = ['ci.yml']" in src
    assert "'base_sha': pr['base']['sha'], 'head_sha': sha" in src


def test_snapshot_detects_rename_as_delete_and_add(tmp_path):
    subprocess.run(['git', 'init', '-q', str(tmp_path)], check=True)
    def commit(message):
        subprocess.run(['git', '-C', str(tmp_path), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(tmp_path), '-c', 'user.name=CI', '-c', 'user.email=ci@example.invalid',
                        'commit', '-qm', message], check=True)
        return planner.git(tmp_path, 'rev-parse', 'HEAD')
    f = tmp_path / 'pkgs/a/a.lua'
    f.parent.mkdir(parents=True)
    f.write_text(pkg())
    base = commit('base')
    f.rename(f.with_name('renamed.lua'))
    head = commit('rename')
    changes = planner.git(tmp_path, 'diff', '--name-only', '--no-renames', base, head).splitlines()
    assert changes == ['pkgs/a/a.lua', 'pkgs/a/renamed.lua']


def test_resource_only_does_not_expand_unrelated_runners():
    res = module('ci-res-plan')
    entries = json.loads((ROOT / '.github/res-build-matrix.json').read_text())
    result = res.select(entries, 'sample-music')
    assert len(result['include']) == 1
    assert all(e['what'] == 'sample-music' for e in result['include'])
    with pytest.raises(ValueError, match='Unknown'):
        res.select(entries, 'typo')


def test_linux_toolchain_change_does_not_start_macos_baseline():
    mod = module('ci-toolchain-plan')
    rows = mod.select(['pkgs/g/gcc.lua', 'pkgs/m/musl-gcc.lua'])['include']
    assert {r['tool'] for r in rows} == {'gcc', 'musl-gcc'}
    assert {r['platform'] for r in rows} == {'linux'}
    assert len(mod.select([])['include']) == 2


def test_publication_follows_build_inputs_too():
    mod = module('ci-publication-scope')
    assert mod.selected(['tools/build_xim_index_artifact.sh'], 'index')
    assert mod.selected(['libs/sysroot.lua'], 'index')
    assert not mod.selected(['docs/guide.md'], 'index')
    assert mod.selected(['docs/guide.md'], 'site')
    for filename in ['publish-artifact.yml', 'pkgindex-deloy.yml', 'xpkg-mirror.yml']:
        d, on = workflow(filename)
        assert on['workflow_run']['workflows'] == ['CI']
        assert on['workflow_run']['branches'] == ['main']
        assert 'pull_request' not in on
        assert any('${{ github.event.workflow_run.head_sha || github.sha }}' == step.get('with', {}).get('ref')
                   for job in d['jobs'].values() for step in job.get('steps', []))


def test_multicommit_pr_keeps_earlier_package_change(tmp_path):
    import sys
    subprocess.run(['git', 'init', '-q', str(tmp_path)], check=True)
    (tmp_path / '.github').mkdir()
    (tmp_path / '.github/ci-profiles.json').write_text(json.dumps(PROFILES))
    def commit(message):
        subprocess.run(['git', '-C', str(tmp_path), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(tmp_path), '-c', 'user.name=CI', '-c', 'user.email=ci@example.invalid',
                        'commit', '-qm', message], check=True)
        return planner.git(tmp_path, 'rev-parse', 'HEAD')
    base = commit('base')
    f = tmp_path / 'pkgs/a/a.lua'
    f.parent.mkdir(parents=True)
    f.write_text(pkg())
    commit('package')
    (tmp_path / 'README.md').write_text('second commit changes documentation only')
    head = commit('docs')
    subprocess.run([sys.executable, str(ROOT / '.github/scripts/ci-plan.py'), '--base', base, '--head', head],
                   cwd=tmp_path, check=True, capture_output=True)
    result = json.loads((tmp_path / 'ci-plan.json').read_text())
    assert result['packages'] == ['pkgs/a/a.lua']
    assert result['base_sha'] == base and result['head_sha'] == head


def test_display_metadata_is_excluded_but_hooks_and_coordinates_stay():
    a = (('table', {'description': ('string', 'before'), 'name': ('string', 'tool'),
                    'xpm': ('table', {'resource': 'old'})}), 'prefix', 'install hook')
    b = (('table', {**a[0][1], 'description': ('string', 'after')}), a[1], a[2])
    assert planner.runtime_inputs(a) == planner.runtime_inputs(b)
    c = (('table', {**a[0][1], 'name': ('string', 'other')}), a[1], a[2])
    assert planner.runtime_inputs(a) != planner.runtime_inputs(c)
    assert planner.runtime_inputs(a) != planner.runtime_inputs((a[0], a[1], 'changed hook'))


@pytest.mark.parametrize('field,value', [('head_sha', 'other'), ('head_branch', 'feature'),
    ('event', 'pull_request'), ('status', 'in_progress'), ('conclusion', 'failure'),
    ('head_repository', {'full_name': 'foreign/repo'})])
def test_publication_cannot_bypass_source_gate(field, value):
    mod = module('ci-verified-source')
    run = dict(head_sha='a' * 40, head_branch='main', event='push', status='completed',
               conclusion='success', head_repository={'full_name': 'acme/index'})
    assert mod.verified(run, 'acme/index', 'a' * 40)
    run[field] = value
    assert not mod.verified(run, 'acme/index', 'a' * 40)


def test_readme_translation_changes_receive_documentation_validation():
    p = planner.plan(['README.zh.md'], {}, {}, PROFILES)
    assert p['flags']['site_check']
    assert p['install_matrix']['include'] == []
    assert module('ci-publication-scope').selected(['README.zh.md'], 'site')
