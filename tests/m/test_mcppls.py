"""测试 mcppls 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_platform_supported, assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not

PKG = "mcppls"
PKG_FILE = "pkgs/m/mcppls.lua"

# The xvm shim must win over whatever else the host has on PATH: a developer
# machine can carry its own older `mcppls` wrapper (e.g. ~/.local/bin) that
# would otherwise answer the version probe instead of the installed payload.
SUBOS_BIN = '$HOME/.xlings/subos/current/bin'


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
    def test_platforms(self, meta):
        # linux (x86_64/aarch64), macosx (aarch64), windows (x86_64)
        for plat in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, plat)


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
    def test_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_mcppls_version(self):
        assert_command_output(
            f'PATH="{SUBOS_BIN}:$PATH" mcppls --version', contains="0.0.11"
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_shim(self):
        assert_xvm_shim_exists("mcppls")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_payload_complete(self):
        # one file per payload inside the tarball: server / clangd / kit
        import glob
        import os
        from tests.lib.platform_utils import xpkgs_dir
        hits = glob.glob(os.path.join(xpkgs_dir(), "*-x-mcppls", "*"))
        assert hits, "mcppls install dir not found under xpkgs"
        d = hits[0]
        for rel in ("bin/mcppls", "clangd/bin/clangd", "kit/kit.json"):
            assert os.path.isfile(os.path.join(d, rel)), f"payload file missing: {rel}"


class TestUninstall:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_uninstall(self):
        # -y: a non-interactive shell has nobody to ask (xlings refuses
        # otherwise); XlingsClient.remove feeds stdin, which xlings ignores.
        # mcppls-nvim (its only dependent) is removed first if present — this
        # suite may run after the mcppls-nvim one, and xlings refuses to
        # remove a package another installed package pins.
        import subprocess
        subprocess.run(
            ["bash", "-l", "-c", "xlings remove mcppls-nvim -y"],
            capture_output=True, text=True, timeout=120,
        )
        r = subprocess.run(
            ["bash", "-l", "-c", f"xlings remove {PKG} -y"],
            capture_output=True, text=True, timeout=120,
        )
        assert r.returncode == 0, f"uninstall failed: {(r.stdout + r.stderr)[-300:]}"

    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_shim_removed(self):
        import os
        from tests.lib.platform_utils import subos_bin_dir
        assert not os.path.exists(os.path.join(subos_bin_dir(), "mcppls")), \
            "xvm shim left behind after uninstall"
