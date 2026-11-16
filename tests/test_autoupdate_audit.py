"""Generate coverage from recipes without a checked-in snapshot; fail closed on opt-ins."""
import importlib.util
from pathlib import Path

import pytest

pytestmark = pytest.mark.static
ROOT = Path(__file__).resolve().parents[1]
RECIPE = '''package = {
    name = "foo", archs = {"x86_64"},
    extensions = { autoupdate = {
        source = "https://github.com/acme/foo/releases",
        resources = { GLOBAL = "https://github.com/acme/foo/releases/download/${tag}/foo.zip" },
    } },
    xpm = { linux = {
        ["latest"] = { ref = "1.0.0" },
        ["1.0.0"] = { url = "https://github.com/acme/foo/releases/download/v1.0.0/foo.zip",
                        sha256 = "''' + 'a' * 64 + '''" },
    } },
}'''


@pytest.fixture
def audit_module():
    # The updater workflow runs this suite with the pinned source available.
    pytest.importorskip('xpkgindex_update')
    spec = importlib.util.spec_from_file_location('autoupdate_audit', ROOT / '.github/scripts/autoupdate-ci.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def index(tmp_path, monkeypatch, audit_module):
    monkeypatch.setattr(audit_module, 'ROOT', tmp_path)
    recipe = tmp_path / 'pkgs/f/foo.lua'
    recipe.parent.mkdir(parents=True)
    recipe.write_text(RECIPE)
    return audit_module, recipe


def test_new_packages_and_declaration_changes_need_no_snapshot(index):
    module, recipe = index
    first = module.audit()
    assert first['enabled'] == ['xim:foo']
    # Changing an approved URL is validated directly, without copying it to an inventory.
    recipe.write_text(RECIPE.replace('foo.zip', 'foo-new.zip'))
    manual = recipe.with_name('manual.lua')
    manual.write_text('package = { name = "manual" }')
    report = module.audit()
    assert report['total'] == 2
    assert report['enabled'] == ['xim:foo']
    assert report['manual'] == 1
    assert {r['path'] for r in report['packages']} == {'pkgs/f/foo.lua', 'pkgs/f/manual.lua'}
    manual.unlink()
    assert module.audit()['total'] == 1
    assert not (recipe.parents[2] / '.agents').exists()


def test_complete_real_index_is_classified_without_an_inventory(audit_module):
    report = audit_module.audit()
    paths = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'pkgs').glob('*/*.lua')}
    assert {r['path'] for r in report['packages']} == paths
    assert report['total'] == len(paths) == len(report['enabled']) + report['manual']
    assert all(r['status'] in ('enabled', 'manual') for r in report['packages'])
    assert all(r['reason'] for r in report['packages'] if r['status'] == 'manual')


def test_chatgpt_official_feed_appends_without_rewriting_helper_history(tmp_path, audit_module):
    """Exercise the actual mixed helper/explicit recipe through check/apply/verify."""
    xim = audit_module.xim
    recipe = tmp_path / 'pkgs/c/chatgpt.lua'
    recipe.parent.mkdir(parents=True)
    before = (ROOT / 'pkgs/c/chatgpt.lua').read_text()
    recipe.write_text(before)
    info = xim.package_info(recipe, tmp_path)
    expected = xim.matrix(info)
    assert {p: set(a) for p, a in expected.items()} == {
        'linux': {'x86_64'}, 'macosx': {'aarch64'},
    }
    newest = max((v for p in info['platforms'].values() for v in p['entries']), key=xim.version_key)
    candidate = newest + '.1'
    enclosure = xim.expand(expected['macosx']['aarch64']['GLOBAL'], candidate, candidate)

    class OfficialFeed:
        def text(self, url, **kwargs):
            assert url == info['autoupdate']['source']
            return (f'<rss xmlns:s="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>'
                    f'<s:shortVersionString>{candidate}</s:shortVersionString><s:version>1</s:version>'
                    f'<enclosure url="{enclosure}" length="12" /></item></channel></rss>')

        def artifact(self, url):
            return {'url': url, 'size': 12, 'sha256': 'b' * 64}

    client = OfficialFeed()
    record = xim.check_package(info, client)
    assert record['status'] == 'update-ready', record
    xim.append(tmp_path, record, client)
    after = xim.package_info(recipe, tmp_path)
    xim.guard(before, after['text'])
    assert set(xim.latest_refs(after).values()) == {candidate}
    assert all(after['platforms'][p]['entries'][candidate].kind == 'table' for p in expected)
    reports = xim.verify_candidates(after, before, client)
    assert reports[0]['status'] == 'verified' and len(reports[0]['assets']) == 2


