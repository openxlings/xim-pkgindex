"""Tests for ZheFeng7110:newlib-arm-none-eabi (newlib + newlib-nano sysroot for arm-none-eabi-gcc)."""
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
)
from tests.lib.platform_utils import project_root, skip_if_not, subos_bin_dir, xpkgs_dir
from tests.lib.xpkg_parser import parse_xpkg

NAMESPACE = "ZheFeng7110"
NAME = "newlib-arm-none-eabi"
VERSION = "4.5.0.20241231"
PKG = f"{NAMESPACE}:{NAME}@{VERSION}"
PKG_FILE = "pkgs/n/newlib-arm-none-eabi.lua"
LIBSTDCXX_FILE = "pkgs/l/libstdcxx-newlib-arm-none-eabi.lua"
SHA256 = "dc5fb47392f89fdd5afa6d734c352cbe1a1d7628ce745e3208d7718e2ec3bc19"

# Arm GNU Toolchain's names: a project generated for it (STM32CubeMX:
# `--specs=nano.specs --specs=nosys.specs`) needs every one of them.
NANO_NAMES = ["libc_nano.a", "libg_nano.a", "librdimon_nano.a"]
SPECS = ["nano.specs", "nosys.specs", "rdimon.specs"]


def read(rel):
    with open(os.path.join(project_root(), rel), encoding="utf-8") as handle:
        return handle.read()


def multilibs(source):
    body = re.search(r"local multilibs = \{(.*?)\n\}", source, re.S).group(1)
    return re.findall(r'"([^"]+)"', body)


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
        assert meta.namespace == NAMESPACE
        assert 'source = "xlings-res"' not in meta.raw_content
        assert "ci = { mirror = true }" in meta.raw_content

    @pytest.mark.static
    def test_one_payload_for_every_host(self, meta):
        """Target code: one archive, one sha256, one version table for every host."""
        source = meta.raw_content
        for os_name in ("linux", "macosx", "windows"):
            assert f"{os_name} = versions," in source, f"{os_name} does not use the shared table"
        assert source.count(f'sha256 = "{SHA256}"') == 1
        assert f'["latest"] = {{ ref = "{VERSION}" }}' in source

    @pytest.mark.static
    def test_multilibs_are_rmprofile(self, meta):
        """The rows of arm-none-eabi-gcc's -print-multi-lib (rmprofile), `.` first."""
        rows = multilibs(meta.raw_content)
        assert rows[0] == "."
        assert len(rows) == 29 and len(set(rows)) == 29
        for row in ("thumb/v6-m/nofp", "thumb/v7-m/nofp", "thumb/v7e-m+fp/hard",
                    "thumb/v7e-m+fp/softfp", "thumb/v8-m.main+fp/hard"):
            assert row in rows, f"multilib table lacks {row}"

    @pytest.mark.static
    def test_same_multilibs_as_libstdcxx(self, meta):
        """Both sysroots serve the same compiler: their rows must agree."""
        assert multilibs(meta.raw_content) == multilibs(read(LIBSTDCXX_FILE))

    @pytest.mark.static
    def test_install_asserts_arm_toolchain_names(self, meta):
        source = meta.raw_content
        for name in NANO_NAMES:
            assert f'"{name}"' in source, f"install() does not check {name}"
        for specs in SPECS:
            assert f'"lib/{specs}"' in source, f"install() does not check {specs}"

    @pytest.mark.static
    def test_target_headers_do_not_enter_the_host_sysroot(self, meta):
        assert "subos_sysrootdir" not in meta.raw_content
        assert "xvm.add(package.name)" in meta.raw_content


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
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_cubemx_style_link_picks_the_multilib(self, tmp_path):
        """`--specs=nano.specs --specs=nosys.specs` takes the right row's libc_nano.a."""
        gcc = os.path.join(subos_bin_dir(), "arm-none-eabi-gcc")
        if not os.path.exists(gcc):
            pytest.skip("ZheFeng7110:arm-none-eabi-gcc is not installed in this home")
        sysroot = os.path.join(xpkgs_dir(), f"{NAMESPACE}-x-{NAME}", VERSION, "arm-none-eabi")
        src = tmp_path / "hello.c"
        src.write_text('#include <stdio.h>\n#include <limits.h>\n'
                       'int main(void) { printf("%d\\n", PATH_MAX); return 0; }\n')
        cases = {
            ("-mcpu=cortex-m0", "-mthumb"): "thumb/v6-m/nofp/libc_nano.a",
            ("-mcpu=cortex-m4", "-mthumb", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard"):
                "thumb/v7e-m+fp/hard/libc_nano.a",
        }
        for flags, want in cases.items():
            r = subprocess.run([gcc, f"--sysroot={sysroot}", *flags, "--specs=nano.specs",
                                "--specs=nosys.specs", str(src), "-o", str(tmp_path / "a.elf"),
                                "-Wl,--trace"], capture_output=True, text=True, timeout=120)
            assert r.returncode == 0, r.stderr
            assert os.path.join(sysroot, "lib", want) in r.stdout, r.stdout
