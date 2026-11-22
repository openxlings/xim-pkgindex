"""Tests for the magpie-cli package."""
import re

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_xvm_registered, assert_config_registers_package_name,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test
from tests.m._magpie_resources import (
    PLATFORMS, latest_refs, platform_resources,
)
from tests.m._magpie_shim import shim_output

PKG = "magpie-cli"
PKG_FILE = "pkgs/m/magpie-cli.lua"
VERSION = "0.1.4657"

# Upstream's release SHA256SUMS for v0.1.4657.
EXPECTED = {
    "linux": {
        "x86_64": ("magpie-cli-linux-amd64",
                   "52c8efaa2cd43e9801b19b5c3ab3abc9d4d4a4b4efcf1e85edd4c3542e4b472c"),
        "aarch64": ("magpie-cli-linux-arm64",
                    "36f717e2f7f2d937dac7c6272c7c4cf12200c0ba4bb7905edb60747efce843ba"),
    },
    "macosx": {
        "x86_64": ("magpie-cli-darwin-amd64",
                   "7bf97b01638df9d4f5b72e533ada67f0f0bdd4d05c23e5bdb9054dc99b404da9"),
        "aarch64": ("magpie-cli-darwin-arm64",
                    "19185305feb4c7ca35002f44d854b8fa3ff4380e4bd149602f98219a4e14fb6a"),
    },
    "windows": {
        "x86_64": ("magpie-cli-windows-amd64.exe",
                   "7b520b795ac320e90d164abf8dec96c7416cc440cad3b527f467f397cbdbefac"),
        "aarch64": ("magpie-cli-windows-arm64.exe",
                    "06c48152b46a0cd9d12c56365f29211349a744f85296a5eca6150919cd393c61"),
    },
}

BASE = f"https://github.com/yetone/magpie/releases/download/v{VERSION}"


def _code():
    text = open(PKG_FILE, encoding="utf-8").read()
    return re.sub(r"--[^\n]*", "", text)


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
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_import_boundary(self):
        imports = re.findall(r'import\("([^"]+)"\)', _code())
        assert imports, "recipe imports nothing"
        assert all(name.startswith("xim.libxpkg.") for name in imports), imports

    @pytest.mark.static
    def test_platform_matrix(self):
        resources = platform_resources(PKG_FILE, VERSION)
        assert set(resources) == set(PLATFORMS), sorted(resources)
        for platform, expected in EXPECTED.items():
            for arch, (asset, sha) in expected.items():
                got = resources[platform][arch]
                assert got["url"] == f"{BASE}/{asset}", f"{platform}/{arch}: {got['url']}"
                assert got["sha256"] == sha, f"{platform}/{arch}: {got['sha256']}"

    @pytest.mark.static
    def test_latest_refs_agree(self):
        refs = latest_refs(PKG_FILE)
        assert set(refs) == set(PLATFORMS), sorted(refs)
        assert set(refs.values()) == {VERSION}, refs

    @pytest.mark.static
    def test_android_is_not_a_platform(self):
        """Upstream publishes magpie-cli-android-arm64 for Termux.

        xlings looks up a host platform among linux/macosx/windows only, so an
        android section could never be selected. It is deliberately absent.
        """
        resources = platform_resources(PKG_FILE, VERSION)
        assert "android" not in resources
        assert len(resources) == 3

    @pytest.mark.static
    def test_manual_update_reason_is_documented(self):
        """No autoupdate opt-in, and the recipe says why.

        GitHub's list-releases API refuses page 11 of this project with 422
        ("Only the first 1000 results are available"), which makes the pinned
        updater error on every scan. Bumps stay manual until that changes.
        """
        text = open(PKG_FILE, encoding="utf-8").read()
        assert "autoupdate" not in _code(), "autoupdate cannot enumerate >1000 releases"
        assert "1000 results" in text
        assert "SHA256SUMS" in text

    @pytest.mark.static
    def test_no_runtime_deps(self):
        """The Linux build is a static Go binary (readelf -d: no DT_NEEDED)."""
        assert not re.search(r"(?m)^\s*deps\s*=", _code())

    @pytest.mark.static
    def test_registers_a_distinct_command(self):
        """It must not claim `magpie`: the desktop package owns that name.

        Both upstream builds report the same version, so two xvm registrations
        of `magpie` at 0.1.4657 would collide ("another package already owns
        this exact name and version"). Renaming the payload keeps both
        packages installable side by side.
        """
        meta = parse_xpkg(PKG_FILE)
        assert meta.programs == ["magpie-cli"]
        code = _code()
        assert 'xvm.add("magpie-cli"' in code
        assert 'xvm.add("magpie"' not in code
        # The upstream asset is `magpie`; the installed command is renamed.
        assert '"magpie-cli.exe"' in code and '"magpie-cli"' in code

    @pytest.mark.static
    def test_installed_checks_the_executable(self):
        code = _code()
        body = code[code.index("function installed()"):code.index("function config()")]
        assert "os.isfile" in body
        assert "os.isdir" not in body


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
    def test_install(self):
        assert_install_succeeds(under_test(PKG, VERSION), timeout=900)


class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        code, out = shim_output("magpie-cli", "--version")
        assert code == 0 and VERSION in out, out[:300]
        assert_xvm_registered("magpie-cli")