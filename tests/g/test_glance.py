"""L0-L4 coverage for Glance's six native release archives and offline dashboard."""
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import time
from urllib.error import URLError
from urllib.request import ProxyHandler, build_opener

import pytest

from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_platform_supported,
    assert_valid_xvm_node_kinds,
    assert_no_exec_xvm,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds,
    assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "glance"
PKG_FILE = "pkgs/g/glance.lua"
ROOT = Path(__file__).resolve().parents[2]


def _glance_bin():
    suffix = ".exe" if os.name == "nt" else ""
    base = Path(xlings_home()) / "subos"
    names = [os.environ["XLINGS_TEST_SUBOS"]] if os.environ.get("XLINGS_TEST_SUBOS") else ["current", "default"]
    for name in names:
        shim = base / name / "bin" / (PKG + suffix)
        if shim.is_file():
            return str(shim)
    pytest.fail(f"Missing installed Glance shim under {base}")


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert meta.spec == "2"
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)
        assert_valid_xvm_node_kinds(meta)
        for platform in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, platform)

    @pytest.mark.static
    def test_resource_and_updater_matrix(self):
        lua = shutil.which("lua5.4") or shutil.which("lua")
        if not lua:
            pytest.skip("Lua interpreter is unavailable")
        script = r'''
function import() end
assert(loadfile(arg[1]))()
assert(package.name == "glance" and package.xvm_enable)
assert(package.ci and package.ci.mirror == true)
assert(#package.programs == 1 and package.programs[1] == "glance")
assert(#package.archs == 2 and package.archs[1] == "x86_64" and package.archs[2] == "aarch64")
local auto = assert(package.extensions.autoupdate)
assert(auto.source == "https://github.com/glanceapp/glance/releases")
assert(auto.resources.CN == nil, "no unverified regional mirror")
assert(auto.resources.GLOBAL.required == true)
local platforms = { linux = "linux", macosx = "darwin", windows = "windows" }
local arches = { x86_64 = "amd64", aarch64 = "arm64" }
local count = 0
for platform, upstream_os in pairs(platforms) do
    local p = assert(package.xpm[platform])
    assert(p.deps == nil, "static Go payload needs no runtime package")
    assert(p.latest.ref == "0.8.8")
    local entry = assert(p[p.latest.ref])
    for arch, alias in pairs(arches) do
        assert(entry.arch_alias[arch] == alias)
        local digest = assert(entry.sha256[arch])
        assert(#digest == 64 and digest:match("^[0-9a-f]+$"))
        local ext = platform == "windows" and "zip" or "tar.gz"
        local expected = "https://github.com/glanceapp/glance/releases/download/v0.8.8/glance-"
            .. upstream_os .. "-" .. alias .. "." .. ext
        local resource = p.source:gsub("%${version}", "0.8.8"):gsub("%${arch_alias}", alias)
        local updater = assert(auto.resources.GLOBAL.url[platform][arch]):gsub("%${tag}", "v0.8.8")
        assert(resource == expected and updater == expected, platform .. "/" .. arch)
        count = count + 1
    end
    for arch in pairs(entry.sha256) do assert(arches[arch]) end
end
assert(count == 6)
'''
        subprocess.run(
            [lua, "-", PKG_FILE], input=script, text=True,
            capture_output=True, check=True, cwd=ROOT,
        )

    @pytest.mark.static
    def test_flat_archive_assertions(self):
        source = (ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert 'payload.unpack{}' in source  # Windows zip: no wrapper to strip.
        assert 'shell.exec({ "tar", "-xzf", normalized, "-C", dir })' in source
        assert 'payload.require({ is_win and "glance.exe" or "glance" })' in source
        assert 'payload.present({ "glance" })' in source
        assert 'payload.present({ "glance.exe" })' in source


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_policies(self):
        assert_no_exec_xvm(PKG_FILE)
        assert_no_bashrc_modification(PKG_FILE)
        assert_no_direct_path_modification(PKG_FILE)
        assert_uses_new_api(PKG_FILE)
        assert_no_direct_pkg_manager(PKG_FILE)

    @pytest.mark.isolation
    def test_portable_hooks_without_service_or_config_writes(self):
        source = (ROOT / PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', source)) == {
            "xim.libxpkg.fs", "xim.libxpkg.pkginfo", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|try\s*\{|raise\()', source)
        hooks = source[source.index('function installed()'):]
        assert not re.search(r'(?i)systemctl|launchctl|sc\.exe|writefile|io\.open|os\.setenv|os\.addenv', hooks)
        assert 'xvm.add("glance", { bindir = pkginfo.install_dir() })' in hooks
        assert 'xvm.remove("glance")' in hooks


class TestIndex:
    @pytest.mark.index
    def test_register_recipe(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=90)


class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        result = subprocess.run([_glance_bin(), "--version"], capture_output=True, text=True, check=True, timeout=10)
        assert result.stdout.strip().removeprefix("v") == os.environ.get("XLINGS_TEST_VERSION", "0.8.8")

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            base = Path(xlings_home()) / "subos"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", "current" if (base / "current").is_dir() else "default")
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    def test_offline_dashboard(self, tmp_path):
        # Only an inline HTML widget: no external feeds, images, APIs or fixed port.
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        config = tmp_path / "glance.yml"
        config.write_text(
            f"server:\n  host: 127.0.0.1\n  port: {port}\n"
            "pages:\n  - name: Offline\n    columns:\n      - size: full\n"
            "        widgets:\n          - type: html\n"
            "            source: '<h1>Glance offline acceptance</h1>'\n",
            encoding="utf-8",
        )
        binary = _glance_bin()
        subprocess.run([binary, "--config", str(config), "config:validate"], capture_output=True, text=True, check=True, timeout=10)
        opener = build_opener(ProxyHandler({}))
        with (tmp_path / "glance.log").open("w+", encoding="utf-8") as log:
            process = subprocess.Popen(
                [binary, "--config", str(config)], cwd=tmp_path,
                stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
            )
            try:
                deadline = time.monotonic() + 10
                while True:
                    assert process.poll() is None, "Glance exited before serving the dashboard"
                    try:
                        with opener.open(f"http://127.0.0.1:{port}/", timeout=1) as response:
                            assert response.status == 200
                            assert "Offline" in response.read().decode("utf-8")
                        break
                    except URLError:
                        if time.monotonic() >= deadline:
                            pytest.fail("Glance did not serve its loopback dashboard within 10s")
                        time.sleep(0.05)
                with opener.open(f"http://127.0.0.1:{port}/api/pages/offline/content/", timeout=2) as response:
                    assert response.status == 200
                    assert "<h1>Glance offline acceptance</h1>" in response.read().decode("utf-8")
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                log.seek(0)
                print(log.read())
