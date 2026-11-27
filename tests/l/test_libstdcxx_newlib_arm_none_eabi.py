"""Tests for ZheFeng7110:libstdcxx-newlib-arm-none-eabi (newlib sysroot + libstdc++ of GCC 14.2.0)."""
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
NAME = "libstdcxx-newlib-arm-none-eabi"
VERSION = "14.2.0"
PKG = f"{NAMESPACE}:{NAME}@{VERSION}"
PKG_FILE = "pkgs/l/libstdcxx-newlib-arm-none-eabi.lua"
GCC_FILE = "pkgs/a/arm-none-eabi-gcc.lua"
SHA256 = "ead19549a73a9c6f27bbaed61db0464eccf9c99d21d3088bb00450d76688aae4"

# `nano.specs` maps -lstdc++ to -lstdc++_nano (and -lsupc++ likewise).
CXX_NAMES = ["libstdc++.a", "libsupc++.a", "libstdc++_nano.a", "libsupc++_nano.a"]


def read(rel):
    with open(os.path.join(project_root(), rel), encoding="utf-8") as handle:
        return handle.read()


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
        source = meta.raw_content
        for os_name in ("linux", "macosx", "windows"):
            assert f"{os_name} = versions," in source, f"{os_name} does not use the shared table"
        assert source.count(f'sha256 = "{SHA256}"') == 1

    @pytest.mark.static
    def test_version_is_the_compilers(self, meta):
        """libstdc++ is part of GCC: its version is arm-none-eabi-gcc's."""
        gcc_latest = re.search(r'\["latest"\] = \{ ref = "([^"]+)" \}', read(GCC_FILE)).group(1)
        assert f'["latest"] = {{ ref = "{gcc_latest}" }}' in meta.raw_content
        assert VERSION == gcc_latest

    @pytest.mark.static
    def test_install_asserts_cxx_libraries(self, meta):
        source = meta.raw_content
        for name in CXX_NAMES:
            assert f'"{name}"' in source, f"install() does not check {name}"
        assert "c++config.h" in source

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
        assert_install_succeeds(PKG, timeout=900)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_cxx_link_takes_nano_with_nano_specs(self, tmp_path):
        gxx = os.path.join(subos_bin_dir(), "arm-none-eabi-g++")
        if not os.path.exists(gxx):
            pytest.skip("ZheFeng7110:arm-none-eabi-gcc is not installed in this home")
        sysroot = os.path.join(xpkgs_dir(), f"{NAMESPACE}-x-{NAME}", VERSION, "arm-none-eabi")
        src = tmp_path / "hello.cc"
        src.write_text("#include <vector>\n#include <string>\n#include <cstdio>\n"
                       "int main() { std::vector<std::string> v{\"a\", \"b\"};"
                       " std::printf(\"%zu\\n\", v.size()); return 0; }\n")
        m4 = ["-mcpu=cortex-m4", "-mthumb", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard"]
        for extra, want in ((["--specs=nano.specs", "-fno-exceptions"], "libstdc++_nano.a"),
                            ([], "libstdc++.a")):
            r = subprocess.run([gxx, f"--sysroot={sysroot}", *m4, *extra, "--specs=nosys.specs",
                                str(src), "-o", str(tmp_path / "a.elf"), "-Wl,--trace"],
                               capture_output=True, text=True, timeout=180)
            assert r.returncode == 0, r.stderr
            assert os.path.join(sysroot, "lib", "thumb/v7e-m+fp/hard", want) in r.stdout, r.stdout
