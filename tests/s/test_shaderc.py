"""Tests for the shaderc package -- glslc and the SPIRV-Tools binaries,
repacked from conda-forge with its glslang and SPIRV-Tools closure.

The property that distinguishes this payload from `xim:glslang` is negative:
it carries a NEWER glslang than that package publishes and must not register
or declare it. Two packages competing for one program name is a race whose
winner is whichever installed last."""
import glob
import os
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "shaderc"
PKG_FILE = "pkgs/s/shaderc.lua"
PROGRAMS = ("glslc", "spirv-as", "spirv-dis", "spirv-link", "spirv-opt", "spirv-val")


def _code(content: str) -> str:
    """Strip lua line comments so static assertions see only real declarations."""
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


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

    @pytest.mark.static
    def test_declares_both_archs(self, meta):
        code = _code(meta.raw_content)
        assert 'archs = {"x86_64", "aarch64"}' in code

    @pytest.mark.static
    def test_resource_has_both_mirrors_per_arch(self, meta):
        """Every resource resolves through both mirrors with its own sha256 --
        the per-resource shape, not one pair shared across architectures or
        platforms.

        THE DENOMINATOR COMES FROM THE RECIPE, not from a list kept here. An
        earlier version asserted `== 2`, which was the count of the two Linux
        architectures; adding macOS and Windows made it fail for the right
        reason and the wrong one -- it could only ever notice that the number
        changed, never that a platform had lost its CN mirror.
        """
        code = _code(meta.raw_content)
        globals_ = re.findall(
            r'GLOBAL\s*=\s*"https://github\.com/xlings-res/shaderc/[^"]*/([^"/]+)"', code)
        cns = re.findall(
            r'CN\s*=\s*"https://gitcode\.com/xlings-res/shaderc/[^"]*/([^"/]+)"', code)
        shas = re.findall(r'sha256 = "[0-9a-f]{64}"', code)

        assert globals_, "no GLOBAL urls at all"
        assert globals_ == cns, \
            f"the two mirrors do not name the same files:\n  GLOBAL {globals_}\n  CN     {cns}"
        assert len(shas) == len(globals_), \
            f"{len(globals_)} resources but {len(shas)} sha256 entries"

        # …and each platform this recipe declares contributes at least one
        # resource, so a block added without a download is caught too.
        for plat in re.findall(r'^\s{8}(linux|macosx|windows) = \{', code, re.M):
            token = {"linux": "linux-", "macosx": "macosx-", "windows": "windows-"}[plat]
            assert any(token in f for f in globals_), \
                f"the {plat} block declares no resource"

    @pytest.mark.static
    def test_seals_both_bin_and_lib(self, meta):
        """The default libdirs list is {"lib","lib64"}; without "bin" the
        programs' own RPATH is left as conda wrote it and their libstdc++
        resolves from the host."""
        code = _code(meta.raw_content)
        assert re.search(r'selfcontain\.seal\([^)]*"lib"[^)]*"bin"[^)]*\)', code) \
            or re.search(r'selfcontain\.seal\([^)]*"bin"[^)]*"lib"[^)]*\)', code), \
            "selfcontain.seal must cover both lib/ and bin/"

    @pytest.mark.static
    def test_does_not_register_glslang(self, meta):
        """`xim:glslang` owns those two program names. This payload carries a
        newer glslang and must neither register nor declare it, or the two
        packages race for one name."""
        code = _code(meta.raw_content)
        assert "glslangValidator" not in code, \
            "shaderc must not register glslangValidator; xim:glslang owns that name"
        assert not re.search(r'xvm\.add\(\s*"glslang"', code), \
            "shaderc must not register the glslang program name"

    @pytest.mark.static
    def test_declares_no_libs_into_the_subos(self, meta):
        """The payload's glslang and SPIRV-Tools are private to it. Declaring
        them into the subos library view would put a second, differently
        versioned copy of both sonames on every consumer's search path."""
        code = _code(meta.raw_content)
        assert "declare_libs" not in code
        assert "declare_headers" not in code

    @pytest.mark.static
    def test_programs_field_matches_registration(self, meta):
        code = _code(meta.raw_content)
        for prog in PROGRAMS:
            assert f'"{prog}"' in code, f"{prog} is not named in the recipe"


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
        assert_install_succeeds(f"local:{PKG}")


