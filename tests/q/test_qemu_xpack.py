"""qemu-arm and qemu-x86 (xPack): each emulator binds to its package's release."""
import os

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import assert_required_fields, assert_valid_spec, assert_no_typos
from tests.lib.platform_utils import project_root

PACKAGES = {
    "qemu-arm": ("pkgs/q/qemu-arm.lua", ["qemu-system-aarch64", "qemu-system-arm"]),
    "qemu-x86": ("pkgs/q/qemu-x86.lua", ["qemu-system-x86_64"]),
}


def source(path):
    with open(os.path.join(project_root(), path), encoding="utf-8") as handle:
        return handle.read()


@pytest.mark.static
@pytest.mark.parametrize("name", sorted(PACKAGES))
def test_manifest(name):
    path, _ = PACKAGES[name]
    meta = parse_xpkg(path)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_no_typos(path)


@pytest.mark.static
@pytest.mark.parametrize("name", sorted(PACKAGES))
def test_emulators_bind_to_the_release(name):
    """Without the binding, self doctor reads the package-name anchor as a
    broken payload (xlings 2026.10.12.1)."""
    path, programs = PACKAGES[name]
    text = source(path)
    assert 'local release = package.name .. "@" .. pkginfo.version()' in text
    for program in programs:
        assert f'xvm.add("{program}", {{ bindir = bindir, binding = release }})' in text


@pytest.mark.static
@pytest.mark.parametrize("name", sorted(PACKAGES))
def test_every_platform_raised_its_revision(name):
    """The config changed, so every scope must configure again (revision)."""
    text = source(PACKAGES[name][0])
    assert text.count("revision = 1,") == 3
