"""Tests for zhefeng:arm-none-eabi-gcc (GCC + binutils for bare-metal Arm, no C library)."""
import os
import re
import subprocess

import pytest

from tests.lib.assertions import (
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_xim_add_succeeds,
    assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, subos_bin_dir
from tests.lib.xpkg_parser import parse_xpkg

NAMESPACE = "zhefeng"
NAME = "arm-none-eabi-gcc"
VERSION = "14.2.0"
PKG = f"{NAMESPACE}:{NAME}@{VERSION}"
PKG_FILE = "pkgs/a/arm-none-eabi-gcc.lua"
RELEASE = ("https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/"
           "arm-none-eabi-gcc-14.2.0-r1/")

# The published payloads of revision 1, one per host.
ASSETS = {
    "arm-none-eabi-gcc-14.2.0-r1-linux-x86_64.tar.gz":
        "b50f2f9b7662492addc76b15539a6e79090b88fc839f4a777e7196e64fe42cc1",
    "arm-none-eabi-gcc-14.2.0-r1-linux-aarch64.tar.gz":
        "4ba0531c3c9140c1679107a60bafb4467b1f3940460a9b9130d892b1bcbe47b7",
    "arm-none-eabi-gcc-14.2.0-r1-windows-x86_64.zip":
        "0e46c7b914d43ad4e9466f930f7fc3b67ca298402234a71eb2cab0428381b830",
    "arm-none-eabi-gcc-14.2.0-r1-macosx-aarch64.tar.gz":
        "5d569219739266262359ce9cf1bb3a88458796d6b91c8eb84d223b957151f8c1",
}


@pytest.fixture(scope="module")
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
    def test_personal_packaging_is_namespaced(self, meta):
        """Built from source and hosted on a personal repository: not an xim: package."""
        assert meta.namespace == NAMESPACE
        assert 'source = "xlings-res"' not in meta.raw_content
        assert "ci = { mirror = true }" in meta.raw_content

    @pytest.mark.static
    def test_every_program_is_target_prefixed(self, meta):
        """A bare gcc/ld/as would shadow the host toolchain."""
        assert meta.programs
        for prog in meta.programs:
            assert prog.startswith("arm-none-eabi-"), f"{prog} has no target prefix"

    @pytest.mark.static
    def test_release_assets_are_pinned(self, meta):
        source = meta.raw_content
        assert source.count(f'["latest"] = {{ ref = "{VERSION}" }}') == 3
        for asset, sha256 in ASSETS.items():
            assert source.count(f'url = "{RELEASE}{asset}"') == 1, asset
            assert source.count(f'sha256 = "{sha256}"') == 1, asset

    @pytest.mark.static
    def test_revision_one_everywhere(self, meta):
        """Revision 1 is the first build a C/C++ library sysroot works with."""
        source = meta.raw_content
        assert len(re.findall(r"revision = 1,\s*floor = 1,", source)) == 3

    @pytest.mark.static
    def test_no_c_library_in_the_compiler(self, meta):
        """C libraries and libstdc++ are packages of their own, selected with --sysroot."""
        source = meta.raw_content
        dep = re.search(r'"[\w.-]+:(newlib|picolibc|libstdcxx)', source)
        assert dep is None, f"the compiler must not depend on {dep and dep.group(1)}"
        assert "subos_sysrootdir" not in source, "target headers/libraries never enter the SubOS sysroot"

    @pytest.mark.static
    def test_linux_payload_declares_glibc(self, meta):
        """The Linux host programs need libc, libm and the loader alone (measured)."""
        assert '"xim:glibc@>=2.39"' in meta.raw_content


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
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(PKG, timeout=900)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_shims(self, meta):
        for prog in ("arm-none-eabi-gcc", "arm-none-eabi-g++", "arm-none-eabi-ld",
                     "arm-none-eabi-objcopy"):
            assert_xvm_shim_exists(prog)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_freestanding_link(self, tmp_path):
        """Without a C library only freestanding code links, with libgcc."""
        gcc = os.path.join(subos_bin_dir(), "arm-none-eabi-gcc")
        out = subprocess.run([gcc, "--version"], capture_output=True, text=True, timeout=30)
        assert out.returncode == 0 and VERSION in out.stdout, out.stdout + out.stderr
        src = tmp_path / "div.c"
        src.write_text("int div(int a, int b) { return a / b; }\n")
        elf = tmp_path / "div.elf"
        r = subprocess.run([gcc, "-mcpu=cortex-m0", "-mthumb", "-nostdlib", "-Wl,-e,div",
                            str(src), "-lgcc", "-o", str(elf)],
                           capture_output=True, text=True, timeout=60)
        assert r.returncode == 0, r.stderr
        assert elf.is_file()
