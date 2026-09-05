"""Tests for the pocl package -- a CPU OpenCL platform repacked from
conda-forge, following the mesa-lavapipe closure-payload design: a complete
runtime closure with DT_RPATH=$ORIGIN, no `deps`, nothing declared into the
subos library view."""
import glob
import json
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
from tests.lib.platform_utils import skip_if_not, xlings_home, xpkgs_dir

PKG = "pocl"
PKG_FILE = "pkgs/p/pocl.lua"


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
        """Each declared arch resolves through both mirrors, with its own
        sha256 -- the V2 per-arch resource shape (aria2-next.lua, cc-switch.lua),
        not one url/sha256 pair shared across architectures."""
        code = _code(meta.raw_content)
        assert re.search(
            r'GLOBAL\s*=\s*"https://github\.com/xlings-res/pocl/[^"]+linux-x86_64\.tar\.gz"', code)
        assert re.search(
            r'CN\s*=\s*"https://gitcode\.com/xlings-res/pocl/[^"]+linux-x86_64\.tar\.gz"', code)
        assert re.search(
            r'GLOBAL\s*=\s*"https://github\.com/xlings-res/pocl/[^"]+linux-aarch64\.tar\.gz"', code)
        assert re.search(
            r'CN\s*=\s*"https://gitcode\.com/xlings-res/pocl/[^"]+linux-aarch64\.tar\.gz"', code)
        assert len(re.findall(r'sha256 = "[0-9a-f]{64}"', code)) == 2

    @pytest.mark.static
    def test_no_deps(self, meta):
        """No `deps`, by design: the payload is a complete conda-forge
        closure with DT_RPATH=$ORIGIN, and elfpatch would replace that with a
        DT_RUNPATH for any declared dependency -- see the recipe's own
        comment for the mesa-lavapipe precedent this follows."""
        code = _code(meta.raw_content)
        assert not re.search(r'\bdeps\s*=', code), \
            "pocl must declare no deps -- a declared dep hands the payload " \
            "to elfpatch, which turns DT_RPATH into a DT_RUNPATH"

    @pytest.mark.static
    def test_does_not_seal_payload(self, meta):
        """`selfcontain.seal` is for closing a payload's OWN unresolved
        NEEDED entries against other packages' libs; this payload resolves
        entirely inside itself and nothing outside it needs closing over."""
        code = _code(meta.raw_content)
        assert "selfcontain" not in code

    @pytest.mark.static
    def test_rewrites_conda_placeholder_in_libpocl(self, meta):
        """install() must patch libpocl.so's compiled-in conda build path --
        without it, libpocl.so looks for its kernel bitcode and headers under
        a directory that exists on no end-user machine and clBuildProgram
        fails for every kernel."""
        code = _code(meta.raw_content)
        assert "lib/libpocl.so" in code
        assert "_h_env_placehold" in meta.raw_content
        assert "CONDA_PLACEHOLDERS" in code

    @pytest.mark.static
    def test_placeholder_strings_are_255_bytes(self, meta):
        """A hand-miscounted placeholder is invisible in the source and turns
        every replacement into a silent no-op -- catch it here instead of at
        install time on some user's machine."""
        text = meta.raw_content
        for m in re.finditer(
            r'"(/home/conda/feedstock_root/build_artifacts/[^"]*)"'
            r'((?:\s*\.\.\s*"[^"]*")*)',
            text,
        ):
            if "_h_env_placehold" not in m.group(0):
                continue
            pieces = re.findall(r'"([^"]*)"', m.group(0))
            full = "".join(pieces)
            assert len(full) == 255, (
                f"placeholder reassembles to {len(full)} bytes, not 255: {full!r}"
            )

    @pytest.mark.static
    def test_rewrites_icd_manifest(self, meta):
        code = _code(meta.raw_content)
        assert "etc/OpenCL/vendors/pocl.icd" in code

    @pytest.mark.static
    def test_config_wires_opencl_discovery(self, meta):
        code = _code(meta.raw_content)
        assert "graphics.declare_opencl_icd" in code
        assert "graphics.declare_opencl_icd_library" in code
        assert "OCL_ICD_VENDORS" not in re.sub(r"--[^\n]*", "", code), \
            "the recipe must never declare OCL_ICD_VENDORS; it replaces the host's vendors directory"


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
        # Explicit local:, for the same reason ncurses's lifecycle test uses
        # it: the only spelling that is correct both before and after this
        # package is published to the index.
        assert_install_succeeds(f"local:{PKG}")


# -- L4 helpers -- read the installed payload and the subos state directly,
# never through a shim.

