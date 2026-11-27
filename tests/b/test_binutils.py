"""测试 binutils 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "binutils"
PKG_FILE = "pkgs/b/binutils.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)


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


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_ld(self):
        assert_command_output("ld --version 2>&1 | head -1", contains="ld")



# ── the nine links of xlings design 2026-11-27 §2.8 (E13) and §8.3 ─────────
#
# The ld wrapper gives an executable on the environment's runtime the subos
# farm as its run path, and leaves a host compiler's links, a static link and
# -shared alone; XLINGS_SUBOS_LD_PATHS=0 keeps the tag only (#532, #540).

import re
import tempfile
from pathlib import Path

from tests.lib.xlings_client import _run_xlings

_SOURCES = {
    "hello.c": '#include <stdio.h>\nint main(void){ puts("ok"); return 0; }\n',
    "z.c": '#include <stdio.h>\n#include <zlib.h>\nint main(void){ printf("ok %s\\n", zlibVersion()); return 0; }\n',
    "z.cc": '#include <iostream>\n#include <zlib.h>\nint main(){ std::cout << "ok " << zlibVersion() << "\\n"; }\n',
    "gl.c": '#include <stdio.h>\nextern const unsigned char* glGetString(unsigned);\n'
            'int main(void){ printf("ok %p\\n", (void*)&glGetString); return 0; }\n',
    "lib.c": "int lib_answer(void){ return 42; }\n",
}


def _sh(cmd, timeout=900):
    return _run_xlings(cmd, timeout=timeout)


def _dynamic(binary):
    """(tag, [paths]) of the binary's run path: ("RPATH"|"RUNPATH"|None, [...])."""
    code, out = _sh(f"readelf -d {binary}")
    assert code == 0, out
    m = re.search(r"\((RPATH|RUNPATH)\)\s+Library (?:rpath|runpath): \[([^\]]*)\]", out)
    return (m.group(1), m.group(2).split(":")) if m else (None, [])


@pytest.fixture(scope="module")
def links():
    for pkg in ("xim:gcc", "xim:zlib", "xim:libglvnd"):
        code, out = _sh(f"xlings install {pkg} -y", timeout=1800)
        assert code == 0, f"{pkg}: {out}"
    code, farm = _sh('printf %s "$XLINGS_SUBOS_LIB"')
    assert code == 0 and farm, "the subos does not declare XLINGS_SUBOS_LIB: " + farm
    work = Path(tempfile.mkdtemp(prefix="ld-rows-"))
    for name, text in _SOURCES.items():
        (work / name).write_text(text, encoding="utf-8")
    return work, farm.strip()


def _build(work, cmd, out_name, env=""):
    code, out = _sh(f"cd {work} && {env} {cmd} -o {out_name}")
    assert code == 0, f"{cmd}: {out}"
    return work / out_name


def _runs(binary, env=""):
    code, out = _sh(f"{env} {binary}")
    return code == 0 and out.strip().startswith("ok"), out


class TestLdWrapperRows:
    @pytest.mark.verify
    @skip_if_not('linux')
    @pytest.mark.parametrize("row,cmd,expect_farm", [
        (1, "gcc z.c -lz", True),
        (2, "gcc gl.c -lGL", True),
        (3, "gcc hello.c", True),
        (9, "g++ z.cc -lz", True),
    ])
    def test_the_subos_toolchain_gets_the_farm_last_and_runs(self, links, row, cmd, expect_farm):
        work, farm = links
        b = _build(work, cmd, f"row{row}")
        tag, paths = _dynamic(b)
        assert tag == "RPATH" and paths and paths[-1] == farm, f"row {row}: {tag} {paths}"
        ok, out = _runs(b)
        assert ok, f"row {row} does not run: {out}"

    @pytest.mark.verify
    @skip_if_not('linux')
    # -B: the host compiler takes `ld` from the subos (the wrapper), as one
    # that finds it on PATH does -- the case that crashed (row E12).
    @pytest.mark.parametrize("row,cmd", [
        (4, '/usr/bin/gcc -B"$(dirname "$(command -v ld)")" z.c -lz'),
        (5, '/usr/bin/gcc -B"$(dirname "$(command -v ld)")" hello.c'),
    ])
    def test_a_host_compiler_through_the_same_ld_is_left_alone(self, links, row, cmd):
        work, farm = links
        if not Path("/usr/bin/gcc").exists():
            pytest.skip("no host compiler on this machine")
        b = _build(work, cmd, f"row{row}")
        tag, paths = _dynamic(b)
        assert farm not in paths, f"row {row}: the farm reached a host compiler's program: {paths}"
        ok, out = _runs(b)
        assert ok, f"row {row} does not run: {out}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_shared_and_static_links_get_no_run_path(self, links):
        work, farm = links
        lib = _build(work, "gcc -shared -fPIC lib.c", "row6.so")
        assert farm not in _dynamic(lib)[1], "row 6: -shared got the farm"
        static = _build(work, "gcc -static hello.c", "row7")
        assert farm not in _dynamic(static)[1], "row 7: -static got the farm"
        ok, out = _runs(static)
        assert ok, f"row 7 does not run: {out}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_declaring_ld_paths_off_keeps_the_tag_without_the_farm(self, links):
        work, farm = links
        b = _build(work, "gcc z.c -lz", "row8", env="XLINGS_SUBOS_LD_PATHS=0")
        tag, paths = _dynamic(b)
        assert tag == "RPATH" and farm not in paths, f"row 8: {tag} {paths}"
