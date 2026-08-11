"""binutils: the `ld` wrapper that lets a subos link against its own farm.

WHAT IS BEING DEFENDED

A subos publishes every installed library into `<subos>/lib` and puts that on
the compiler's search path, so `gcc t.c -lGL` finds `libGL.so`. But `libGL.so`
has DT_NEEDED on `libGLdispatch.so.0` and `libGLX.so.0`, and `ld` does NOT
search `-L` directories for a dependency's dependencies. Measured on a real
home, verbatim:

    ld: warning: libGLdispatch.so.0, needed by <subos>/lib/libGL.so, not found
        (try using -rpath or -rpath-link)
    ld: <subos>/lib/libGL.so: undefined reference to `__glDispatchInit'

Both libraries are in the same directory as libGL.so. The linker's own message
names the fix (openxlings/xlings#532).

WHY THESE TESTS RUN THE SHELL

The wrapper is a `#!/bin/sh` file this recipe generates, and its failure mode
is not "wrong output" -- it is a linker that vanishes, or one that appends
`-rpath-link ""`, which is not "no option" but an option naming the current
directory. That is the same empty-vs-absent confusion that produced
`--sysroot=` and cost this project five days. So the wrapper text is lifted
out of the recipe and actually executed against a stub linker, rather than
matched against a pattern.
"""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
RECIPE = REPO / "pkgs" / "b" / "binutils.lua"


def _recipe_text() -> str:
    return RECIPE.read_text(encoding="utf-8")


def _wrapper_body(real_path: str) -> str:
    """The wrapper exactly as the recipe writes it, for a given real `ld`.

    Lifted from the recipe rather than copied into this file: a copy is a
    second source of truth, and the whole class of bug here is two things
    that are supposed to agree and quietly stop agreeing.
    """
    text = _recipe_text()
    start = text.index('io.writefile(wrapper, table.concat({')
    end = text.index('}, "\\n"))', start)
    block = text[start:end]

    lines = []
    for raw in block.splitlines()[1:]:
        raw = raw.strip().rstrip(",")
        if not raw:
            continue
        if raw.startswith("'") and raw.endswith("'"):
            lines.append(raw[1:-1])
        elif raw.startswith('"') and raw.endswith('"'):
            lines.append(raw[1:-1])
        elif ".. __shq(real)" in raw:
            # `[ -x "$real" ] || real=` .. __shq(real)
            prefix = raw.split(".. __shq(real)")[0].strip().rstrip()
            prefix = prefix[1:-1] if prefix.startswith("'") else prefix
            lines.append(prefix + "'" + real_path.replace("'", "'\\''") + "'")
        else:
            raise AssertionError(
                f"unrecognised wrapper line in binutils.lua: {raw!r} -- the "
                "generator changed shape and this test can no longer read it"
            )
    assert lines, "no wrapper lines were extracted from the recipe"
    return "\n".join(lines) + "\n"


@pytest.fixture()
def wrapper(tmp_path):
    """A materialised wrapper plus a stub `ld` that records its argv."""
    payload = tmp_path / "payload"
    (payload / "bin").mkdir(parents=True)
    (payload / "xlings-wrappers").mkdir()

    argv_log = tmp_path / "argv.txt"
    real = payload / "bin" / "ld"
    real.write_text(
        "#!/bin/sh\n"
        f'printf "%s\\n" "$@" > {argv_log}\n'
        "exit 0\n",
        encoding="utf-8",
    )
    real.chmod(0o755)

    w = payload / "xlings-wrappers" / "ld"
    w.write_text(_wrapper_body(str(real)), encoding="utf-8")
    w.chmod(0o755)
    return w, argv_log


@pytest.mark.static
def test_the_wrapper_is_valid_posix_sh(wrapper):
    w, _ = wrapper
    sh = shutil.which("sh")
    if sh is None:
        pytest.skip("no POSIX sh here; this wrapper is a linux-only payload")
    r = subprocess.run([sh, "-n", str(w)], capture_output=True, text=True)
    assert r.returncode == 0, (
        "the generated wrapper does not parse; the linker would be replaced "
        f"by a file that cannot run:\n{r.stderr}"
    )


