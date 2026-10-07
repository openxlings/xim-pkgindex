"""测试 mcppls-nvim 包（Neovim 插件，依赖 xim:mcppls + xim:nvim）"""
import glob
import json
import os
import subprocess
import tempfile

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
from tests.lib.platform_utils import skip_if_not, xlings_home

PKG = "mcppls-nvim"
PKG_FILE = "pkgs/n/mcppls-nvim.lua"

# 同 test_mcppls.py：钉住 subos bin，宿主机上自带的旧 mcppls/nvim 不得应答
SUBOS_BIN = '$HOME/.xlings/subos/current/bin'


def nvim_pack_copy() -> str:
    """config() copies the plugin here: <nvim data>/site/pack/xim/start/mcppls"""
    if os.name == "nt":
        data = os.path.join(os.environ.get("LOCALAPPDATA", ""), "nvim-data")
    else:
        data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(data, "nvim", "site", "pack", "xim", "start", "mcppls")


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
        for plat in ("linux", "macosx", "windows"):
            assert_platform_supported(meta, plat)

    @pytest.mark.static
    def test_deps_qualified(self, meta):
        # The plugin needs the server and an editor; both must be namespaced
        # deps so the closure resolves even when several indexes provide them.
        # (The parser records platforms as bare flags, so scan the recipe text.)
        import re
        deps_blocks = re.findall(r'deps\s*=\s*\{([^}]*)\}', meta.raw_content)
        assert len(deps_blocks) == 3, f"expected deps in 3 platform sections, got {len(deps_blocks)}"
        for block in deps_blocks:
            deps = re.findall(r'"([^"]+)"', block)
            assert "xim:mcppls" in deps, f"missing xim:mcppls in: {deps}"
            assert any(d.startswith("xim:nvim@") for d in deps), \
                f"missing xim:nvim@>=... in: {deps}"
            for d in deps:
                assert d.startswith("xim:"), f"unqualified dep: {d}"


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
        # the group placeholder is the sanctioned kind for a package that
        # ships no program of its own
        assert_valid_xvm_node_kinds(meta)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        # pulls xim:nvim and xim:mcppls as deps on a fresh home
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_deps_alive(self):
        assert_command_output(
            f'PATH="{SUBOS_BIN}:$PATH" nvim --version | head -1', contains="NVIM"
        )
        assert_command_output(
            f'PATH="{SUBOS_BIN}:$PATH" mcppls --version', contains="0.0.11"
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_plugin_copy_on_nvim_site(self):
        pack = nvim_pack_copy()
        assert os.path.isfile(os.path.join(pack, "lua", "mcppls", "init.lua")), \
            f"plugin not installed into {pack}"
        assert os.path.isfile(os.path.join(pack, "lsp", "mcppls.lua")), \
            f"nvim-0.11 lsp config missing in {pack}"
        assert os.path.isfile(os.path.join(pack, "plugin", "xim-mcppls-auto.lua")), \
            f"auto-start shim missing in {pack}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_auto_start_without_setup(self):
        # the whole point of the xim packaging: NO init.lua, NO explicit
        # setup() — opening a C++ buffer alone must attach the server
        with tempfile.TemporaryDirectory() as td:
            cpp = os.path.join(td, "main.cpp")
            with open(cpp, "w") as f:
                f.write("int main() { return 0; }\n")
            lua = ("vim.wait(30000, function() "
                   "local get = vim.lsp.get_clients or vim.lsp.get_active_clients; "
                   "return #(get({bufnr = 0, name = [[mcppls]]})) > 0 end, 200)")
            cmd = (f'PATH="{SUBOS_BIN}:$PATH" nvim --headless {cpp} '
                   f'"+lua assert({lua}, \'mcppls did not auto-attach\')" +qa')
            assert_command_output(cmd)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_plugin_loadable_by_nvim(self):
        # a plain headless run (no --clean): site pack start dirs are on the
        # default runtimepath, so require('mcppls') must answer
        assert_command_output(
            f'PATH="{SUBOS_BIN}:$PATH" '
            'nvim --headless \'+lua assert(require("mcppls"), "mcppls not on rtp")\' +qa'
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_server_shim(self):
        # the plugin finds the server on PATH; that is the mcppls package's
        # shim, and its presence here closes the loop
        assert_xvm_shim_exists("mcppls")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_group_node_registered(self, meta):
        # type = "group" registers the package name without a shim (no
        # program behind it), so the check reads the subos registry; a home
        # with no such registry file is an older layout — skip, not fail.
        registries = glob.glob(os.path.join(xlings_home(), "subos", "*", ".xlings.json"))
        if not registries:
            pytest.skip("no subos .xlings.json registry on this xlings layout")
        found = []
        for r in registries:
            with open(r, encoding="utf-8") as f:
                reg = json.load(f)
            ws = (reg.get("workspace") or {}).get(PKG)
            if ws:
                found.append((r, ws))
        assert found, f"group node '{PKG}' not in any subos workspace registry"


class TestUninstall:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_uninstall(self):
        # -y: a non-interactive shell has nobody to ask (xlings refuses
        # otherwise); XlingsClient.remove feeds stdin, which xlings ignores
        r = subprocess.run(
            ["bash", "-l", "-c", f"xlings remove {PKG} -y"],
            capture_output=True, text=True, timeout=120,
        )
        assert r.returncode == 0, f"uninstall failed: {(r.stdout + r.stderr)[-300:]}"

    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_no_plugin_residue(self):
        assert not os.path.exists(nvim_pack_copy()), \
            f"plugin copy left behind: {nvim_pack_copy()}"
