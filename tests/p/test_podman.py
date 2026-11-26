"""Tests for the podman package."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tomllib

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields,
    assert_valid_spec,
    assert_valid_type,
    assert_no_typos,
    assert_config_registers_package_name,
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
from tests.lib.platform_utils import skip_if_not, under_test, xlings_home

PKG = "podman"
PKG_FILE = "pkgs/p/podman.lua"
VERSION = "6.2.1"
REPO = Path(__file__).resolve().parents[2]


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args],
        input=script,
        text=True,
        capture_output=True,
        check=True,
        cwd=REPO,
    ).stdout


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
    def test_platforms_sha256_and_autoupdate(self, meta):
        assert set(meta.platforms.keys()) == {"linux", "macosx", "windows"}
        _run_lua('''
import = function() end
dofile(arg[1])
local ver = arg[2]
assert(package.spec == "2")
assert(package.xvm_enable == true)
assert(package.ci and package.ci.mirror == true)
assert(package.programs and package.programs[1] == "podman" and #package.programs == 1)

local auto = assert(package.extensions and package.extensions.autoupdate)
assert(auto.source == "https://github.com/podman-container-tools/podman/releases")
assert(auto.resources and auto.resources.GLOBAL and auto.resources.GLOBAL.required == true)

local expected = {
    linux = { x86_64 = "amd64", aarch64 = "arm64" },
    macosx = { aarch64 = "arm64" },
    windows = { x86_64 = "amd64", aarch64 = "arm64" },
}

local count = 0
for plat, aliases in pairs(expected) do
    local p = assert(package.xpm[plat], "missing platform: " .. plat)
    assert(p.deps == nil, plat .. " uses self-contained static/stdlib binaries and needs no deps")
    assert(type(p.source) == "string")
    assert(p.latest and p.latest.ref == ver, plat .. " latest must ref " .. ver)
    local v = assert(p[ver], "missing version entry on " .. plat)
    assert(type(v.sha256) == "table", plat .. " must declare per-arch sha256 table")
    assert(type(v.arch_alias) == "table", plat .. " must declare arch_alias table")
    for arch, alias in pairs(aliases) do
        assert(v.arch_alias[arch] == alias, "arch_alias mismatch for " .. plat .. "/" .. arch)
        local digest = assert(v.sha256[arch], "missing sha256 for " .. plat .. "/" .. arch)
        assert(type(digest) == "string" and #digest == 64 and digest:match("^%x+$"))
        local xpm_url = p.source:gsub("%${version}", ver):gsub("%${arch_alias}", alias)
        local auto_url = assert(auto.resources.GLOBAL.url[plat][arch])
        local resolved = auto_url:gsub("%${tag}", "v" .. ver):gsub("%${version}", ver)
        assert(resolved == xpm_url, "autoupdate URL disagrees for " .. plat .. "/" .. arch)
        count = count + 1
    end
    for k in pairs(v.sha256) do
        assert(aliases[k], "unexpected arch in sha256: " .. plat .. "/" .. k)
    end
end
assert(count == 5)
''', PKG_FILE, VERSION)

    @pytest.mark.static
    def test_hooks_linux_macos_windows_sandbox(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            linux_dir = root / "linux_install"
            (linux_dir / "etc" / "containers").mkdir(parents=True)
            out = _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()
shell = assert(loadfile("libs/shell.lua"))()
dofile(arg[1])

local linux_install_dir = arg[2]
local ver = arg[3]

local linux_rel = {
    "usr/local/bin/podman",
    "usr/local/bin/crun",
    "usr/local/bin/runc",
    "usr/local/bin/fuse-overlayfs",
    "usr/local/bin/fusermount3",
    "usr/local/bin/passt",
    "usr/local/bin/pasta",
    "usr/local/lib/podman/conmon",
    "usr/local/lib/podman/netavark",
    "usr/local/lib/podman/aardvark-dns",
    "usr/local/lib/podman/catatonit",
    "usr/local/lib/podman/rootlessport",
    "usr/local/libexec/podman/quadlet",
    "etc/containers/policy.json",
    "etc/containers/registries.conf",
    "etc/containers/seccomp.json",
}

-- Case 1: Linux static stack (moves podman-linux-amd64, writes xlings-containers.conf)
local files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
local host = "linux"
local install_file = "/cache/podman-linux-amd64.tar.gz"
local install_dir = linux_install_dir
dirs["/cache/podman-linux-amd64"] = true
os.host = function() return host end
os.getenv = function() return nil end
os.isfile = function(p)
    if files[p] then return true end
    local f = io.open(p, "rb")
    if f then f:close() return true end
    return false
end
os.isdir = function(p) return dirs[p] == true end
os.tryrm = function(p)
    dirs[p] = nil
    for k in pairs(files) do
        if k:sub(1, #p + 1) == p .. "/" then files[k] = nil end
    end
end
os.mv = function(src, dst)
    dirs[src] = nil
    dirs[dst] = true
    for _, rel in ipairs(linux_rel) do
        files[dst .. "/" .. rel] = true
    end
end
fs = { mkdir_p = function(p) dirs[p] = true end }
log = { info = function() end }
system = { exec = function(cmd) table.insert(execs, cmd) end }
pkginfo = {
    name = function() return "podman" end,
    version = function() return ver end,
    install_file = function() return install_file end,
    install_dir = function() return install_dir end,
}
xvm = {
    add = function(name, opts) table.insert(adds, {name, opts}) end,
    remove = function(name) table.insert(rms, name) end,
}

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 0)
assert(config())
assert(#adds == 1)
assert(adds[1][1] == "podman")
assert(adds[1][2].bindir == linux_install_dir .. "/usr/local/bin")
assert(adds[1][2].envs.CONTAINERS_CONF == linux_install_dir .. "/etc/containers/xlings-containers.conf")
assert(adds[1][2].envs.CONTAINERS_POLICY_JSON == linux_install_dir .. "/etc/containers/policy.json")
assert(adds[1][2].envs.CONTAINERS_REGISTRIES_CONF == linux_install_dir .. "/etc/containers/registries.conf")
assert(uninstall())
assert(#rms == 1 and rms[1] == "podman")

-- Case 2: macOS arm64 (pre-extracted podman-<ver>/ directory)
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
host = "macosx"
install_file = "/cache/podman-remote-release-darwin_arm64.zip"
install_dir = "/xpkgs/podman/" .. ver
dirs["/cache/podman-" .. ver] = true
os.mv = function(src, dst)
    dirs[src] = nil
    dirs[dst] = true
    files[dst .. "/usr/bin/podman"] = true
    files[dst .. "/usr/bin/podman-mac-helper"] = true
end

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == "'chmod' '+x' '/xpkgs/podman/" .. ver .. "/usr/bin/podman' '/xpkgs/podman/" .. ver .. "/usr/bin/podman-mac-helper'")
assert(config())
assert(#adds == 1 and adds[1][1] == "podman" and adds[1][2].bindir == "/xpkgs/podman/" .. ver .. "/usr/bin")
assert(adds[1][2].envs == nil)
assert(uninstall())
assert(#rms == 1 and rms[1] == "podman")

-- Case 3: Windows zip unpacked via System32\\tar.exe with --strip-components=1
files, dirs, execs, adds, rms = {}, {}, {}, {}, {}
host = "windows"
install_file = "C:/cache/podman-remote-release-windows_amd64.zip"
install_dir = "C:/xpkgs/podman/" .. ver
os.getenv = function(k)
    if k == "SystemRoot" then return "C:\\\\Windows" end
    if k == "OS" then return "Windows_NT" end
    return nil
end
system.exec = function(cmd)
    table.insert(execs, cmd)
    files[install_dir .. "/usr/bin/podman.exe"] = true
    files[install_dir .. "/usr/bin/gvproxy.exe"] = true
    files[install_dir .. "/usr/bin/win-sshproxy.exe"] = true
end

assert(not installed())
assert(install())
assert(installed())
assert(#execs == 1)
assert(execs[1] == 'C:\\\\Windows\\\\System32\\\\tar.exe -xf "C:\\\\cache\\\\podman-remote-release-windows_amd64.zip" --strip-components=1 -C "C:\\\\xpkgs\\\\podman\\\\' .. ver .. '"')
assert(config())
assert(#adds == 1 and adds[1][1] == "podman" and adds[1][2].bindir == "C:/xpkgs/podman/" .. ver .. "/usr/bin")
assert(adds[1][2].envs == nil)
assert(uninstall())
assert(#rms == 1 and rms[1] == "podman")
print("SANDBOX_OK")
''', PKG_FILE, str(linux_dir), VERSION)
            assert "SANDBOX_OK" in out
            conf_file = linux_dir / "etc" / "containers" / "xlings-containers.conf"
            parsed = tomllib.loads(conf_file.read_text(encoding="utf-8"))
            assert parsed["containers"]["seccomp_profile"] == f"{linux_dir}/etc/containers/seccomp.json"
            assert parsed["containers"]["init_path"] == f"{linux_dir}/usr/local/lib/podman/catatonit"
            assert parsed["engine"]["runtime"] == "crun"
            assert parsed["engine"]["cgroup_manager"] == "cgroupfs"
            assert parsed["engine"]["events_logger"] == "file"
            assert parsed["engine"]["conmon_path"] == [f"{linux_dir}/usr/local/lib/podman/conmon"]
            assert parsed["engine"]["runtimes"]["crun"] == [f"{linux_dir}/usr/local/bin/crun"]
            assert parsed["engine"]["runtimes"]["runc"] == [f"{linux_dir}/usr/local/bin/runc"]
            assert parsed["network"]["network_backend"] == "netavark"
            assert parsed["network"]["default_rootless_network_cmd"] == "pasta"


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
    def test_portable_lua_and_libxpkg_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.pkginfo",
            "xim.libxpkg.xvm",
            "xim.pkgindex.payload",
            "xim.pkgindex.shell",
        }
        assert not re.search(r'\b(?:path\.|is_host\(|os\.host\(|raise\()', src)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=180)


class TestVerify:
    def _shim(self, prog: str = "podman") -> Path:
        suffix = ".exe" if os.name == "nt" else ""
        subos_dir = Path(xlings_home()) / "subos"
        subos = os.environ.get("XLINGS_TEST_SUBOS")
        if not subos:
            subos = "current" if (subos_dir / "current" / ".xlings.json").is_file() else "default"
        shim = subos_dir / subos / "bin" / (prog + suffix)
        assert shim.is_file(), f"Missing installed shim: {shim}"
        return shim

    def _run_podman(self, *args: str) -> subprocess.CompletedProcess:
        shim = self._shim("podman")
        return subprocess.run(
            [str(shim), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )

    @pytest.mark.verify
    def test_podman_version(self):
        expected = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        r = self._run_podman("--version")
        out = r.stdout + r.stderr
        assert r.returncode == 0, out
        assert expected in out, f"podman --version: {out!r}"

    @pytest.mark.verify
    def test_podman_help_and_completion(self):
        r_help = self._run_podman("--help")
        out_help = r_help.stdout + r_help.stderr
        assert r_help.returncode == 0, out_help
        assert "podman" in out_help.lower(), out_help

        r_comp = self._run_podman("completion", "bash")
        out_comp = r_comp.stdout + r_comp.stderr
        assert r_comp.returncode == 0, out_comp
        assert "podman" in out_comp, out_comp[:200]

    @pytest.mark.verify
    def test_xvm_registered(self, monkeypatch):
        if not os.environ.get("XLINGS_TEST_SUBOS"):
            subos_dir = Path(xlings_home()) / "subos"
            subos = "current" if (subos_dir / "current" / ".xlings.json").is_file() else "default"
            monkeypatch.setenv("XLINGS_TEST_SUBOS", subos)
        assert_xvm_registered("podman")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_linux_relocatable_config_and_helpers(self):
        expected_ver = os.environ.get("XLINGS_TEST_VERSION", VERSION)
        xpkgs = Path(xlings_home()) / "data" / "xpkgs"
        install_dirs = sorted(xpkgs.glob(f"*-x-{PKG}/{expected_ver}"))
        assert install_dirs, f"No installed payload dir found under {xpkgs}"
        root = install_dirs[0]

        conf_path = root / "etc" / "containers" / "xlings-containers.conf"
        assert conf_path.is_file(), f"Missing generated config: {conf_path}"
        conf = tomllib.loads(conf_path.read_text(encoding="utf-8"))
        assert Path(conf["containers"]["seccomp_profile"]).is_file()
        assert Path(conf["containers"]["init_path"]).is_file()
        assert Path(conf["engine"]["conmon_path"][0]).is_file()
        assert Path(conf["engine"]["runtimes"]["crun"][0]).is_file()
        assert Path(conf["engine"]["runtimes"]["runc"][0]).is_file()
        for helper_dir in conf["engine"]["helper_binaries_dir"]:
            assert Path(helper_dir).is_dir(), f"Missing helper dir: {helper_dir}"

        helper_checks = [
            (root / "usr/local/bin/crun", ["--version"], "crun"),
            (root / "usr/local/bin/runc", ["--version"], "runc"),
            (root / "usr/local/lib/podman/conmon", ["--version"], "conmon"),
            (root / "usr/local/lib/podman/netavark", ["--version"], "netavark"),
            (root / "usr/local/lib/podman/aardvark-dns", ["--version"], "aardvark-dns"),
            (root / "usr/local/bin/pasta", ["--version"], "pasta"),
            (root / "usr/local/bin/fuse-overlayfs", ["--version"], "fuse-overlayfs"),
            (root / "usr/local/lib/podman/catatonit", ["--version"], "catatonit"),
            (root / "usr/local/libexec/podman/quadlet", ["-version"], expected_ver),
        ]
        for binary, argv, needle in helper_checks:
            r = subprocess.run([str(binary), *argv], capture_output=True, text=True, timeout=15)
            out = r.stdout + r.stderr
            assert r.returncode == 0, f"{binary} failed: {out}"
            assert needle in out, f"{binary} output missing {needle!r}: {out!r}"

        # Exercise `podman info` when unprivileged user namespaces are allowed on the host.
        # Ubuntu 24.04 runners with AppArmor userns restriction may refuse reexec for binaries
        # outside /usr/bin; fail loudly on any other error.
        with tempfile.TemporaryDirectory() as tmp_run:
            env = {
                **os.environ,
                "XDG_RUNTIME_DIR": tmp_run,
                "XDG_DATA_HOME": str(Path(tmp_run) / "data"),
                "XDG_CONFIG_HOME": str(Path(tmp_run) / "config"),
            }
            r_info = subprocess.run(
                [str(self._shim("podman")), "info", "--format",
                 "{{.Host.OCIRuntime.Path}}|{{.Host.Conmon.Path}}|{{.Host.NetworkBackendInfo.Path}}|{{.Host.Pasta.Executable}}"],
                capture_output=True, text=True, env=env, timeout=30,
            )
            out_info = r_info.stdout + r_info.stderr
            if r_info.returncode == 0:
                assert str(root / "usr/local/bin/crun") in out_info, out_info
                assert str(root / "usr/local/lib/podman/conmon") in out_info, out_info
                assert str(root / "usr/local/lib/podman/netavark") in out_info, out_info
                assert str(root / "usr/local/bin/pasta") in out_info, out_info
            else:
                userns_restricted = any(
                    marker in out_info.lower()
                    for marker in ("permission denied", "operation not permitted", "newuidmap", "user namespace")
                )
                assert userns_restricted, f"podman info failed unexpectedly: {out_info}"
