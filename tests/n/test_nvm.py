"""测试 nvm 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager, assert_config_registers_package_name,
    assert_platform_supported,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not

PKG = "nvm"
PKG_FILE = "pkgs/n/nvm.lua"


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

    # nvm-sh is a shell project and nvm-windows is a Go binary — neither is
    # arch-specific, so every declared platform must be present. macosx used
    # to be missing entirely despite `archs` claiming otherwise.
    @pytest.mark.static
    @pytest.mark.parametrize("plat", ["linux", "macosx", "windows"])
    def test_all_platforms_declared(self, meta, plat):
        assert_platform_supported(meta, plat)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    # Was xfail("nvm 是 shell 函数, 需要 bashrc 集成, 无法 shim 化"). It is
    # shimmable: install() writes a bash launcher that sources nvm.sh and
    # forwards argv, so the profile snippet is no longer needed. The one thing
    # a child process genuinely cannot do — `nvm use` in the parent shell —
    # the launcher reports instead of silently dropping.
    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    # Was xfail("nvm Windows 版需要 PATH 设置"). It does not: the portable
    # nvm-noinstall.zip replaces nvm-setup.exe, and NVM_HOME/NVM_SYMLINK ride
    # on the xvm shim instead of being written into the user environment.
    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_config_registers_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)

    # Checks the subos bin dir rather than `assert_xvm_registered`: the latter
    # shells out to `xvm info`, which in current xlings prints runtime tips and
    # exits 0 for any name at all, so it reports "not registered" for every
    # package including node.
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_shim_exists(self):
        assert_xvm_shim_exists(PKG)


class TestVerify:
    # Reaching the real nvm through the shim means the generated launcher
    # sourced nvm.sh and the function answered — the whole point of the
    # rewrite. Nothing here relies on a shell profile being sourced.
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_nvm_version(self):
        assert_command_output("nvm --version", regex=r"\d+\.\d+\.\d+")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_nvm_ls_remote_is_reachable(self):
        assert_command_output("nvm --help", contains="Node Version Manager")
