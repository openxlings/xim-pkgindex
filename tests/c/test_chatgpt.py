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
        if version ~= "deps" and version ~= "latest" then
            assert(resources.aarch64)
            assert((platform == "linux") == (resources.x86_64 ~= nil))
            for arch, asset in pairs(resources) do
                assert(asset.url:match("^https://persistent%.oaistatic%.com/"))
                assert(asset.url:find(version, 1, true))
                assert(#asset.sha256 == 64 and asset.sha256:match("^[0-9a-f]+$"))
            end
        end
    end
end
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
    assert all(module.startswith("xim.libxpkg.") for module in re.findall(r'import\("([^"]+)"\)', text))
    assert not re.search(r"\b(?:sudo|apt install|dnf install|pacman -S|--no-sandbox)\b", text)


@pytest.mark.index
def test_index_registration():
    assert_xim_add_succeeds(str(RECIPE))


@pytest.fixture
def launcher(tmp_path):
    root = tmp_path / "version's directory with spaces"
    (root / "bin").mkdir(parents=True)
    (root / "app/resources").mkdir(parents=True)
    (root / "package-version").write_text("26.924.22138\n")
    (root / "app/resources/linux-package-metadata.json").write_text(
        json.dumps({"version": "26.924.22138"}))
    program = root / "app/ChatGPT"
    program.write_text('#!/bin/sh\nprintf "%s\\n" "$CODEX_SPARKLE_ENABLED" "$@"\n')
    program.chmod(0o755)
    script = re.search(r"local launcher = \[=\[(.*?)\]=\]", RECIPE.read_text(), re.S).group(1)
    command = root / "bin/chatgpt"
    command.write_text(script)
    command.chmod(0o755)
    return command, root


@pytest.mark.static
def test_version_does_not_start_app(launcher):
    command, root = launcher
    (root / "app/ChatGPT").unlink()
    result = subprocess.run([command, "--version"], capture_output=True, text=True)
    assert result.returncode == 0
    assert result.stdout == "ChatGPT 26.924.22138\n"


@pytest.mark.static
def test_launch_preserves_arguments_and_disables_updater(launcher):
    command, _ = launcher
    result = subprocess.run([command, "space in argument", "", "codex://example"],
                            env={**os.environ, "CODEX_SPARKLE_ENABLED": "true"},
                            capture_output=True, text=True)
    assert result.returncode == 0
    assert result.stdout == "false\nspace in argument\n\ncodex://example\n"


@pytest.mark.static
def test_changed_payload_is_rejected(launcher):
    command, root = launcher
    (root / "app/resources/linux-package-metadata.json").write_text('{"version":"different"}')
    result = subprocess.run([command], capture_output=True, text=True)
    assert result.returncode != 0
    assert "version mismatch" in result.stderr
    assert not result.stdout


@pytest.mark.static
def test_missing_library_fails_diagnostic(launcher, tmp_path):
    command, root = launcher
    (root / "app/native.node").write_bytes(b"\x7fELFtest")
    tools = tmp_path / "tools"
    tools.mkdir()
    for name, script in {
        "getconf": "echo 'glibc 2.39'",
        "ldd": "echo 'libexample.so => not found'",
    }.items():
        p = tools / name
        p.write_text("#!/bin/sh\n" + script + "\n")
        p.chmod(0o755)
    command.write_text(command.read_text().replace("/usr/bin/getconf", str(tools / "getconf")).replace("/usr/bin/ldd", str(tools / "ldd")))
    result = subprocess.run([command, "--check-deps"], capture_output=True, text=True,
                            env={**os.environ, "PATH": str(tools) + os.pathsep + os.environ["PATH"]})
    assert result.returncode != 0
    assert "native.node" in result.stderr
    assert "libexample.so => not found" in result.stderr


@pytest.mark.static
def test_dependency_check_ignores_path_shims(launcher, tmp_path):
    if not Path("/usr/bin/ldd").exists() or not Path("/usr/bin/getconf").exists():
        pytest.skip("Host glibc tools are required")
    command, root = launcher
    shutil.copy2("/usr/bin/true", root / "app/native")
    tools = tmp_path / "shims"
    tools.mkdir()
    for name in ("ldd", "getconf"):
        shim = tools / name
        shim.write_text("#!/bin/sh\necho 'incorrect shim' >&2\nexit 1\n")
        shim.chmod(0o755)
    result = subprocess.run([command, "--check-deps"], capture_output=True, text=True,
                            env={**os.environ, "PATH": str(tools) + os.pathsep + os.environ["PATH"]})
    assert result.returncode == 0, result.stderr
    assert "incorrect shim" not in result.stderr
    assert "ELF library check passed" in result.stdout


@pytest.mark.static
def test_musl_is_rejected(launcher, tmp_path):
    command, _ = launcher
    tools = tmp_path / "tools"
    tools.mkdir()
    getconf = tools / "getconf"
    getconf.write_text("#!/bin/sh\nexit 1\n")
    getconf.chmod(0o755)
    command.write_text(command.read_text().replace("/usr/bin/getconf", str(tools / "getconf")).replace("/usr/bin/ldd", str(tools / "ldd")))
    result = subprocess.run([command, "--check-deps"], capture_output=True, text=True,
                            env={**os.environ, "PATH": str(tools) + os.pathsep + os.environ["PATH"]})
    assert result.returncode != 0
    assert "musl is unsupported" in result.stderr


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
    (app / "ChatGPT").write_text("#!/bin/sh\nexit 0\n")
    (app / "ChatGPT").chmod(0o755)
    (app / "resources/app.asar").write_bytes(b"fixture")
    (app / "resources/linux-package-metadata.json").write_text(json.dumps({"version": version}))
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
    dep_install_dir = function() return dep end,
}
system = { exec = run }
json = { loadfile = function(p)
    local f = assert(io.open(p)); local s = f:read("*a"); f:close()
    return { version = s:match('"version"%s*:%s*"([^"]+)"') }
end }
import = function() end
dofile(recipe)
assert(install())
'''
    result = subprocess.run([lua, "-", str(RECIPE), str(tmp_path / "fixture.deb"), str(target), str(dep)],
                            input=harness, capture_output=True, text=True)
    if version == "wrong-version":
        assert result.returncode != 0
        assert "archive version mismatch" in result.stderr
        assert not (target / "bin/chatgpt").exists()
    else:
        assert result.returncode == 0, result.stderr
        assert not (target / ".unpack").exists()
        assert (target / "app/resources/app.asar").read_bytes() == b"fixture"
        output = subprocess.check_output([target / "bin/chatgpt", "--version"], text=True)
        assert output == "ChatGPT 26.924.22138\n"
