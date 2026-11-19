"""gdb: GNU gdb and gdbserver, static, built by this index's factory
(tools/res/build.sh gdb)."""
import json
import os
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import project_root, skip_if_not, under_test

PKG = "gdb"
PKG_FILE = "pkgs/g/gdb.lua"


def read(rel):
    with open(os.path.join(project_root(), rel), encoding="utf-8") as handle:
        return handle.read()


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def source():
    return read(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_recipe_shape(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_both_architectures_from_the_factory(self, source):
        assert 'url = "XLINGS_RES"' in source
        for arch in ("x86_64", "aarch64"):
            assert re.search(arch + r' = "[0-9a-f]{64}"', source), arch

    @pytest.mark.static
    def test_gdb_and_gdbserver_with_their_terminfo(self, source):
        for prog in ("gdb", "gdbserver"):
            assert f'"{prog}"' in source, prog
        assert "TERMINFO_DIRS" in source

    @pytest.mark.static
    def test_the_factory_builds_and_checks_it(self):
        build = read("tools/res/build.sh")
        assert "\ngdb)" in build
        assert 'static_only "$work/$d/bin/gdb" "$work/$d/bin/gdbserver"' in build
        assert "show data-directory" in build
        assert re.search(r"^gdb 18\.1 [0-9a-f]{64}$", read("tools/res/inputs.txt"), re.M)
        matrix = json.loads(read(".github/res-build-matrix.json"))
        assert {e["arch"] for e in matrix if e["what"] == "gdb" and e["version"] == "18.1"} == {"x86_64", "aarch64"}


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
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_gdb(self):
        assert_command_output("gdb --version", contains="GNU gdb (GDB) 18.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_gdbserver(self):
        assert_command_output("gdbserver --version", contains="GNU gdbserver (GDB) 18.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("gdb")
        assert_xvm_registered("gdbserver")
