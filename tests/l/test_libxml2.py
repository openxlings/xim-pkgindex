"""测试 libxml2 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not

PKG = "libxml2"
PKG_FILE = "pkgs/l/libxml2.lua"


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
    def test_the_pkgconfig_file_is_relocated_and_declared(self, meta):
        """The payload ships `lib/pkgconfig/libxml-2.0.pc` written for the
        prefix it was built in (`prefix=/tmp/libxml2-install`). install()
        relocates it and config() declares it into the SubOS pkg-config view;
        before this, it was the one `.pc` of the GTK 4 stack absent from the
        view (measured on a fresh home, mcpp#635)."""
        code = "\n".join(l for l in meta.raw_content.splitlines()
                         if not l.lstrip().startswith("--"))
        assert 'import("xim.pkgindex.sysroot")' in code
        install = code[code.index("function install()"):code.index("function config()")]
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert 'sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")' in install
        assert 'sysroot.declare_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig", binding)' in config

    @pytest.mark.static
    def test_the_revision_installs_the_release_it_revises(self, meta):
        """"2.13.5-1" downloads the 2.13.5 archive, whose top-level directory
        is `libxml2-2.13.5-linux-x86_64`, so the directory is named from the
        upstream version and not from the version key."""
        code = "\n".join(l for l in meta.raw_content.splitlines()
                         if not l.lstrip().startswith("--"))
        assert '["latest"] = { ref = "2.13.5-1" }' in code
        assert '["2.13.5-1"] = {' in code
        assert '["2.13.5"] = {' in code, "xim:llvm pins 2.13.5 exactly"
        assert code.count("libxml2-2.13.5-linux-x86_64.tar.gz") == 4
        assert 'gsub("%-%d+$", "")' in code
        assert 'sysroot.adopt_payload("libxml2-" .. upstream_version() .. "-linux-x86_64")' in code


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
        assert_install_succeeds(PKG)
