"""ChatGPT 包的资源边界和启动行为验证"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

import pytest

from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)
from tests.lib.xpkg_parser import parse_xpkg


ROOT = Path(__file__).resolve().parents[2]
RECIPE = ROOT / "pkgs/c/chatgpt.lua"


@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(str(RECIPE))
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)
    assert set(meta.platforms) == {"linux", "macosx"}


@pytest.mark.static
def test_resolved_resources():
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua is required to evaluate the resource matrix")
    code = r'''
import = function() end
dofile(arg[1])
assert(package.xpm.windows == nil)
for platform, entries in pairs(package.xpm) do
    assert(entries[entries.latest.ref])
    for version, resources in pairs(entries) do
        if version ~= "deps" and version ~= "latest" and version ~= "exports" then
            -- Linux: x86_64 only until glibc/gcc-runtime ship arm64 payloads;
            -- macOS: Apple silicon only
            assert((platform == "linux") == (resources.x86_64 ~= nil))
            assert((platform == "macosx") == (resources.aarch64 ~= nil))
            for arch, asset in pairs(resources) do
                -- `revision` sits beside the arch keys; it is not an asset
                if arch ~= "revision" then
                    assert(asset.url:match("^https://persistent%.oaistatic%.com/"))
                    assert(asset.url:find(version, 1, true))
                    assert(#asset.sha256 == 64 and asset.sha256:match("^[0-9a-f]+$"))
                end
            end
        end
    end
end
'''
    subprocess.run([lua, "-", str(RECIPE)], input=code, text=True, check=True)


@pytest.mark.static
def test_deps_split_build_from_runtime():
    """7-Zip only unpacks the deb, so it is a build dep and never on the user's
    PATH; the Qt packages were only for Chromium's optional Qt UI shims, which
    the payload no longer keeps."""
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua is required to evaluate the descriptor")
    code = r'''
import = function() end
dofile(arg[1])
local deps = package.xpm.linux.deps
-- the split form: a positional list next to `build` reads the same and is
-- dropped by clients older than libxpkg 0.0.52
assert(#deps == 0 and type(deps.runtime) == "table" and type(deps.build) == "table")
local function has(list, pattern)
    for _, d in ipairs(list) do if d:match(pattern) then return true end end
    return false
end
assert(has(deps.build, "^xim:7zip"), "7zip must be a build dep")
assert(not has(deps.runtime, "7zip"), "7zip must not be a runtime dep")
for _, list in ipairs({ deps.runtime, deps.build }) do
    assert(not has(list, "^xim:qt"), "the Qt packages only fed the removed UI shims")
end
assert(has(deps.runtime, "^xim:gtk3$"), "gtk3 is what replaces the Qt UI")
'''
    subprocess.run([lua, "-", str(RECIPE)], input=code, text=True, check=True)


@pytest.mark.isolation
def test_isolation():
    filename = str(RECIPE)
    assert_no_exec_xvm(filename)
    assert_no_bashrc_modification(filename)
    assert_no_direct_path_modification(filename)
    assert_uses_new_api(filename)
    text = RECIPE.read_text()
    assert all((module.startswith("xim.libxpkg.") or module == "xim.pkgindex.graphics") for module in re.findall(r'import\("([^"]+)"\)', text))
    assert not re.search(r"\b(?:apt install|dnf install|pacman -S)\b", text)
    assert not re.search(r"(?:system\.exec|os\.exec|io\.popen)\([^\n]*\bsudo\b", text)


@pytest.mark.index
def test_index_registration():
    assert_xim_add_succeeds(str(RECIPE))


@pytest.mark.static
@pytest.mark.parametrize("version", ["26.924.22138", "wrong-version"])
def test_deb_install_roundtrip(tmp_path, version):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    sevenzip = shutil.which("7zz") or shutil.which("7z")
    if not lua or not sevenzip or not shutil.which("ar"):
        pytest.skip("Lua, 7-Zip and ar are required for the archive roundtrip")
    stage = tmp_path / "input"
    app = stage / "usr/lib/chatgpt"
    (app / "resources").mkdir(parents=True)
    # a real dynamically linked x86_64 program stands in for the app, and a
    # minimal ELF with no PT_INTERP and no PT_DYNAMIC for a static helper
    host_true = Path("/bin/true").resolve()
    if host_true.read_bytes()[18:20] != b"\x3e\x00":                     # EM_X86_64
        pytest.skip("needs an x86_64 host program for the dynamic fixture")
    shutil.copy(host_true, app / "ChatGPT")
    (app / "ChatGPT").chmod(0o755)
    static = bytearray(64)
    static[0:4] = b"\x7fELF"; static[4] = 2; static[5] = 1; static[18:20] = b"\x3e\x00"
    (app / "resources").mkdir(exist_ok=True)
    (app / "libqt5_shim.so").write_bytes(b"shim")
    (app / "libqt6_shim.so").write_bytes(b"shim")
    (app / "resources/static-helper").write_bytes(bytes(static))
    (app / "resources/app.asar").write_bytes(b"fixture")
    (app / "resources/asar-link").symlink_to("app.asar")
    (app / "resources/linux-package-metadata.json").write_text(json.dumps({"version": version}))
    (stage / "usr/bin").mkdir()
    (stage / "usr/bin/chatgpt").symlink_to("../lib/chatgpt/codex-launcher")
    with tarfile.open(tmp_path / "data.tar.xz", "w:xz") as archive:
        archive.add(stage / "usr", arcname="./usr")
    (tmp_path / "debian-binary").write_text("2.0\n")
    (tmp_path / "control").write_text("Package: chatgpt\nVersion: " + version + "\nArchitecture: amd64\n")
    with tarfile.open(tmp_path / "control.tar.xz", "w:xz") as archive:
        archive.add(tmp_path / "control", arcname="./control")
    subprocess.run(["ar", "rc", "fixture.deb", "debian-binary", "control.tar.xz", "data.tar.xz"], cwd=tmp_path, check=True)
    dep = tmp_path / "dependency"
    dep.mkdir()
    (dep / "7zz").symlink_to(sevenzip)
    (dep / "lib64").mkdir()
    (dep / "lib64/ld-linux-x86-64.so.2").write_bytes(b"loader")
    target = tmp_path / "installed's folder"
    harness = r'''
local recipe, archive, target, dep = arg[1], arg[2], arg[3], arg[4]
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function run(s) assert(os.execute(s)) end
os.mkdir = function(p) run("mkdir -p " .. q(p)) end
os.mv = function(a,b) run("mv " .. q(a) .. " " .. q(b)) end
os.tryrm = function(p) run("rm -rf " .. q(p)) end
os.isfile = function(p) return os.execute("test -f " .. q(p)) == true end
pkginfo = {
    install_dir = function() return target end,
    install_file = function() return archive end,
    version = function() return "26.924.22138" end,
    -- 7-Zip is a build dep: the only way to it is build_dep, by its bare name
    build_dep = function(name)
        assert(name == "7zip", "asked for " .. tostring(name))
        return { path = dep }
    end,
    resolved_dep = function() return { install_dir = dep } end,
}
patched = {}
elfpatch = {
    skip = function() skipped = true end,
    closure_lib_paths = function() return { "/closure" } end,
    patch_elf_loader_rpath = function(file, opts)
        assert(opts.loader == dep .. "/lib64/ld-linux-x86-64.so.2")
        patched[#patched + 1] = file:match("[^/]+$")
    end,
}
system = { exec = run }
json = { loadfile = function(p)
    local f = assert(io.open(p)); local s = f:read("*a"); f:close()
    return { version = s:match('"version"%s*:%s*"([^"]+)"') }
end }
import = function() end
dofile(recipe)
assert(install())
assert(skipped, "auto-elfpatch must be switched off")
table.sort(patched)
print("PATCHED " .. table.concat(patched, ","))
'''
    result = subprocess.run([lua, "-", str(RECIPE), str(tmp_path / "fixture.deb"), str(target), str(dep)],
                            input=harness, capture_output=True, text=True)
    if version == "wrong-version":
        assert result.returncode != 0
        assert "archive version mismatch" in result.stderr
        assert not (target / "app/ChatGPT").exists()
    else:
        assert result.returncode == 0, result.stderr
        # the dynamic program is patched; the static helper is left as shipped
        assert "PATCHED ChatGPT\n" in result.stdout, result.stdout
        assert not (target / ".unpack").exists()
        # Chromium's optional Qt UI integration is not kept; nothing declares Qt
        assert not list((target / "app").glob("libqt*_shim.so"))
        assert (target / "app/resources/app.asar").read_bytes() == b"fixture"
        assert os.access(target / "app/ChatGPT", os.X_OK)
        assert (target / "app/resources/asar-link").is_symlink()
        assert (target / "app/resources/asar-link").read_bytes() == b"fixture"
        profile = (target / "share/apparmor/xlings-chatgpt").read_text()
        assert f'"{target}/app/ChatGPT" flags=(unconfined)' in profile and "userns," in profile
        assert "profile xlings-chatgpt-26.924.22138 " in profile
        check_launcher(tmp_path, target)


def check_launcher(tmp_path, target):
    """bin/chatgpt runs the app unless the host's sandbox provably cannot start"""
    launcher = target / "bin/chatgpt"
    assert os.access(launcher, os.X_OK)
    subprocess.run(["sh", "-n", str(launcher)], check=True)
    # the same script against fixture copies of the two kernel interfaces
    host = tmp_path / "host"
    (host / "profiles/other.3").mkdir(parents=True)
    (host / "profiles/other.3/name").write_text("other\n")
    text = launcher.read_text()
    assert text.count("/proc/sys/kernel/apparmor_restrict_unprivileged_userns") == 1
    assert text.count("/sys/kernel/security/apparmor/policy/profiles/") == 1
    probe = tmp_path / "probe"
    probe.write_text(text
        .replace("/proc/sys/kernel/apparmor_restrict_unprivileged_userns", str(host / "restrict"))
        .replace("/sys/kernel/security/apparmor/policy/profiles/", str(host / "profiles") + "/"))

    def run(restrict, *args):
        (host / "restrict").write_text(restrict)
        return subprocess.run(["sh", str(probe), *args], capture_output=True, text=True)

    assert run("0\n").returncode == 0                     # unrestricted: the app runs
    blocked = run("1\n")                                  # restricted, profile not loaded
    assert blocked.returncode == 1
    # both ways out, each as commands that run as printed, and what the profile grants
    assert f"sudo install -m 0644 '{target}/share/apparmor/xlings-chatgpt' /etc/apparmor.d/xlings-chatgpt-26.924.22138\n" in blocked.stderr
    assert "sudo apparmor_parser -r /etc/apparmor.d/xlings-chatgpt-26.924.22138\n" in blocked.stderr
    assert "chatgpt --no-sandbox\n" in blocked.stderr
    assert f'| profile xlings-chatgpt-26.924.22138 "{target}/app/ChatGPT" flags=(unconfined) {{' in blocked.stderr
    assert "|   userns," in blocked.stderr
    assert run("1\n", "--no-sandbox").returncode == 0     # the user's own choice
    (host / "profiles/xlings-chatgpt-26.924.22138.9").mkdir()
    (host / "profiles/xlings-chatgpt-26.924.22138.9/name").write_text("xlings-chatgpt-26.924.22138\n")
    assert run("1\n").returncode == 0                     # profile loaded
    # the app is started in two places, both with exactly the user's arguments
    assert re.findall(r"exec .*", text) == ['exec "$app/ChatGPT" "$@" ;; esac', 'exec "$app/ChatGPT" "$@"']


