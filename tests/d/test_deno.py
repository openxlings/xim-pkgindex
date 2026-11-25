"""测试 deno 包"""
import re
import shutil
import subprocess
from pathlib import Path

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_valid_xvm_node_kinds,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "deno"
PKG_FILE = "pkgs/d/deno.lua"
VERSION = "2.9.8"
REPO = Path(__file__).resolve().parent.parent.parent


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


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
    def test_platforms_and_programs(self, meta):
        assert set(meta.platforms) >= {"linux", "macosx", "windows"}
        assert "deno" in meta.programs
        assert meta.has_xvm_enable
        assert meta.has_installed
        assert meta.has_install
        assert meta.has_config
        assert meta.has_uninstall

    @pytest.mark.static
    def test_linux_declares_runtime_deps(self, meta):
        assert "xim:glibc" in meta.raw_content
        assert "xim:gcc-runtime" in meta.raw_content

    @pytest.mark.static
    def test_all_six_sha256_present(self, meta):
        sha_matches = re.findall(r'sha256\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        # 2 arches x 3 platforms = 6 unique digests
        assert len(sha_matches) == 6
        assert len(set(sha_matches)) == 6

    @pytest.mark.static
    @pytest.mark.skipif(shutil.which("luac") is None, reason="no luac on this machine")
    def test_lua_syntax(self):
        r = subprocess.run(["luac", "-p", str(REPO / PKG_FILE)],
                           capture_output=True, text=True)
        assert r.returncode == 0, r.stderr


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

    @pytest.mark.isolation
    def test_no_deprecated_xmake_apis(self, meta):
        code = "\n".join(
            line for line in meta.raw_content.splitlines()
            if not line.lstrip().startswith("--")
        )
        for bad in ("os.arch", "os.curdir", "os.execv", "os.files",
                    "path.absolute", "is_host", "try {", "raise("):
            assert bad not in code, f"unexpected deprecated API {bad!r} in {PKG_FILE}"


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_deno_version(self):
        assert_command_output("deno --version", contains=f"deno {VERSION}")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_deno_eval(self):
        assert_command_output('deno eval "console.log(1 + 2)"', contains="3")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_deno(self):
        # `xvm info` prints runtime tips and exits 0 for any target on current
        # xlings, so assert the real shim landed instead (same as test_node.py).
        assert_xvm_shim_exists("deno")
