"""Tests for the magpie desktop package."""
import re

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
    assert_xvm_registered, assert_config_registers_package_name,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import skip_if_not, under_test
from tests.m._magpie_resources import (
    PLATFORMS, latest_refs, platform_resources,
)
from tests.m._magpie_shim import install_package, shim_output

PKG = "magpie"
PKG_FILE = "pkgs/m/magpie.lua"
VERSION = "0.1.4657"

# Upstream's release SHA256SUMS for v0.1.4657. The index carries these
# verbatim; a typo here is only caught by an install after a ~100 MB download.
EXPECTED = {
    "linux": {
        "x86_64": ("magpie-linux-amd64",
                   "dd7c38f9fa24f862e091dc0e3d3e9c6615b6a2eaec2012f717f46a6b28a4279d"),
        "aarch64": ("magpie-linux-arm64",
                    "e761eea9b332c8d8687412a25b815d7a6f53b1c4322ae6e2e4be688b3032e4f3"),
    },
    "macosx": {
        "x86_64": ("magpie-darwin-amd64.zip",
                   "8ad6f3ac9060550f6cbd7f00bcd9a4366bddf4325934e3576f1001f65835438f"),
        "aarch64": ("magpie-darwin-arm64.zip",
                    "8dc23b344e0e8ce1583c31373ace4a86502bc780ab2c961aae73c4e1e8e85c2d"),
    },
    "windows": {
        "x86_64": ("magpie-windows-amd64.exe",
                   "07e1f5779508ae0296365b64f6174131e7b01db37fcec9cb71104bbfd19c1f00"),
        "aarch64": ("magpie-windows-arm64.exe",
                    "4949207245c8aa5c93b5e0c716fd178ac0be67fc275e5deb032e77611d8be4e1"),
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
        """Hooks use libxpkg only — no xmake-private runtime."""
        imports = re.findall(r'import\("([^"]+)"\)', _code())
        assert imports, "recipe imports nothing"
        assert all(name.startswith("xim.libxpkg.") for name in imports), imports

    @pytest.mark.static
    def test_platform_matrix(self):
        """Every platform/arch points at the matching upstream asset + hash."""
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
        """The CLI publishes a Termux asset; xlings has no Android host platform."""
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
        """The Linux GUI binary is a host application.

        It links against the host's GTK 3 and WebKitGTK 4.1 (readelf -d), which
        this index does not provide. Declaring xim:glibc would only hand
        elfpatch a loader provider and rewrite the interpreter of a binary
        whose other libraries still come from the host.
        """
        assert not re.search(r"(?m)^\s*deps\s*=", _code())
        assert "gtk3" not in _code()

    @pytest.mark.static
    def test_programs_and_layout(self):
        meta = parse_xpkg(PKG_FILE)
        assert meta.programs == ["magpie"]
        code = _code()
        # macOS bundle stays together; its inner binary is registered.
        assert 'path.join(app_dir(), "Contents", "MacOS")' in code
        # Raw downloads are renamed to a stable command name.
        assert '"magpie.exe"' in code and '"magpie"' in code
        assert "chmod +x" in code

    @pytest.mark.static
    def test_installed_checks_the_executable(self):
        code = _code()
        assert "function installed()" in code
        assert "os.isfile(exe_path())" in code
        assert "os.isdir" not in code[code.index("function installed()"):code.index("function config()")]


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
        ok, out = install_package(under_test(PKG, VERSION))
        assert ok, out[-400:]


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("windows")
    def test_version_windows(self):
        code, out = shim_output("magpie", "--version")
        assert code == 0 and VERSION in out, out[:300]
        assert_xvm_registered("magpie")

    @pytest.mark.verify
    @skip_if_not("macosx")
    def test_version_macos(self):
        code, out = shim_output("magpie", "--version")
        assert code == 0 and VERSION in out, out[:300]
        assert_xvm_registered("magpie")

    # Linux deliberately has no verify test: the desktop build links against
    # the host's GTK 3 / WebKitGTK 4.1, which a headless CI runner does not
    # have. Install is still exercised by the lifecycle test above; the
    # terminal build (magpie-cli) is the headless one that runs here.