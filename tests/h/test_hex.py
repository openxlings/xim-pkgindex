"""测试 hex 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_uninstall_succeeds, assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not

PKG = "hex"
PKG_FILE = "pkgs/h/hex.lua"


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
    def test_sha256_covered_for_declared_archs(self, meta):
        # V2 fail-closed: every per-arch entry that carries a url must carry
        # a measured sha256 — a pin-less entry would install an unverified
        # binary. The parser exposes no xpm tree, so scan the raw recipe:
        # each arch block here is flat (url + sha256, no nested braces).
        import re
        for block in re.finditer(
                r'(?:x86_64|aarch64)\s*=\s*\{[^{}]*\}', meta.raw_content):
            text = block.group(0)
            if 'url' in text:
                assert 'sha256' in text, \
                    f"per-arch 资源块缺少 sha256: {text[:80]}..."


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

    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_uninstall(self):
        assert_uninstall_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_hex_version(self):
        # `hex --version` prints "hex <version>" headless (no display needed);
        # the GUI app writes to redirected stdout before any window work.
        assert_command_output("hex --version", regex=r"(?i)\bhex \d+\.\d+")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_hex(self):
        # shim presence, not `xvm info`: the standalone xvm CLI on this
        # machine only prints Runtime Tips, while the subos registry and the
        # subos/default/bin shim are the real routing (same choice as
        # test_aria2_next.py).
        assert_xvm_shim_exists("hex")
