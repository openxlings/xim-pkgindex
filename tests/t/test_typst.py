"""typst"""
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_valid_xvm_node_kinds,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "typst"
PKG_FILE = "pkgs/t/typst.lua"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def code(meta):
    return "\n".join(
        line for line in meta.raw_content.splitlines()
        if not line.lstrip().startswith("--")
    )


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)
        assert meta.spec == "2"

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_expected_platforms(self, meta):
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)

    @pytest.mark.static
    def test_no_forbidden_xmake_apis(self, code):
        for pat in (r"\bpath\.", r"\bos\.host\s*\(", r"\bis_host\s*\(", r"\btry\s*\{", r"\braise\s*\("):
            assert not re.search(pat, code), f"forbidden xmake API pattern matched: {pat}"

    @pytest.mark.static
    def test_autoupdate_and_mirror_configured(self, meta, code):
        assert meta.programs == ["typst"]
        assert meta.has_xvm_enable
        assert "ci = { mirror = true }" in code
        assert 'source = "https://github.com/typst/typst/releases"' in code
        assert "${tag}" in code


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

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("typst --version", contains="typst 0.15.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("typst")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_compiles_typ_to_pdf(self, tmp_path):
        src = tmp_path / "hello.typ"
        out = tmp_path / "hello.pdf"
        src.write_text("= Hello Typst\n\nCompiled by xlings.\n", encoding="utf-8")
        proc = subprocess.run(
            ["bash", "-l", "-c", f'typst compile "{src}" "{out}"'],
            capture_output=True,
            text=True,
            timeout=30,
            check=True,
        )
        assert proc.returncode == 0
        assert out.is_file()
        assert out.read_bytes().startswith(b"%PDF-")
