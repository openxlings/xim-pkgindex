"""qemu-system: both system emulators, static, with user networking and firmware."""
import os

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, project_root

PKG = "qemu-system"
PKG_FILE = "pkgs/q/qemu-system.lua"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def source_text():
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_both_emulators_are_programs(self, meta):
        """xlings's tool table maps both emulators to this package (luban try)."""
        assert set(meta.programs) >= {"qemu-system-x86_64", "qemu-system-aarch64"}

    @pytest.mark.static
    def test_every_architecture_has_its_own_resource(self, source_text):
        for arch in ("x86_64", "aarch64"):
            assert f"qemu-system-9.2.4-r2-linux-{arch}.tar.gz" in source_text
        assert "@X86_64@" not in source_text and "@AARCH64@" not in source_text, "a hash left unfilled"

    @pytest.mark.static
    def test_static_payload_declares_no_loader(self, source_text):
        """A static payload has nothing for elfpatch to relocate: no deps."""
        assert "deps" not in source_text.split("xpm = {", 1)[1].split("import(", 1)[0]


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shims(self):
        assert_xvm_shim_exists("qemu-system-x86_64")
        assert_xvm_shim_exists("qemu-system-aarch64")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_user_networking(self):
        """The reason this package exists: `-nic user` (luban try --proxy)."""
        assert_command_output("qemu-system-aarch64 -M none -netdev help", contains="user")
        assert_command_output("qemu-system-x86_64 -M none -netdev help", contains="user")