@pytest.mark.static
@pytest.mark.parametrize("macos", [False, True])
def test_direct_xvm_registration(tmp_path, macos):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        pytest.skip("Lua is required")
    root = tmp_path / "version's directory with spaces"
    bindir, alias = ("ChatGPT.app/Contents/MacOS", "ChatGPT") if macos else ("bin", "chatgpt")
    bindir = root / bindir
    bindir.mkdir(parents=True)
    (bindir / alias).touch()
    code = r'''
import = function() end
os.isfile = function(p) local f=io.open(p); if f then f:close(); return true end; return false end
pkginfo = { install_dir = function() return arg[2] end,
    version = function() return "26.924.22138" end }
graphics = { consumer_envs = function() return {} end }
xvm = { add = function(name, node)
    assert(name == "chatgpt")
    assert(node.bindir == arg[3])
    assert(node.alias == arg[4])
    assert(node.envs.CODEX_SPARKLE_ENABLED == "false")
    -- schemas come through XDG_DATA_DIRS (<subos>/share), never a payload path
    assert(node.envs.GSETTINGS_SCHEMA_DIR == nil)
end }
dofile(arg[1])
assert(config())
'''
    subprocess.run([lua, "-", str(RECIPE), str(root), str(bindir), alias],
                   input=code, text=True, check=True)


