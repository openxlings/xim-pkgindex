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
