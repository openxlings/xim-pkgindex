"""测试 libcuda-host-link 包"""
import os
import re
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "libcuda-host-link"
PKG_FILE = "pkgs/l/libcuda-host-link.lua"
VERSION = "0.0.2"


def recipe_sonames():
    """The names the recipe promises, read from the recipe.

    The denominator comes from the file under test rather than from a copy
    here, so a name added to SONAMES without a link being created fails. The
    size is asserted separately: a list this function read as empty would
    otherwise satisfy every per-name assertion vacuously.
    """
    with open(PKG_FILE, encoding="utf-8") as f:
        body = f.read()
    m = re.search(r"^local SONAMES = \{(.*?)\}", body, re.M | re.S)
    assert m, "SONAMES list not found in " + PKG_FILE
    return re.findall(r'"([^"]+)"', m.group(1))


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
    def test_recipe_promises_more_than_libcuda(self):
        # The size of the denominator, stated once. Every per-name assertion
        # in TestVerify would pass vacuously on an empty or truncated list.
        #
        # `static` rather than `verify` deliberately: this is a property of the
        # recipe text, and the verify marker is not selected by any CI job for
        # this package, so an assertion placed there would be written, green
        # and never run.
        names = recipe_sonames()
        assert "libcuda.so.1" in names
        assert "libnvidia-ml.so.1" in names, (
            "the SYCL runtime's CUDA adapter needs NVML beside libcuda "
            "(mcpp#596); a sentinel that answers for one of them is the "
            "defect that issue reports"
        )


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
        # Sentinel package install should always succeed regardless of
        # whether the host has an NVIDIA driver — the symlink is
        # intentionally allowed to be dangling so it self-heals on a
        # later driver install.
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_links_exist(self):
        # The package should always create every symlink, regardless of host
        # driver presence: a dangling link is the documented self-heal shape,
        # so `islink` rather than `exists` is the property being asserted.
        libdir = os.path.join(
            xpkgs_dir(), "xim-x-libcuda-host-link", VERSION, "lib",
        )
        for soname in recipe_sonames():
            link = os.path.join(libdir, soname)
            assert os.path.islink(link), f"sentinel symlink missing: {link}"