@pytest.mark.verify
def test_installed_linux_native_modules():
    """使用配方写入的加载器检查当前架构模块，禁止宿主库兜底"""
    import platform
    if platform.system() != "Linux":
        pytest.skip("Linux runtime check")
    home = Path(os.environ.get("XLINGS_HOME", str(Path.home() / ".xlings"))).resolve()
    apps = list((home / "data/xpkgs").glob("*-x-chatgpt/*/app/ChatGPT"))
    if not apps:
        pytest.skip("Install ChatGPT before the runtime verification")
    machine = {"x86_64": 62, "aarch64": 183}.get(platform.machine())
    for executable in apps:
        headers = subprocess.check_output(["readelf", "-l", str(executable)], text=True)
        loader = re.search(r"Requesting program interpreter: (.+?)\]", headers).group(1)
        assert loader.startswith(str(home) + "/data/xpkgs/")
        targets = [executable]
        for native in executable.parent.rglob("*.node"):
            if "musl" in str(native) or "android" in str(native):
                continue
            with native.open("rb") as stream:
                header = stream.read(20)
            if header[:4] == b"\x7fELF" and int.from_bytes(header[18:20], "little") == machine:
                targets.append(native)
        for target in targets:
            result = subprocess.run([loader, "--list", str(target)], capture_output=True, text=True)
            assert result.returncode == 0, f"{target}: {result.stderr}"
            for resolved in re.findall(r"=> (/\S+)", result.stdout):
                assert resolved.startswith(str(home) + "/"), f"Host library: {resolved}"
