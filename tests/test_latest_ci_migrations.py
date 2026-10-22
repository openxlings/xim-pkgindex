"""The legacy update contract is retired; coverage decisions stay reviewable."""
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).parents[1]
AUDIT = ROOT / '.agents/docs/2026-10-22-autoupdate-package-audit.json'


@pytest.mark.static
def test_complete_inventory_and_explicit_eligibility_decisions():
    data = json.loads(AUDIT.read_text())
    rows = data['packages']
    paths = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'pkgs').glob('*/*.lua')}
    assert len(rows) == len(paths)
    assert {r['path'] for r in rows} == paths
    for row in rows:
        assert row['status'] in ('enabled', 'manual'), row
        if row['status'] == 'enabled':
            assert row['stars'] > 50
            assert set(row['autoupdate']) >= {'upstream', 'tag', 'latest', 'url'}
            assert 'autoupdate = {' in (ROOT / row['path']).read_text()
        else:
            assert row['reason'], row


@pytest.mark.static
@pytest.mark.parametrize('package', ('fish', 'griddycode'))
def test_existing_mirror_packages_use_the_unified_declaration(package):
    row = next(r for r in json.loads(AUDIT.read_text())['packages'] if r.get('id') == 'xim:' + package)
    assert row['status'] == 'enabled', row
    text = (ROOT / row['path']).read_text()
    assert 'mirror = true' in text
    assert 'autoupdate = {' in text
    assert 'update = true' not in text


@pytest.mark.static
def test_legacy_executable_entry_points_are_removed():
    for name in ('.github/scripts/version-check.py', '.github/workflows/version-check.yml',
                 '.github/workflows/version-bump.yml', '.github/xpkg-ci.yml'):
        assert not (ROOT / name).exists()
    mirror = (ROOT / 'tools/xpkg_ci.py').read_text()
    assert 'load_vcheck' not in mirror and 'def cmd_scan' not in mirror and 'def cmd_propose' not in mirror


@pytest.mark.static
def test_cn_package_keeps_mirror_publication_but_not_autoupdate():
    row = next(r for r in json.loads(AUDIT.read_text())['packages'] if r.get('id') == 'xim:pnpm')
    assert row['status'] == 'manual' and 'CN' in row['reason']
    text = (ROOT / row['path']).read_text()
    assert 'mirror = true' in text
    assert 'autoupdate = {' not in text
