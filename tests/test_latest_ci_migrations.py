"""The legacy update contract is retired; package declarations remain authoritative."""
from pathlib import Path

import pytest

ROOT = Path(__file__).parents[1]


@pytest.mark.static
@pytest.mark.parametrize('package', ('fish', 'griddycode'))
def test_existing_mirror_packages_use_the_unified_declaration(package):
    text = (ROOT / 'pkgs' / package[0] / (package + '.lua')).read_text()
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
def test_cn_package_uses_dual_required_targets_and_keeps_publication():
    text = (ROOT / 'pkgs/p/pnpm.lua').read_text()
    declaration = text.split('autoupdate = {', 1)[1].split('xpm = {', 1)[0]
    assert 'GLOBAL = {' in declaration and 'CN = {' in declaration
    assert declaration.count('required = true') == 2
    assert 'mirror = true' in text
    assert 'autoupdate = {' in text
