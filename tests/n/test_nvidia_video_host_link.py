"""测试 nvidia-video-host-link 包"""
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

PKG = "nvidia-video-host-link"
PKG_FILE = "pkgs/n/nvidia-video-host-link.lua"
VERSION = "0.0.1"


def recipe_sonames():
    """The names the recipe promises, read from the recipe.

    The denominator comes from the file under test rather than from a copy
    here, so a name added to SONAMES without a link being created fails, and a
    name removed fails too. The size is asserted separately: a list this
    function read as empty would satisfy every per-name assertion vacuously.
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
    def test_recipe_answers_for_the_codec_userspace(self):
        # The denominator, stated once, and the reason this package is separate
        # from libcuda-host-link.
        #
        # `static` rather than `verify` deliberately: this is a property of the
        # recipe text, and the verify marker is not selected by any CI job for
        # a sentinel package, so an assertion placed there would be written,
        # green and never run.
        names = recipe_sonames()
        assert names, "SONAMES is empty; every per-name assertion would pass vacuously"
        assert "libnvcuvid.so.1" in names, (
            "libnvidia-encode and libnvidia-opticalflow name libnvcuvid in "
            "DT_NEEDED; a farm that carried those two without it published "
            "libraries that could not load"
        )

    @pytest.mark.static
    def test_does_not_duplicate_the_compute_sentinel(self):
        # Two sentinels answering for one soname is the shape compat.glx-runtime
        # records for the GL vendor names: two routes to the same file that
        # disagree the day the driver is upgraded underneath. The split is by
        # NEED -- compute, graphics, codec -- so the lists must not overlap.
        with open("pkgs/l/libcuda-host-link.lua", encoding="utf-8") as f:
            compute = set(re.findall(r'"([^"]+)"',
                          re.search(r"^local SONAMES = \{(.*?)\}",
                                    f.read(), re.M | re.S).group(1)))
        assert compute, "the compute sentinel's list read as empty"
        overlap = compute & set(recipe_sonames())
        assert not overlap, (
            "these sonames are answered for by libcuda-host-link as well: "
            + ", ".join(sorted(overlap))
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
        # Installing succeeds whether or not the host has the driver: the link
        # is allowed to dangle at the canonical path so it self-heals when the
        # distro driver package is installed later.
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_every_promised_name_has_a_link(self):
        libdir = os.path.join(xpkgs_dir(), f"xim-x-{PKG}", VERSION, "lib")
        if not os.path.isdir(libdir):
            pytest.skip(f"{PKG} is not installed in this environment")
        names = recipe_sonames()
        assert names, "SONAMES read as empty"
        for soname in names:
            link = os.path.join(libdir, soname)
            # islink, not exists: a dangling link is the documented shape on a
            # machine with no driver, and asserting existence would turn a
            # supported configuration into a failure.
            assert os.path.islink(link), f"{soname} has no link in {libdir}"
