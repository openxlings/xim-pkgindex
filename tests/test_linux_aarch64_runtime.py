"""Native runtime layouts preserve x86 paths and register the ARM64 loader."""
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
pytestmark = pytest.mark.static


@pytest.mark.parametrize("arch,libdir,loader", [
    ("x86_64", "lib64", "ld-linux-x86-64.so.2"),
    ("aarch64", "lib", "ld-linux-aarch64.so.1"),
])
def test_glibc_payload_drives_registration_and_removal(arch, libdir, loader):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua, "Lua is required for runtime layout tests"
    result = subprocess.run([
        lua, str(ROOT / "tests/lua/linux_runtime_layout_harness.lua"),
        str(ROOT / "pkgs/g/glibc.lua"),
        f"glibc-2.44.3-r1-linux-{arch}.tar.gz", "/isolated/glibc",
    ], check=True, text=True, capture_output=True)
    lines = result.stdout.splitlines()
    assert f"{loader} /isolated/glibc/{libdir}" in lines
    assert f"libc.so.6 /isolated/glibc/{libdir}" in lines
    assert f"REMOVE {loader}" in lines
    other = "ld-linux-aarch64.so.1" if arch == "x86_64" else "ld-linux-x86-64.so.2"
    assert not any(other in line for line in lines if not line.startswith("EXPORT "))


def test_carve_rejects_foreign_elf_before_publishing(tmp_path):
    """A foreign tools archive must fail before any artifact is emitted."""
    if not shutil.which("patchelf") or not shutil.which("readelf"):
        pytest.skip("ELF carve validation requires patchelf and readelf")
    source = tmp_path / "upstream"
    (source / "bin").mkdir(parents=True)
    headers = source / "lib/clang/23/include"
    headers.mkdir(parents=True)
    (headers / "stddef.h").write_text("/* fixture */\n")
    # A minimal ELF64 header with EM_X86_64; no execution is involved.
    header = bytearray(64)
    header[:7] = b"\x7fELF\x02\x01\x01"
    header[16:20] = b"\x03\x00\x3e\x00"
    header[20:24] = b"\x01\x00\x00\x00"
    header[52:54] = b"\x40\x00"
    for name in ("clang-format", "clang-tidy", "clangd"):
        (source / "bin" / name).write_bytes(header)
    output = tmp_path / "out"
    result = subprocess.run([
        "bash", str(ROOT / ".agents/tools/build-llvm-subpkg.sh"),
        "--in", str(source), "--pkg", "tools", "--version", "23.1.3",
        "--platform", "linux", "--arch", "aarch64", "--out", str(output),
    ], capture_output=True, text=True)
    assert result.returncode != 0
    assert "foreign ELF in aarch64 payload" in result.stderr
    assert not list(output.glob("*.tar.*"))


@pytest.mark.parametrize("arch,loader,libdir", [
    ("x86_64", "lib64/ld-linux-x86-64.so.2", "lib64"),
    ("aarch64", "lib/ld-linux-aarch64.so.1", "lib"),
    ("arm64", "lib/ld-linux-aarch64.so.1", "lib"),
])
def test_glibc_catalog_metadata_uses_process_architecture(arch, loader, libdir):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua
    result = subprocess.run([
        lua, str(ROOT / "tests/lua/linux_runtime_layout_harness.lua"),
        str(ROOT / "pkgs/g/glibc.lua"), "glibc-2.44.3-r1-linux-aarch64.tar.gz",
        "/isolated/glibc", arch,
    ], check=True, capture_output=True, text=True)
    abi_arch = "aarch64" if arch == "arm64" else arch
    assert f"EXPORT {loader} linux-{abi_arch}-glibc {libdir}" in result.stdout.splitlines()


def test_raw_index_old_client_refuses_arm64_before_installation(tmp_path):
    """A raw local recipe cannot silently bind ARM64 to an x86 loader."""
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua
    harness = tmp_path / "old-client.lua"
    harness.write_text('''
os.arch = nil
function import(name)
  local key = name:match("[^.]+$")
  if key == "pkginfo" then
    _G[key] = {install_file=function() return "glibc-2.44.3-r1-linux-aarch64.tar.gz" end}
  elseif key == "log" then _G[key] = {error=function(msg) print(msg) end}
  else _G[key] = {} end
end
dofile(arg[1])
assert(install() == false)
''')
    result = subprocess.run([lua, str(harness), str(ROOT / "pkgs/g/glibc.lua")],
                            check=True, text=True, capture_output=True)
    assert "requires xlings >= 2026.10.8.1" in result.stdout


