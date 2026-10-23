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
