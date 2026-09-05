"""Tests for the hip-nvidia package -- the HIP API as a header layer over the
CUDA runtime.

The package contains no binaries and no architecture-specific content, which
is the property most of these tests are about: a payload that grew a `lib/`
or a program would mean HIP had stopped being a header layer on this platform,
and the recipe would be describing something else."""
import glob
import os
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "hip-nvidia"
PKG_FILE = "pkgs/h/hip-nvidia.lua"


def _code(content: str) -> str:
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
    def test_one_architecture_independent_resource(self, meta):
        """Headers are the same bytes everywhere, so this recipe declares ONE
        url pair and ONE sha256 -- not a per-arch table with the same digest
        written twice, which would read as two artefacts that happen to
        match."""
        code = _code(meta.raw_content)
        assert re.search(
            r'GLOBAL\s*=\s*"https://github\.com/xlings-res/hip-nvidia/[^"]+noarch\.tar\.gz"', code)
        assert re.search(
            r'CN\s*=\s*"https://gitcode\.com/xlings-res/hip-nvidia/[^"]+noarch\.tar\.gz"', code)
        assert len(re.findall(r'sha256 = "[0-9a-f]{64}"', code)) == 1
        assert "x86_64 = {" not in code and "aarch64 = {" not in code

    @pytest.mark.static
    def test_declares_no_programs(self, meta):
        """No binaries, so nothing goes on PATH. `xvm.add(package.name)` is
        the root the header declaration hangs from, not a program."""
        code = _code(meta.raw_content)
        assert "programs = {" not in code
        assert not re.search(r'xvm\.add\(\s*"', code), \
            "hip-nvidia registers a program name; it publishes no binaries"

    @pytest.mark.static
    def test_declares_headers_as_a_tree(self, meta):
        """declare_headers_tree, not declare_headers: the non-recursive form
        places `include/hip` as one asset, which is a rename(2) over the
        sysroot's copy -- a later package contributing to the same namespace
        would silently replace it."""
        code = _code(meta.raw_content)
        assert "declare_headers_tree" in code
        assert not re.search(r'sysroot\.declare_headers\(', code)

    @pytest.mark.static
    def test_install_checks_both_platform_trees(self, meta):
        """A payload missing nvidia_detail still installs and still has an
        include/hip; it fails at the first #include in a user's build, with a
        message about a file rather than about this package."""
        code = _code(meta.raw_content)
        for required in ("include/hip/hip_runtime.h",
                         "include/hip/hip_version.h",
                         "include/hip/nvidia_detail/nvidia_hip_runtime.h",
                         "include/hip/amd_detail/amd_hip_runtime_pt_api.h"):
            assert required in code, f"install() does not check for {required}"


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
        hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-hip-nvidia", "*")))
        if hits:
            return hits[-1]
    pytest.fail(f"no hip-nvidia payload in the store ({xpkgs_dir()})")


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_headers_present(self):
        inc = os.path.join(_payload_dir(), "include", "hip")
        for rel in ("hip_runtime.h", "hip_version.h",
                    "nvidia_detail/nvidia_hip_runtime.h",
                    "amd_detail/amd_hip_runtime_pt_api.h"):
            assert os.path.isfile(os.path.join(inc, rel)), f"payload is missing hip/{rel}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_payload_carries_no_binaries(self):
        """Header layer, stated as a measurement: no ELF anywhere under the
        payload. If this ever fails, HIP on NVIDIA has stopped being what the
        recipe says it is."""
        for root, _, files in os.walk(_payload_dir()):
            for name in files:
                p = os.path.join(root, name)
                if os.path.islink(p) or not os.path.isfile(p):
                    continue
                with open(p, "rb") as f:
                    assert f.read(4) != b"\x7fELF", f"{p} is an ELF file"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_version_header_matches_the_package_version(self, meta):
        """hip_version.h is generated rather than shipped, so its numbers are
        the one thing in this payload that could disagree with the version the
        index resolves."""
        text = open(os.path.join(_payload_dir(), "include", "hip", "hip_version.h"),
                    encoding="utf-8").read()
        major = re.search(r"#define\s+HIP_VERSION_MAJOR\s+(\d+)", text)
        minor = re.search(r"#define\s+HIP_VERSION_MINOR\s+(\d+)", text)
        assert major and minor, "hip_version.h declares no MAJOR/MINOR"
        installed = os.path.basename(_payload_dir())
        assert installed.startswith(f"{major.group(1)}.{minor.group(1)}."), \
            f"hip_version.h says {major.group(1)}.{minor.group(1)}, payload is {installed}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_dispatch_selects_nvidia(self):
        """The header that decides the platform. Both macros undefined is an
        #error upstream, and this payload exists to make the NVIDIA branch
        reachable."""
        text = open(os.path.join(_payload_dir(), "include", "hip", "hip_runtime.h"),
                    encoding="utf-8").read()
        assert "__HIP_PLATFORM_NVIDIA__" in text
        assert "hip/nvidia_detail/nvidia_hip_runtime.h" in text