def _compiler_cfg(mode):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua
    return subprocess.run([
        lua, str(ROOT / "tests/lua/llvm_linux_cfg_harness.lua"),
        str(ROOT / "pkgs/l/llvm.lua"), mode,
    ], check=True, text=True, capture_output=True).stdout


def test_linux_cfg_closes_system_header_search():
    output = _compiler_cfg("complete")
    assert "RESULT true" in output and "WRITTEN 3" in output
    for section in output.split("FILE ")[1:]:
        assert "-nostdlibinc\n" in section
        assert "-isystem /managed/glibc/include\n" in section
        assert "-isystem /managed/uapi/include\n" in section
        assert "/usr/include" not in section and "/usr/local/include" not in section
    cxx = output.split("FILE /managed/llvm/bin/clang++.cfg\n")[1]
    assert cxx.index("/managed/llvm/include/c++/v1") < cxx.index("/managed/glibc/include")
    assert "/managed/llvm/include/aarch64-unknown-linux-gnu/c++/v1" in cxx


def test_missing_uapi_never_writes_partial_cfg():
    output = _compiler_cfg("missing-headers")
    assert "HOST MARKER true" in output
    assert "RESULT false" in output and "WRITTEN 0" in output
    assert "linux-headers payload not found" in output
    assert "refusing to write a host-dependent clang cfg" in output


def test_raw_verifier_requires_explicit_managed_uapi(tmp_path):
    """Host header availability cannot rescue a missing native dependency."""
    if not shutil.which("patchelf") or not shutil.which("file"):
        pytest.skip("raw verifier requires patchelf and file")
    import os
    import tarfile
    payload = tmp_path / "llvm-23.1.3-linux-aarch64"
    (payload / "bin").mkdir(parents=True)
    (payload / "lib/aarch64-unknown-linux-gnu").mkdir(parents=True)
    (payload / "share/libc++/v1").mkdir(parents=True)
    driver = payload / "bin/clang++"
    driver.write_text("#!/bin/sh\necho unexpected-compiler-invocation >&2\nexit 99\n")
    driver.chmod(0o755)
    for module in ("std.cppm", "std.compat.cppm"):
        (payload / "share/libc++/v1" / module).write_text("// fixture\n")
    for lib in ("libc++.so.1", "libatomic.so.1"):
        (payload / "lib/aarch64-unknown-linux-gnu" / lib).touch()
    archive = tmp_path / "llvm.tar.gz"
    with tarfile.open(archive, "w:gz") as package:
        package.add(payload, arcname=payload.name)
    glibc = tmp_path / "glibc"
    (glibc / "lib").mkdir(parents=True)
    (glibc / "include").mkdir()
    (glibc / "include/stdlib.h").touch()
    loader = glibc / "lib/ld-linux-aarch64.so.1"
    loader.touch()
    result = subprocess.run([
        "bash", str(ROOT / ".agents/tools/verify-toolchain.sh"), str(archive),
        "--loader", str(loader), "--linux-headers", str(tmp_path / "missing-uapi"),
    ], capture_output=True, text=True, env={**os.environ, "CPATH": "/usr/include"})
    assert result.returncode == 1, result.stdout + result.stderr
    assert "managed Linux UAPI headers absent" in result.stdout
    assert "unexpected-compiler-invocation" not in result.stderr


def test_existing_linux_llvm_versions_advance_hook_revision():
    lua = shutil.which("lua5.4") or shutil.which("lua")
    assert lua
    script = '''function import() end
dofile(arg[1])
for _, version in ipairs({"20.1.7", "22.1.8", "23.1.3"}) do
  local entry = package.xpm.linux[version]
  assert(entry.revision == 1)
  assert(entry.x86_64.revision == nil)
  assert(entry.x86_64.url.GLOBAL:find("llvm%-" .. version:gsub("%.", "%%.") .. "%-linux%-x86_64.tar.gz$"))
end
print("REVISION PASS")'''
    result = subprocess.run([lua, "-", str(ROOT / "pkgs/l/llvm.lua")],
                            input=script, capture_output=True, text=True, check=True)
    assert "REVISION PASS" in result.stdout
