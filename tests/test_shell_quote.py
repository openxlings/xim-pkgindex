"""shell: every value a recipe hands to a shell arrives as one word (mcpp#832).

`system.exec` runs its string through the host's shell, so a path holding a
space -- a home under `/tmp/mc probe` -- was split by gcc's specs rewrite. Two
kinds of test:

* the LINT runs over the whole index: every `%s` of an exec's format string is
  quoted, or the command is built with `xim.pkgindex.shell`;
* a BEHAVIOUR check of libs/shell.lua in a plain-Lua sandbox: the argv a real
  `sh` receives is the argv the recipe meant, for values with a space, a single
  quote, a dollar sign and a glob. Skipped when no `lua` is on the runner.
"""

import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent

pytestmark = pytest.mark.static


def test_every_exec_quotes_what_it_interpolates():
    proc = subprocess.run(["bash", str(REPO / "tools" / "lint_exec_quoting.sh")],
                          capture_output=True, text=True)
    assert proc.returncode == 0, proc.stdout + proc.stderr


HARNESS = r"""
import = function() end
os.host = function() return "linux" end
local ran
system = { exec = function(cmd) ran = cmd; local ok = os.execute(cmd); assert(ok == true or ok == 0, cmd) end }
local shell = assert(loadfile(arg[1]))()
local out = arg[2]
local values = { "/tmp/mc probe/home", "it's", "$HOME", "a*b", "家 目录" }
local argv = { "sh", "-c", 'for a in "$@"; do printf "%s\\n" "$a"; done > ' .. shell.quote(out), "sh" }
for _, v in ipairs(values) do argv[#argv + 1] = v end
shell.exec(argv)
"""


@pytest.mark.skipif(shutil.which("lua5.4") is None and shutil.which("lua") is None,
                    reason="no lua interpreter on this runner")
def test_quote_survives_a_real_shell(tmp_path):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    harness = tmp_path / "harness.lua"
    harness.write_text(HARNESS, encoding="utf-8")
    out = tmp_path / "out dir" / "argv.txt"
    out.parent.mkdir()
    proc = subprocess.run([lua, str(harness), str(REPO / "libs" / "shell.lua"), str(out)],
                          capture_output=True, text=True)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    got = out.read_text(encoding="utf-8").splitlines()
    assert got == ["/tmp/mc probe/home", "it's", "$HOME", "a*b", "家 目录"]