def test_unreviewed_cn_is_still_rejected(index):
    module, recipe = index
    recipe.write_text(RECIPE.replace('resources = {', 'resources = { CN = "https://unreviewed.example/${version}.zip",'))
    with pytest.raises(module.Invalid, match='reviewed'):
        module.audit()


def test_optional_reviewed_cn_can_be_declared_without_an_inventory(index):
    module, recipe = index
    recipe.write_text(RECIPE.replace('resources = {', '''resources = {
        CN = { required = false, url = "https://mirrors.nju.edu.cn/foo/${version}.zip" },'''))
    assert module.audit()['packages'][0]['targets'] == ['CN', 'GLOBAL']


def test_invalid_opt_in_cannot_silently_become_manual(index):
    module, recipe = index
    recipe.write_text('package = make_recipe({ autoupdate = {} })')
    with pytest.raises(module.Invalid):
        module.audit()


def test_opaque_manual_recipe_does_not_opt_in_from_a_comment(index):
    module, recipe = index
    recipe.write_text('-- autoupdate = {}\npackage = make_recipe()')
    report = module.audit()
    assert report['enabled'] == []
    assert report['manual'] == 1
    assert 'unsupported literal metadata' in report['packages'][0]['reason']


def test_unsupported_runner_is_still_rejected(index):
    module, recipe = index
    recipe.write_text(RECIPE.replace('x86_64', 'riscv64'))
    with pytest.raises(module.Invalid, match='no validated xlings execution environment'):
        module.audit()


@pytest.mark.parametrize('platform,arch', [('macosx', 'x86_64'), ('windows', 'aarch64')])
def test_resource_only_target_is_reported_without_an_installation(index, platform, arch, monkeypatch):
    module, recipe = index
    recipe.write_text(RECIPE.replace('linux', platform).replace('x86_64', arch))
    report = module.audit()
    row = report['packages'][0]
    assert row['installation_targets'] == []
    assert row['resource_only_targets'] == [f'{platform}/{arch}']
    summary = recipe.parents[2] / 'summary.md'
    monkeypatch.setenv('GITHUB_STEP_SUMMARY', str(summary))
    module.summarize_coverage(report)
    assert 'no installation validation' in summary.read_text()
    assert f'{platform}/{arch}' in summary.read_text()


@pytest.mark.parametrize('legacy', [
    'ci = { update = true }',
    'xpm = { linux = { url_template = "https://example.com/${version}" } }',
])
def test_legacy_update_fields_are_still_rejected(index, legacy):
    module, recipe = index
    recipe.write_text('package = { name = "foo", ' + legacy + ' }')
    with pytest.raises(module.Invalid, match='legacy'):
        module.audit()


def commit_fixture(root, message):
    import subprocess
    subprocess.run(['git', 'add', 'pkgs'], cwd=root, check=True)
    subprocess.run(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.org',
                    'commit', '-qm', message], cwd=root, check=True)
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()


def test_new_opt_in_descriptor_uses_regular_package_ci(index):
    import subprocess
    module, recipe = index
    subprocess.run(['git', 'init', '-q'], cwd=module.ROOT, check=True)
    recipe.write_text('package = { name = "manual" }')
    base = commit_fixture(module.ROOT, 'baseline')
    added = recipe.with_name('added.lua')
    added.write_text(RECIPE)
    commit_fixture(module.ROOT, 'new package opting in')
    assert module.candidates(base) == {'include': []}


