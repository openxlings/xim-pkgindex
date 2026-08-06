"""测试 perl 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "perl"
PKG_FILE = "pkgs/p/perl.lua"


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
        # Perl's lib tree is ~2300 files; the default 180s can be tight on a
        # cold cache.
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_perl_runs(self):
        assert_command_output("perl -e 'print \"ok\\n\"'", contains="ok")

    # The whole point of the package: a perl that HAS its core modules. A
    # binary that runs but cannot `use FindBin` is the exact failure this
    # package exists to prevent (mcpplibs/mcpp-index#140), and `perl
    # --version` would pass right through it.
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_core_modules_load(self):
        assert_command_output(
            "perl -MFindBin -MConfig -MFile::Path -MPOSIX -MIO::File "
            "-MDigest::MD5 -MExtUtils::MakeMaker -e 'print \"core-ok\\n\"'",
            contains="core-ok",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_perl(self):
        assert_xvm_registered("perl")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_perldoc(self):
        assert_xvm_registered("perldoc")
