"""hostlib: one answer to "where is the host's <soname>".

Two kinds of test, deliberately:

* an INVARIANT, in pure Python, that always runs -- no recipe may carry a
  hardcoded list of distribution library directories. That list is the bug
  class: FHS biarch (/usr/lib = 32-bit) and Debian multiarch (/usr/lib =
  64-bit) are both correct, so a list is a decision to be wrong somewhere.
  mcpp#352 is that bug in the mcpp index; this test is what stops it coming
  back here.

* a BEHAVIOUR check of libs/hostlib.lua itself, run in a plain-Lua sandbox
  against a forged biarch host. Skipped rather than failed when no `lua5.4` is
  on the runner: a missing interpreter is not a defect in the index, and a
  fatal skip would make the whole suite unrunnable on a machine that is
  otherwise fine.

Design: xlings/.agents/docs/2026-08-07-graphics-experience-industry-survey-and-plan.md §9.2
"""

import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
HARNESS = REPO / "tests" / "lua" / "hostlib_harness.lua"
HOSTLIB = REPO / "libs" / "hostlib.lua"

# The three layouts, spelled the way a recipe would spell them.
LIBDIR_TOKENS = (
    "/usr/lib/x86_64-linux-gnu",
    "/lib/x86_64-linux-gnu",
    "/usr/lib64",
    "/lib64",
)

# hostlib.lua IS the list, and the verifier carries the same three rules in
# shell because it cannot import Lua. Both are the single implementation this
# test exists to funnel everything else into.
ALLOWED = {
    "libs/hostlib.lua",
}


def _recipes():
    return sorted(REPO.glob("pkgs/*/*.lua"))


def test_hostlib_exists():
    assert HOSTLIB.is_file(), "libs/hostlib.lua is the shared host-library probe"


@pytest.mark.parametrize("recipe", _recipes(), ids=lambda p: p.name)
def test_no_hardcoded_distro_libdir_list(recipe):
    """A recipe must not enumerate distro library directories.

    One token is fine: a package legitimately mentions a single path in a
    comment, or joins one it was handed. TWO OR MORE distinct layout roots in
    one file is the shape that means "I am guessing the layout", and that is
    what must go through hostlib instead -- because hostlib ELF-class checks
    the answer, and a list cannot.
    """
    rel = recipe.relative_to(REPO).as_posix()
    if rel in ALLOWED:
        pytest.skip("this file is the implementation")

    text = recipe.read_text(encoding="utf-8", errors="replace")
    # Comments are where the *reason* lives, and several recipes correctly
    # explain the layout problem in prose. Only code counts.
    code = "\n".join(
        line for line in text.splitlines() if not line.lstrip().startswith("--")
    )
    hits = sorted({tok for tok in LIBDIR_TOKENS if tok in code})
    assert len(hits) < 2, (
        f"{rel} enumerates distro library directories {hits}. There is no layout "
        "to assume: FHS biarch makes /usr/lib 32-bit (Fedora/RHEL/SUSE) and "
        "Debian multiarch makes it 64-bit. Use "
        'import("xim.pkgindex.hostlib") and hostlib.dir_of(<soname>), which asks '
        "ldconfig -p, checks the ELF class and takes the first hit."
    )


def test_verifier_probes_rather_than_hardcodes():
    """verify-host-link.sh must not pin one layout either.

    It skipped its own check 4 in silence on any non-Debian host and still
    printed PASS -- worse than the same mistake in a recipe, because this file
    exists to prove something.
    """
    sh = REPO / ".agents" / "tools" / "graphics" / "verify-host-link.sh"
    if not sh.is_file():
        pytest.skip("verifier not present")
    text = sh.read_text(encoding="utf-8", errors="replace")
    assert "host_vendor_dir" in text, (
        "verify-host-link.sh should resolve the host vendor directory with its "
        "host_vendor_dir() probe (ldconfig -p, ELF class, first hit)"
    )
    # A check that did not run has to be counted, or "PASS: 12 checks" is
    # compatible with two of them never having executed.
    assert re.search(r"\bskipped=\$\(\(skipped\+1\)\)", text), (
        "verify-host-link.sh should count skipped checks and report them in the "
        "verdict"
    )


@pytest.mark.skipif(
    shutil.which("lua5.4") is None and shutil.which("lua") is None,
    reason="no lua interpreter on this machine",
)
def test_hostlib_behaviour_against_a_forged_biarch_host(tmp_path):
    """The #352 shape: 32-bit copy in /usr/lib, real one in /usr/lib64."""
    lua = shutil.which("lua5.4") or shutil.which("lua")
    cc = shutil.which("gcc") or shutil.which("cc")
    if cc is None:
        pytest.skip("no compiler to forge ELF fixtures")

    root = tmp_path / "fakehost"
    for d in ("usr/lib", "usr/lib64", "mixed", "dangling"):
        (root / d).mkdir(parents=True)

    src = root / "foo.c"
    src.write_text("int foo(void){return 1;}\n")
    so64 = root / "usr/lib64/libFoo.so.1"
    subprocess.run([cc, "-shared", "-o", str(so64), str(src)], check=True)

    def make32(dst: Path):
        # e_ident[EI_CLASS] = ELFCLASS32. Forged rather than cross-compiled so
        # the test needs no multilib toolchain; only the class byte is read.
        data = bytearray(so64.read_bytes())
        data[4] = 1
        dst.write_bytes(bytes(data))

    make32(root / "usr/lib/libFoo.so.1")
    (root / "usr/lib/notelf.so").write_text("not an elf\n")
    shutil.copy(so64, root / "mixed/libnvidia-glcore.so.550")
    make32(root / "mixed/libnvidia-eglcore.so.550")
    (root / "dangling/libnvidia-ghost.so.1").symlink_to("/nonexistent/x.so")

    env = dict(os.environ)
    env["FAKE_ROOT"] = str(root)
    env["HOSTLIB"] = str(HOSTLIB)
    env["PATH"] = f"{root / 'fake-bin'}:{env['PATH']}"

    proc = subprocess.run(
        [lua, str(HARNESS)], capture_output=True, text=True, env=env, cwd=tmp_path
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "PASS:" in proc.stdout, proc.stdout
