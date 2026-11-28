"""测试 clash-flux 包。"""
import re

import pytest

from tests.lib.assertions import (
    assert_command_output,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_xim_add_succeeds,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not
from tests.lib.xpkg_parser import parse_xpkg


PKG = "farnaherry:clash-flux@0.3.131"
PROGRAM = "clash-flux"
PKG_FILE = "pkgs/c/clash-flux.lua"


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

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_release_assets_are_pinned(self, meta):
        source = meta.raw_content
        assert '["latest"] = { ref = "0.3.131" }' in source
        assert source.count('["latest"] = { ref = "0.3.131" }') == 3
        assert source.count('["0.3.131"] = {') == 3
        assert source.count('["0.1.3"] = {') == 3
        # 0.3.131 pinned sha256s
        assert source.count('"4357995dabe0b087a3e6f1dc1f19881ce0d312c69589eb3ed534f8af0a08694d"') == 1
        assert source.count('"a0e72d8ab398d5d524f376e6fa28031ee913df9cadfa3579add5e297464d4979"') == 1
        assert source.count('"ca974e97b942fea7189b37274d16e99ca5b03375578789b11264ac5b2279d416"') == 1
        assert source.count('"5fe666eccc505c7dad83eaca33a0b6110f7acbef85b65b5ed354372cca02227a"') == 1
        assert re.search(r"clash-flux-\$\{version\}-linux-\$\{arch\}\.\$\{ext\}", source)
        assert re.search(r"clash-flux-\$\{version\}-macos-\$\{arch_alias\}\.\$\{ext\}", source)
        assert re.search(r"clash-flux-\$\{version\}-windows-\$\{arch\}\.\$\{ext\}", source)
        # 0.1.3 published entries preserved
        assert source.count('"87263deb4ea50ec19a8c5c96b2c348f3b785e91607109b52d35f83663c2760d5"') == 1
        assert source.count('"578503bebff0111fbbd11b9518387b3f43b84419a4cf4684eec744eed83f8195"') == 1
        assert source.count('"908b9b07f5b3c05d040adf9c73839b4ca0132d20587b0f506eb70aad6493c077"') == 1
        assert source.count('"90f69e2cf5190dee8be8d2dd0c9b20e485ce89686d9485f1f8379c610461a4a2"') == 1
        assert re.search(r"build-linux-x86_64\.tar\.gz", source)
        assert re.search(r"build-linux-arm64\.tar\.gz", source)
        assert re.search(r"build-macos-arm64\.tar\.gz", source)
        assert re.search(r"windows-x86_64\.zip", source)

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
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("clash-flux version", contains="Clash-Flux v0.3.131")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shim(self):
        assert_xvm_shim_exists(PROGRAM)