def _payload_dir() -> str:
    for ns in ("xim", "local"):
        hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-pocl", "*")))
        if hits:
            return hits[-1]
    pytest.fail(f"no pocl payload in the store ({xpkgs_dir()})")


def _subos_workspace(name: str = None) -> dict:
    names = [name] if name else ["current", "default"]
    for n in names:
        p = os.path.join(xlings_home(), "subos", n, ".xlings.json")
        if os.path.isfile(p):
            with open(p, encoding="utf-8") as f:
                return json.load(f).get("workspace", {})
    pytest.fail("no subos .xlings.json found")


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_payload_libs_present(self):
        lib = os.path.join(_payload_dir(), "lib")
        for name in ("libpocl.so", "libOpenCL.so.1"):
            assert os.path.exists(os.path.join(lib, name)), f"payload is missing {name}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_placeholder_was_rewritten(self):
        """The installed libpocl.so must carry the real payload path, not
        the conda build-time placeholder -- the static test checks the
        recipe SAYS to rewrite it, this checks install() actually did."""
        libpocl = os.path.realpath(os.path.join(_payload_dir(), "lib", "libpocl.so"))
        with open(libpocl, "rb") as f:
            data = f.read()
        assert b"_h_env_placehold" not in data, \
            "installed libpocl.so still carries the conda build placeholder"
        assert _payload_dir().encode() in data, \
            "installed libpocl.so does not carry its own install path"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_icd_manifest_rewritten(self):
        icd = os.path.join(_payload_dir(), "etc", "OpenCL", "vendors", "pocl.icd")
        assert os.path.isfile(icd), "no etc/OpenCL/vendors/pocl.icd in the payload"
        content = open(icd, encoding="utf-8").read()
        assert content.strip() == os.path.join(_payload_dir(), "lib", "libpocl.so")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_no_runpath_anywhere_in_payload(self):
        """RPATH, never RUNPATH: a non-empty RUNPATH on a dlopen'd object
        switches off the loading executable's inherited RPATH for that
        object's own dependencies -- the same failure mode mesa-lavapipe's
        recipe documents for the Vulkan ICD, here it would strand
        libOpenCL.so.1 unable to resolve libpocl.so's LLVM/libclang-cpp."""
        d = _payload_dir()
        checked = 0
        for root, _, files in os.walk(d):
            for name in files:
                p = os.path.join(root, name)
                if os.path.islink(p) or not os.path.isfile(p):
                    continue
                with open(p, "rb") as f:
                    head = f.read(4)
                if head != b"\x7fELF":
                    continue
                r = subprocess.run(["readelf", "-d", p], capture_output=True,
                                    text=True, timeout=15)
                if r.returncode != 0:
                    continue
                checked += 1
                assert "RUNPATH" not in r.stdout, f"{p} carries a RUNPATH"
        assert checked > 0, "walked the payload and found no ELF file to check"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_lib_node_registered(self):
        ws = _subos_workspace()
        assert "pocl" in ws and ws["pocl"].get("active"), \
            f"xvm workspace is missing the pocl node (has: {sorted(ws)[:20]})"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_subos_env_carries_ocl_icd_filenames(self):
        """OCL_ICD_FILENAMES, prepended with the payload's own libpocl.so:
        the Khronos loader the ecosystem links enumerates it in addition to
        the vendors directory, so the CPU device is added and the machine's
        own ICDs stay visible. OCL_ICD_VENDORS must NOT appear: it replaces
        the default scan and would hide a real GPU (libs/graphics.lua,
        declare_opencl_icd_library)."""
        r = subprocess.run(
            [os.path.join(xlings_home(), "subos", "current", "bin", "xlings"),
             "subos", "use", "default", "--cmd", "env"],
            capture_output=True, text=True, timeout=30,
        )
        assert r.returncode == 0, f"xlings subos use failed: {r.stderr[:300]}"
        assert not re.search(r"^OCL_ICD_VENDORS=", r.stdout, re.MULTILINE), \
            "OCL_ICD_VENDORS is set in the subos environment; it would hide the host's ICDs"
        m = re.search(r"^OCL_ICD_FILENAMES=(.*)$", r.stdout, re.MULTILINE)
        assert m, f"OCL_ICD_FILENAMES not set in the subos environment:\n{r.stdout[-500:]}"
        libs = m.group(1).split(":")
        assert any(l.endswith("/lib/libpocl.so") and os.path.isfile(l) for l in libs), \
            f"OCL_ICD_FILENAMES={m.group(1)!r} names no existing libpocl.so"