def test_existing_descriptor_upgrade_still_selects_native_jobs(index):
    import subprocess
    module, recipe = index
    subprocess.run(['git', 'init', '-q'], cwd=module.ROOT, check=True)
    base = commit_fixture(module.ROOT, 'baseline')
    recipe.write_text(RECIPE.replace('["latest"]', '["1.1.0"] = { url = "https://example.com/foo.zip", sha256 = "new" },\n        ["latest"]'))
    commit_fixture(module.ROOT, 'append a candidate')
    assert module.candidates(base) == {'include': [
        {'id': 'xim:foo', 'path': 'pkgs/f/foo.lua', 'version': '1.1.0',
         'platform': 'linux', 'arch': 'x86_64', 'os': 'ubuntu-latest'}]}


@pytest.mark.parametrize('bad_asset', [None, 'omp-darwin-x64', 'omp-windows-arm64.exe'])
def test_six_resource_upgrade_verifies_every_asset_but_installs_four(index, bad_asset):
    """Exercise the real recipe and verifier, including excluded-target hash failures."""
    import subprocess
    module, recipe = index
    before = (ROOT / 'pkgs/o/oh-my-pi.lua').read_text()
    recipe.write_text(before)
    subprocess.run(['git', 'init', '-q'], cwd=module.ROOT, check=True)
    base = commit_fixture(module.ROOT, 'six upstream resources')
    info = module.xim.package_info(recipe, module.ROOT)
    expected = module.xim.matrix(info)
    newest = max((v for p in info['platforms'].values() for v in p['entries']), key=module.xim.version_key)
    version = newest + '.1'
    edits = []
    for platform, arches in expected.items():
        values = {arch: {'url': module.xim.expand(templates['GLOBAL'], version, version),
                         'sha256': 'b' * 64} for arch, templates in arches.items()}
        node = info['platforms'][platform]['node'].definition()
        edits.append((node.end - 1, '\n["' + version + '"] = ' + module.xim.literal(values) + ',\n'))
    after = before
    for position, insertion in sorted(edits, reverse=True):
        after = after[:position] + insertion + after[position:]
    recipe.write_text(after)
    commit_fixture(module.ROOT, 'add all six candidate resources')
    jobs = module.candidates(base)['include']
    assert {(j['platform'], j['arch'], j['os']) for j in jobs} == {
        ('linux', 'x86_64', 'ubuntu-latest'), ('linux', 'aarch64', 'ubuntu-24.04-arm'),
        ('macosx', 'aarch64', 'macos-latest'), ('windows', 'x86_64', 'windows-latest'),
    }
    assert len(jobs) == 4
    assert module.audit()['packages'][0]['resource_only_targets'] == ['macosx/x86_64', 'windows/aarch64']
    checked = []
    class Assets:
        def artifact(self, url):
            checked.append(url)
            return {'url': url, 'size': 12, 'sha256': ('c' if url.endswith(bad_asset or '\0') else 'b') * 64}
    candidate = module.xim.package_info(recipe, module.ROOT)
    if bad_asset:
        with pytest.raises(module.Invalid, match='SHA256 mismatch'):
            module.xim.verify_candidates(candidate, before, Assets())
        assert any(url.endswith(bad_asset) for url in checked)
    else:
        reports = module.xim.verify_candidates(candidate, before, Assets())
        assert len(reports) == 1 and len(reports[0]['assets']) == len(checked) == 6
        assert reports[0]['status'] == 'verified'
    assert module.xim.matrix(candidate) == expected


MANUAL = '''package = {
    name = "foo", archs = {"x86_64"},
    xpm = { linux = {
        ["latest"] = { ref = "1.0.0" },
        ["1.0.0"] = { url = "XLINGS_RES", sha256 = { x86_64 = "''' + 'a' * 64 + '''" } },
    } },
}'''


