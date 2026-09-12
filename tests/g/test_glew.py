"""Tests for the glew package: upstream's source release, installed as the
tree a consumer compiles `src/glew.c` from."""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "glew"
PKG_FILE = "pkgs/g/glew.lua"
VERSION = "2.2.0"


def _code(content: str) -> str:
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def code(meta):
    return _code(meta.raw_content)


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
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.static
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.static
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.static
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.static
    def test_one_source_archive_on_every_host(self, code):
        """The release tarball is host-independent, so the three host tables
        must carry one url and one sha256 -- a difference would be a typo."""
        for host in ("linux", "macosx", "windows"):
            assert re.search(host + r'\s*=\s*\{', code), f"no {host} table"
        urls = re.findall(r'releases/download/glew-' + re.escape(VERSION) + r'/glew-' + re.escape(VERSION) + r'\.tgz', code)
        assert len(urls) == 3
        hashes = re.findall(r'sha256 = "([0-9a-f]{64})"', code)
        assert len(hashes) == 3 and len(set(hashes)) == 1

    @pytest.mark.static
    def test_no_cn_mirror_invented(self, code):
        assert "gitcode.com/xlings-res" not in code
        assert "ci = {" not in code

    @pytest.mark.static
    def test_install_claims_success_only_with_the_two_files(self, code):
        assert '"glew.h"' in code
        assert '"glew.c"' in code
        assert "return os.isfile(header) and os.isfile(source)" in code


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_glew(self):
        assert_xvm_registered("glew")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_installed_tree_has_header_and_source(self):
        from tests.lib.platform_utils import xpkgs_dir
        import glob
        import os
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(f"{xpkgs_dir()}/{ns}-x-glew/{VERSION}"))
        if not hits:
            pytest.skip(f"glew@{VERSION} is not installed")
        d = hits[-1]
        assert os.path.isfile(os.path.join(d, "include", "GL", "glew.h"))
        assert os.path.isfile(os.path.join(d, "src", "glew.c"))
