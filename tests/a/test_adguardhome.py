"""AdGuard Home package checks; verification never starts DNS or a service."""
import os
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "adguardhome"
PKG_FILE = "pkgs/a/adguardhome.lua"
VERSION = "1.0.0"
REPO = Path(__file__).resolve().parents[2]


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
    def test_config_registers_package_name(self, meta):
        assert_config_registers_package_name(meta)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_portable_resources_and_autoupdate(self, meta):
        assert set(meta.platforms) == {"linux", "macosx", "windows"}
        assert meta.programs == ["AdGuardHome"]
        lua = shutil.which("lua5.4") or shutil.which("lua")
        if not lua:
            pytest.skip("Lua interpreter is unavailable")
        subprocess.run(
            [lua, "-", PKG_FILE, VERSION],
            input='''
import = function() end
dofile(arg[1])
local version = arg[2]
local auto = assert(package.extensions.autoupdate)
assert(auto.source == package.repo .. "/releases")
assert(auto.resources.GLOBAL.required == true)
assert(auto.resources.CN == nil)
for _, platform in ipairs({"linux", "macosx", "windows"}) do
    local section = assert(package.xpm[platform])
    assert(section.deps == nil)
    assert(section.latest.ref == version)
    local entry = assert(section[version])
    local count = 0
    for arch, hash in pairs(entry.sha256) do
        assert(arch == "x86_64" or arch == "aarch64")
        assert(#hash == 64 and hash:match("^%x+$"))
        local url = section.source:gsub("%${version}", version)
            :gsub("%${arch_alias}", assert(entry.arch_alias[arch]))
        local template = assert(auto.resources.GLOBAL.url[platform][arch])
        assert(template:gsub("%${tag}", "v" .. version) == url)
        count = count + 1
    end
    assert(count == 2)
end
''',
            text=True,
            capture_output=True,
            check=True,
            cwd=REPO,
        )


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
    def test_portable_hook_api_boundary(self, meta):
        assert set(meta.imports) <= {
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|os\.curdir\(|os\.execv\(|raise\()', meta.raw_content)


class TestIndex:
    @pytest.mark.index
    def test_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


@pytest.fixture
def program():
    suffix = ".exe" if os.name == "nt" else ""
    subos = Path(xlings_home()) / "subos"
    names = (os.environ.get("XLINGS_TEST_SUBOS", "current"), "default")
    for name in names:
        shim = subos / name / "bin" / ("AdGuardHome" + suffix)
        if shim.is_file():
            return shim
    pytest.fail(f"Missing case-preserving AdGuardHome shim under {subos}")


class TestVerify:
    @pytest.mark.verify
    def test_version_through_shim(self, program, tmp_path):
        result = subprocess.run(
            [str(program), "--version"], cwd=tmp_path,
            capture_output=True, text=True, timeout=15,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        version = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        assert f"AdGuard Home, version v{version}" in result.stdout + result.stderr
        assert not list(tmp_path.iterdir()), "Version query wrote unexpected state"

    @pytest.mark.verify
    @pytest.mark.parametrize("valid", [True, False])
    def test_offline_config_validation(self, program, tmp_path, valid):
        work = tmp_path / "work"
        work.mkdir()
        config = tmp_path / "AdGuardHome.yaml"
        # Check-only mode binds no sockets and makes no upstream DNS requests.
        # Even the explicit unused listener/upstream addresses are loopback and
        # unprivileged; all state is confined to this disposable directory.
        content = (
            "log:\n  enabled: true\n"
            "http:\n  address: 127.0.0.1:18080\n"
            "dns:\n  bind_hosts:\n    - 127.0.0.1\n  port: 15353\n"
            "  upstream_dns:\n    - 127.0.0.1:15354\n"
            "filters: []\nschema_version: 35\n"
            if valid else "dns: [\n"
        )
        config.write_text(content, encoding="utf-8")
        result = subprocess.run(
            [str(program), "--check-config", "--no-check-update",
             "--config", str(config), "--work-dir", str(work)],
            cwd=tmp_path, capture_output=True, text=True, timeout=20,
        )
        if valid:
            assert result.returncode == 0, result.stdout + result.stderr
            assert "configuration file is ok" in result.stdout + result.stderr
        else:
            assert result.returncode != 0, "Malformed YAML unexpectedly validated"
        assert config.read_text(encoding="utf-8") == content
        assert not list(work.iterdir()), "Check-only mode wrote working state"
        assert set(tmp_path.iterdir()) == {config, work}

    @pytest.mark.verify
    def test_program_registered(self):
        assert_xvm_registered("AdGuardHome")

    @pytest.mark.verify
    def test_package_group_registered(self):
        assert_xvm_registered(PKG)
