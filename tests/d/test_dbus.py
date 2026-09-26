"""测试 dbus 包 (libdbus-1 客户端库)"""
import glob
import os
import subprocess
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "dbus"
PKG_FILE = "pkgs/d/dbus.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


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
    def test_both_mirrors_and_digests(self, meta):
        src = meta.raw_content
        for arch in ("x86_64", "aarch64"):
            name = f"dbus-1.16.2-linux-{arch}.tar.gz"
            assert f"https://github.com/xlings-res/dbus/releases/download/1.16.2/{name}" in src
            assert f"https://gitcode.com/xlings-res/dbus/releases/download/1.16.2/{name}" in src


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
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG, timeout=180)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_library_names_the_system_bus(self):
        """库中的系统总线地址是 /var/run/dbus/system_bus_socket，而非 conda 的构建前缀。"""
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-dbus", "*", "lib", "libdbus-1.so.3")))
        assert hits, f"no dbus payload under {xpkgs_dir()}"
        data = open(os.path.realpath(hits[-1]), "rb").read()
        assert b"unix:path=/var/run/dbus/system_bus_socket\x00" in data
        assert b"placehold" not in data