@pytest.mark.static
def test_the_farm_is_passed_when_the_variable_is_set(wrapper, tmp_path):
    w, log = wrapper
    farm = tmp_path / "subos" / "lib"
    farm.mkdir(parents=True)
    r = subprocess.run(
        [str(w), "-o", "out", "obj.o"],
        env={"PATH": "/usr/bin:/bin", "XLINGS_SUBOS_LIB": str(farm)},
        capture_output=True, text=True,
    )
    assert r.returncode == 0, r.stderr
    args = log.read_text().split()
    assert "-rpath-link" in args, "the farm was not passed to the linker"
    assert str(farm) in args
    # The caller's own arguments must survive, in order and unmangled.
    assert args[-3:] == ["-o", "out", "obj.o"]


@pytest.mark.static
def test_nothing_is_passed_when_the_variable_is_absent(wrapper):
    w, log = wrapper
    r = subprocess.run(
        [str(w), "-o", "out"],
        env={"PATH": "/usr/bin:/bin"},
        capture_output=True, text=True,
    )
    assert r.returncode == 0, r.stderr
    args = log.read_text().split()
    assert "-rpath-link" not in args, (
        "an absent variable must make the whole option disappear -- "
        '`-rpath-link ""` is not "no option", it names the current directory'
    )
    assert args == ["-o", "out"]


@pytest.mark.static
def test_a_variable_pointing_nowhere_adds_nothing(wrapper, tmp_path):
    w, log = wrapper
    r = subprocess.run(
        [str(w), "-o", "out"],
        env={"PATH": "/usr/bin:/bin",
             "XLINGS_SUBOS_LIB": str(tmp_path / "does-not-exist")},
        capture_output=True, text=True,
    )
    assert r.returncode == 0, r.stderr
    assert "-rpath-link" not in log.read_text().split()


@pytest.mark.static
def test_a_path_with_a_space_survives(tmp_path):
    """A store under `/home/John Doe/...` must not split into two arguments."""
    payload = tmp_path / "my payload"
    (payload / "bin").mkdir(parents=True)
    (payload / "xlings-wrappers").mkdir()
    argv_log = tmp_path / "argv.txt"
    real = payload / "bin" / "ld"
    real.write_text(
        "#!/bin/sh\n" f'printf "%s\\n" "$@" > "{argv_log}"\n' "exit 0\n",
        encoding="utf-8")
    real.chmod(0o755)
    w = payload / "xlings-wrappers" / "ld"
    w.write_text(_wrapper_body(str(real)), encoding="utf-8")
    w.chmod(0o755)

    farm = tmp_path / "a subos" / "lib"
    farm.mkdir(parents=True)
    r = subprocess.run([str(w), "-o", "out"],
                       env={"PATH": "/usr/bin:/bin",
                            "XLINGS_SUBOS_LIB": str(farm)},
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    lines = argv_log.read_text().splitlines()
    assert str(farm) in lines, f"the farm path was split or mangled: {lines}"


@pytest.mark.static
def test_only_ld_is_registered_through_the_wrapper():
    """`as` and `gold` resolve nothing transitively; routing them through a
    shell process would be cost with no effect."""
    text = _recipe_text()
    assert 'bindir = (program == "ld") and ld_bindir or binutils_bindir' in text


@pytest.mark.static
def test_a_new_version_key_exists_so_installed_homes_re_run_config():
    """config() runs only when a package INSTALLS.

    Without a new key, every home that already has binutils keeps an `ld`
    that cannot see the subos farm, with nothing to say so -- the fix ships
    and those users never get it. Same move as libglvnd 1.7.0.1.
    """
    text = _recipe_text()
    assert '["latest"] = { ref = "2.42.1" }' in text
    assert '["2.42.1"] = {' in text
    assert '["2.42"] = "XLINGS_RES"' in text, (
        "the previous key must stay resolvable: homes pinned to it, and "
        "removing a version key is not an upgrade path"
    )
    # Same artifact, so the sha256 must be the 2.42 tarball's and the URL must
    # still name 2.42 -- there is no 2.42.1 artifact to fetch.
    m = re.search(r'\["2\.42\.1"\] = \{(.*?)\n            \}', text, re.S)
    assert m, "could not read the 2.42.1 entry"
    entry = m.group(1)
    assert "binutils-2.42-linux-x86_64.tar.gz" in entry
    assert "sha256" in entry
