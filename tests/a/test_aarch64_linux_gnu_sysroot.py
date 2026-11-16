"""Tests for the aarch64-linux-gnu-sysroot package: glibc for arm64 as an mcpp base package."""
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
from tests.lib.base_package import assert_base_package, provided
from tests.lib.platform_utils import skip_if_not, project_root, xpkgs_dir

PKG = "aarch64-linux-gnu-sysroot"
PKG_FILE = "pkgs/a/aarch64-linux-gnu-sysroot.lua"
# What a C link, a C++ link and `import std` each read first.
REQUIRED = [
    "mcpp.toml", "PROVENANCE.md",
    "include/features.h", "include/linux/limits.h",
    "include/c++/v1/vector", "include/aarch64-unknown-linux-gnu/c++/v1/__config_site",
    "lib/crt1.o", "lib/Scrt1.o", "lib/libc.so.6", "lib/libc.a", "lib/libm.so.6", "lib/libm-2.44.a",
    "lib/ld-linux-aarch64.so.1",
    "lib/libc++.so", "lib/libc++.so.1", "lib/libc++.a", "lib/libc++abi.so.1", "lib/libc++abi.a",
    "lib/libunwind.so.1", "lib/libunwind.a",
    "lib/clang/23/lib/aarch64-unknown-linux-gnu/libclang_rt.builtins.a",
    "share/libc++/v1/std.cppm", "share/libc++/v1/std.compat.cppm",
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
    def test_one_archive_for_every_host(self, source_text):
        """The payload is target code: every host takes the same archive at the same revision."""
        hashes = set(re.findall(r'sha256 = "([0-9a-f]{64})"', source_text))
        assert len(hashes) == 1, f"one sha256 for every host expected, found {len(hashes)}"
        revisions = re.findall(r"revision = (\d+)", source_text)
        assert len(revisions) == 3 and len(set(revisions)) == 1, "one revision, stated for each host"

    @pytest.mark.static
    def test_the_archive_is_named_by_its_revision(self, source_text):
        """The asset's file name carries the revision the entry states, on both mirrors: the
        installer takes the archive's top directory by that name."""
        revision = re.findall(r"revision = (\d+)", source_text)[0]
        urls = re.findall(r'"(https://[^"]+\.tar\.xz)"', source_text)
        pinned = [u for u in urls if "${version}" not in u]
        assert len(pinned) == 6, "GLOBAL and CN for each of the three hosts"
        for url in pinned:
            assert url.endswith(f"-r{revision}.tar.xz"), url
            assert f"/download/2.44.3-r{revision}/" in url, url

    @pytest.mark.static
    def test_target_files_do_not_enter_the_host_sysroot(self, source_text):
        """Target headers in the subos sysroot would shadow the host's C library."""
        assert "subos_sysrootdir" not in source_text
        assert "xvm.files" not in source_text


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
    def test_what_each_link_reads_is_there(self):
        root = _root()
        for name in REQUIRED:
            assert os.path.exists(os.path.join(root, name)), f"missing {name}"

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_the_layout_contract_of_a_base_package(self):
        doc = assert_base_package(_root())
        layers = provided(doc)
        assert layers["c-abi"] == "glibc"
        assert layers["c++-abi"] == "libc++"
        # The run-time the link takes: compiler-rt's builtins, where
        # `compiler_runtime_dir` says they stand.
        assert layers["compiler-runtime"] == "compiler-rt"
