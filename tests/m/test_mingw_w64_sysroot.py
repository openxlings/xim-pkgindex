"""Tests for the mingw-w64-sysroot package: the target side of llvm-mingw as an mcpp base package."""
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
from tests.lib.platform_utils import skip_if_not, project_root, xpkgs_dir

PKG = "mingw-w64-sysroot"
PKG_FILE = "pkgs/m/mingw-w64-sysroot.lua"
REQUIRED = [
    "mcpp.toml", "PROVENANCE.md", "include/windows.h", "include/c++/v1/__config_site",
    "x86_64-w64-mingw32/lib/crt2.o", "x86_64-w64-mingw32/lib/libc++.a",
    "aarch64-w64-mingw32/lib/crt2.o", "aarch64-w64-mingw32/lib/libc++.a",
    "compiler-rt/lib/windows/libclang_rt.builtins-x86_64.a",
    "compiler-rt/lib/windows/libclang_rt.builtins-aarch64.a",
]


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def source_text():
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


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
    def test_one_hash_for_every_host(self, source_text):
        """The payload is target code: every host takes the same archive."""
        hashes = set(re.findall(r'sha256 = "([0-9a-f]{64})"', source_text))
        assert len(hashes) == 1, f"one sha256 for every host expected, found {len(hashes)}"
        assert source_text.count("sha256 =") == 3, "one entry each for linux, macosx, windows"

    @pytest.mark.static
    def test_target_files_do_not_enter_the_host_sysroot(self, source_text):
        """Target headers in the subos sysroot would shadow the host's C library."""
        assert "subos_sysrootdir" not in source_text
        assert "xvm.files" not in source_text

    @pytest.mark.static
    def test_no_auto_update_or_self_mirror(self, source_text):
        assert "mirror = true" not in source_text
        assert "update = true" not in source_text


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


def _root():
    roots = [d for d in os.listdir(xpkgs_dir()) if d.endswith("-x-" + PKG)]
    assert roots, "the payload did not land"
    base = os.path.join(xpkgs_dir(), roots[0])
    return os.path.join(base, sorted(os.listdir(base))[-1])


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_every_architecture_is_complete(self):
        root = _root()
        for name in REQUIRED:
            assert os.path.isfile(os.path.join(root, name)), f"missing {name}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_the_manifest_states_the_layers(self):
        """The package root is the sysroot; mcpp reads `provides` and `[build]`, paths from the root."""
        import tomllib
        root = _root()
        with open(os.path.join(root, "mcpp.toml"), "rb") as f:
            doc = tomllib.load(f)
        assert any(p.startswith("mcpp:c-abi=") for p in doc["package"]["provides"])
        build = doc["build"]
        for key in ("std-module", "std-compat-module"):
            assert os.path.isfile(os.path.join(root, build[key])), f"no {key}"
        for d in build["include_dirs"]:
            assert os.path.isdir(os.path.join(root, d)), f"no include dir {d}"