def _guarded(index, before, after):
    import subprocess
    module, recipe = index
    subprocess.run(['git', 'init', '-q'], cwd=module.ROOT, check=True)
    recipe.write_text(before)
    base = commit_fixture(module.ROOT, 'baseline')
    recipe.write_text(after)
    return module, base


def test_a_recipe_no_bot_writes_moves_its_latest_by_review(index):
    """xlings' release writes xlings, luban, luban-os and xdesk (test_release_owned.py)."""
    after = MANUAL.replace('["latest"] = { ref = "1.0.0" },', '["latest"] = { ref = "1.1.0" },\n'
                           '        ["1.1.0"] = { url = "XLINGS_RES", sha256 = { x86_64 = "' + 'b' * 64 + '" } },')
    module, base = _guarded(index, MANUAL, after)
    assert module.guard(base)['changed'] == [{'path': 'pkgs/f/foo.lua', 'rules': 'preserved'}]


def test_a_published_version_is_kept_in_every_recipe(index):
    module, base = _guarded(index, MANUAL, MANUAL.replace('a' * 64, 'c' * 64))
    with pytest.raises(module.Invalid, match='existing version changed'):
        module.guard(base)


def test_a_recipe_a_bot_writes_keeps_the_automatic_rules(index):
    moved = RECIPE.replace('["latest"] = { ref = "1.0.0" }', '["latest"] = { ref = "0.9.0" }')
    module, base = _guarded(index, RECIPE, moved)
    with pytest.raises(module.Invalid):
        module.guard(base)


def test_candidate_verification_receives_the_installed_version(index, monkeypatch):
    """A clean candidate home contains only the new version, never the old pin."""
    import json
    import shutil
    module, recipe = index
    home = recipe.parents[2] / 'home'
    install = home / 'data/xpkgs/local-x-foo/1.1.0'
    test = recipe.parents[2] / 'tests/f/test_foo.py'
    test.parent.mkdir(parents=True)
    test.write_text('# package verification entry point\n')
    monkeypatch.chdir(recipe.parents[2])
    monkeypatch.setenv('XLINGS_HOME', str(home))
    monkeypatch.setenv('XLINGS_TEST_VERSION', '1.0.0')
    monkeypatch.setattr(module, 'git', lambda *args: 'a' * 40)
    verified = []
    runner_python = module.sys.executable
    def run(command, **kwargs):
        if command[:2] == ['xlings', 'install']:
            install.mkdir(parents=True)
            (install / '.xpkg.lua').write_text('metadata')
            (install / 'payload').write_text('candidate')
            # Installing a Python dependency can shadow the runner interpreter.
            bindir = home / 'subos/default/bin'
            bindir.mkdir(parents=True)
            shadow = bindir / 'python'
            shadow.write_text('#!/bin/sh\nexit 99\n')
            shadow.chmod(0o755)
            monkeypatch.setenv('PATH', str(bindir) + __import__('os').pathsep + __import__('os').environ['PATH'])
        elif command[1:3] == ['-m', 'pytest']:
            assert shutil.which('python') == str(home / 'subos/default/bin/python')
            assert command[0] == runner_python
            verified.append(kwargs['env'])
            assert kwargs['env']['XLINGS_TEST_VERSION'] == '1.1.0'
            assert kwargs['env']['XLINGS_TEST_SUBOS'] == 'default'
        elif command[:2] == ['xlings', 'remove']:
            shutil.rmtree(install)
    monkeypatch.setattr(module.subprocess, 'run', run)
    module.run_candidate('xim:foo', 'pkgs/f/foo.lua', '1.1.0')
    assert len(verified) == 1
    evidence = json.loads((recipe.parents[2] / 'candidate-evidence.json').read_text())
    assert evidence['version'] == '1.1.0' and evidence['status'] == 'verified-and-removed'