def _payload_dir() -> str:
    for ns in ("xim", "local"):
        hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-shaderc", "*")))
        if hits:
            return hits[-1]
    pytest.fail(f"no shaderc payload in the store ({xpkgs_dir()})")


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_programs_present(self):
        b = os.path.join(_payload_dir(), "bin")
        for prog in PROGRAMS:
            assert os.path.isfile(os.path.join(b, prog)), f"payload is missing bin/{prog}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_glslang_binaries_were_removed(self):
        """The negative of test_does_not_register_glslang, measured on the
        installed tree rather than on the recipe text."""
        b = os.path.join(_payload_dir(), "bin")
        for name in ("glslang", "glslangValidator"):
            assert not os.path.exists(os.path.join(b, name)), \
                f"bin/{name} is in the payload; xim:glslang owns that name"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_executables_carry_rpath_not_runpath(self):
        """The tag, on the half where it is load-bearing. `elfpatch` stamps
        DT_RPATH on an object with a PT_INTERP and DT_RUNPATH on one without,
        and that split is a measured policy rather than an accident: RPATH is
        consulted for every dlopen anywhere beneath it, RUNPATH only for the
        object carrying it, and forcing RPATH onto a LIBRARY was measured
        harmful in xim-pkgindex#593. So the assertion is on the programs --
        a glslc whose libstdc++ came from a RUNPATH would still run here and
        fail wherever the caller's inherited path was the one that mattered."""
        b = os.path.join(_payload_dir(), "bin")
        for prog in PROGRAMS:
            r = subprocess.run(["readelf", "-d", os.path.join(b, prog)],
                               capture_output=True, text=True, timeout=15)
            assert r.returncode == 0, f"readelf {prog} failed"
            assert "(RPATH)" in r.stdout, f"bin/{prog} carries no DT_RPATH"
            assert "(RUNPATH)" not in r.stdout, f"bin/{prog} carries a DT_RUNPATH"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_libraries_name_their_own_directory(self):
        """The library half of the same question. Whichever tag elfpatch
        chose, a payload library must be able to find its siblings without
        the host: the search path names this payload's own lib/."""
        lib = os.path.join(_payload_dir(), "lib")
        checked = 0
        for name in sorted(os.listdir(lib)):
            p = os.path.join(lib, name)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            with open(p, "rb") as f:
                if f.read(4) != b"\x7fELF":
                    continue
            r = subprocess.run(["readelf", "-d", p], capture_output=True,
                               text=True, timeout=15)
            if r.returncode != 0:
                continue
            checked += 1
            assert lib in r.stdout or "$ORIGIN" in r.stdout, \
                f"lib/{name} names neither $ORIGIN nor {lib} in its search path"
        assert checked > 0, "walked lib/ and found no ELF file to check"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_every_needed_resolves_inside_payloads(self):
        """The whole point of the repack. `ldd` on each program must name no
        file outside the xlings store -- the vdso and the payload loader
        itself are the only entries with no store path."""
        home = os.path.dirname(os.path.dirname(xpkgs_dir()))
        b = os.path.join(_payload_dir(), "bin")
        for prog in PROGRAMS:
            r = subprocess.run(["ldd", os.path.join(b, prog)],
                               capture_output=True, text=True, timeout=30)
            assert r.returncode == 0, f"ldd {prog} failed: {r.stderr[:200]}"
            for line in r.stdout.splitlines():
                if "=>" not in line:
                    continue
                target = line.split("=>", 1)[1].strip().split(" ")[0]
                if not target or target == "not":
                    pytest.fail(f"{prog}: unresolved dependency in {line.strip()!r}")
                assert target.startswith(home), \
                    f"{prog} resolves {line.strip()!r} outside the xlings store"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_glslc_compiles_a_shader(self, tmp_path):
        """The criterion the package exists for: SPIR-V out of GLSL, checked
        by the module's own magic number rather than by an exit status."""
        src = tmp_path / "scale.comp"
        src.write_text(
            "#version 450\n"
            "layout(local_size_x = 64) in;\n"
            "layout(std430, binding = 0) buffer B { uint v[]; };\n"
            "void main() { v[gl_GlobalInvocationID.x] *= 2; }\n"
        )
        out = tmp_path / "scale.spv"
        r = subprocess.run(
            [os.path.join(_payload_dir(), "bin", "glslc"),
             "--target-env=vulkan1.2", "-O", "-o", str(out), str(src)],
            capture_output=True, text=True, timeout=120)
        assert r.returncode == 0, f"glslc failed: {r.stderr[:400]}"
        assert out.read_bytes()[:4] == b"\x03\x02\x23\x07", \
            "output does not start with the SPIR-V magic number 0x07230203"
