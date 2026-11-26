"""Tests for the atuin package."""
import os
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_valid_xvm_node_kinds,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "atuin"
PKG_FILE = "pkgs/a/atuin.lua"


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
        assert meta.spec == "2"

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_expected_platforms(self, meta):
        assert {"linux", "macosx", "windows"} <= set(meta.platforms)

    @pytest.mark.static
    def test_programs_and_xvm(self, meta):
        assert meta.programs == ["atuin"]
        assert meta.has_xvm_enable is True


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

    @pytest.mark.isolation
    def test_no_direct_pkg_manager(self):
        assert_no_direct_pkg_manager(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("atuin --version", contains="atuin 18.25.1")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("atuin")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_init_and_history_db(self, tmp_path):
        env = {
            **os.environ,
            "HOME": str(tmp_path),
            "XDG_CONFIG_HOME": str(tmp_path / "config"),
            "XDG_DATA_HOME": str(tmp_path / "data"),
            "ATUIN_DB_PATH": str(tmp_path / "data" / "history.db"),
        }
        init_proc = subprocess.run(
            ["bash", "-l", "-c", "atuin init bash"],
            env=env,
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert "__atuin_history" in init_proc.stdout

        stats_proc = subprocess.run(
            [
                "bash", "-l", "-c",
                'export ATUIN_SESSION=$(atuin uuid) && '
                'id=$(atuin history start -- "echo hello-atuin") && '
                'atuin history end --exit 0 "$id" && '
                'atuin search hello-atuin && '
                'atuin stats',
            ],
            env=env,
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        assert "echo hello-atuin" in stats_proc.stdout
        assert "Total commands:   1" in stats_proc.stdout
