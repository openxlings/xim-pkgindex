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

@pytest.mark.static
def test_core_and_gcc_use_the_same_binutils_version(tmp_path):
    target = tmp_path / "core"
    result = run_recipe("pkgs/l/luban-core.lua", target, "2026.10.10.1")
    assert result.returncode == 0, result.stderr
    packages = json.loads((target / ".xlings.json").read_text())["packages"]
    lua = shutil.which("lua") or shutil.which("lua5.4")
    result = subprocess.run([lua, "-e", '''function import() end
dofile(arg[0])
for _, name in ipairs(package.xpm.linux.deps.runtime) do
    if name:match("^xim:binutils@") then print(name) end
end
''', str(Path("pkgs/g/gcc.lua").resolve())], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() in packages
