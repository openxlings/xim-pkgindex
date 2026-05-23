"""测试 claude-code 包"""
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

PKG = "claude"
PKG_FILE = "pkgs/c/claude.lua"


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


class TestDesign:
    @pytest.mark.static
    def test_runtime_entry_supports_both_layouts(self):
        content = open(PKG_FILE, encoding='utf-8').read()
        assert "function __claude_entry()" in content
        assert "@anthropic-ai" in content
        assert "claude.exe" in content
        assert "cli.js" in content
        assert "node \"%s\"" in content

    @pytest.mark.static
    def test_claude_config_env(self):
        content = open(PKG_FILE, encoding='utf-8').read()
        assert "CLAUDE_CONFIG_DIR" in content


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG, timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_claude_version(self):
        assert_command_output("claude --version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_claude(self):
        assert_xvm_registered("claude")
