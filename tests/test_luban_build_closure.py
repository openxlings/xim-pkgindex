"""Cold-root constructor dependencies and compiler/linker version coherence."""
import json
from pathlib import Path
import shutil
import subprocess
import pytest
from tests.lib.luban_recipe import run_recipe

@pytest.mark.static
@pytest.mark.parametrize("recipe", ["pkgs/g/gcc.lua", "pkgs/g/gcc-runtime.lua", "pkgs/b/binutils.lua", "pkgs/o/openssl.lua", "pkgs/x/xz.lua"])
def test_elf_relocation_has_an_explicit_build_provider(recipe):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    result = subprocess.run([lua, "-e", '''function import() end
os.host = function() return "linux" end
is_host = function() return true end
dofile(arg[0])
for _, name in ipairs(package.xpm.linux.deps.build or {}) do print(name) end
''', str(Path(recipe).resolve())], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert "xim:patchelf@0.18.0" in result.stdout.splitlines()

def _release(coordinate):
    return tuple(int(p) for p in coordinate.split("@", 1)[1].split("."))


@pytest.mark.static
def test_gcc_declares_no_older_binutils_than_a_core_edition(tmp_path):
    """A published core edition pins the binutils it was made with, and its output
    never changes (test_luban_published.py); gcc declares the binutils its newest
    payload is configured and built against, which moves with a toolchain refresh
    (gcc 16.2.0 revision 1: binutils 2.47). The two are equal only until that
    refresh. What holds is that gcc's is not older: a payload runs with the
    binutils it was built against or a newer one, so the edition's gcc gets an
    assembler and linker at least as new as the ones it was made with."""
    target = tmp_path / "core"
    result = run_recipe("pkgs/luban/luban-core.lua", target, "2026.10.11.1")
    assert result.returncode == 0, result.stderr
    packages = json.loads((target / ".xlings.json").read_text())["packages"]
    pinned = [p for p in packages if p.startswith("xim:binutils@")]
    assert len(pinned) == 1, packages
    lua = shutil.which("lua") or shutil.which("lua5.4")
    result = subprocess.run([lua, "-e", '''function import() end
dofile(arg[0])
for _, name in ipairs(package.xpm.linux.deps.runtime) do
    if name:match("^xim:binutils@") then print(name) end
end
''', str(Path("pkgs/g/gcc.lua").resolve())], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    declared = result.stdout.split()
    assert len(declared) == 1, result.stdout
    assert _release(declared[0]) >= _release(pinned[0]), (declared, pinned)
