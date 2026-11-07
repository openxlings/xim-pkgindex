"""测试 mcpp-ide-nvim 包（Neovim 插件 mcpp-nvim，硬依赖 xim:mcpp-ide；nvim 运行时探测 + pkgmanager 兜底，经 libs/nvim_plugin.lua）"""
import glob
import json
import os
import re
import subprocess

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

PKG = "mcpp-ide-nvim"
PKG_FILE = "pkgs/m/mcpp-ide-nvim.lua"

# 同 test_mcppls_nvim.py：钉住 subos bin，宿主机上自带的 nvim/mcpp-ide 不得应答
SUBOS_BIN = '$HOME/.xlings/subos/current/bin'


def nvim_pack_copy() -> str:
    """config() copies the plugin here: <nvim data>/site/pack/xim/start/mcpp"""
    data = os.environ.get("XDG_DATA_HOME")
    if not data:
        data = os.environ.get("LOCALAPPDATA", "") if os.name == "nt" \
            else os.path.expanduser("~/.local/share")
    return os.path.join(data, "nvim-data" if os.name == "nt" else "nvim",
                        "site", "pack", "xim", "start", "mcpp")


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


def _shim(meta) -> str:
    c = meta.raw_content
    body = c[c.index('function __auto_start_lua()'):]
    return body[body.index('[==[') + 4:body.index(']==]')]


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
        # The backend is the one hard dep, namespaced so the closure resolves
        # even when several indexes provide it. Neovim is deliberately NOT a
        # dep (detected on PATH at install time, with a pkgmanager fallback),
        # and neither is mcppls-nvim: the sibling for C++ files, which the
        # user installs beside this one.
        # (The parser records platforms as bare flags, so scan the recipe text.)
        deps_blocks = re.findall(r'deps\s*=\s*\{([^}]*)\}', meta.raw_content)
        assert len(deps_blocks) == 3, f"expected deps in 3 platform sections, got {len(deps_blocks)}"
        for block in deps_blocks:
            deps = re.findall(r'"([^"]+)"', block)
            assert "xim:mcpp-ide" in deps, f"missing xim:mcpp-ide in: {deps}"
            for d in deps:
                assert d.startswith("xim:"), f"unqualified dep: {d}"
            assert not any("nvim" in d for d in deps), \
                f"Neovim and mcppls-nvim must not be deps: {deps}"

    @pytest.mark.static
    def test_arches_are_where_the_backend_runs(self, meta):
        # pure Lua, declared where xim:mcpp-ide runs, which is where okrun is
        # built (pkgs/o/okrun.lua): Linux on both arches, macOS on aarch64,
        # Windows on x86_64
        import re
        c = meta.raw_content

        def arches(system):
            block = re.search(r'\n        ' + system + r' = \{(.*?)\n        \},', c, re.S).group(1)
            return set(re.findall(r'(aarch64|x86_64) = "', block))

        assert arches('linux') == {'aarch64', 'x86_64'}
        assert arches('macosx') == {'aarch64'}
        assert arches('windows') == {'x86_64'}

    @pytest.mark.static
    def test_recipe_uses_the_lib(self, meta):
        # depend, never copy: the Neovim handling is libs/nvim_plugin.lua's,
        # the same mcppls-nvim calls
        c = meta.raw_content
        assert 'import("xim.pkgindex.nvim_plugin")' in c, "the recipe must import the lib"
        assert 'nvim_plugin.provision()' in c, "install() provisions Neovim through the lib"
        assert 'nvim_plugin.copy_to_pack(pkginfo.install_dir(), "mcpp"' in c, \
            "config() copies into pack/xim/start/mcpp through the lib"
        assert 'nvim_plugin.remove_from_pack("mcpp")' in c, "uninstall() removes through the lib"
        assert 'pkgmanager.install' not in c and 'nvim --version' not in c, \
            "the probe and the fallback live in the lib, not in a recipe copy"

    @pytest.mark.static
    def test_plugin_tree_from_the_tag_archive(self, meta):
        c = meta.raw_content
        assert '"mcpp-ide-" .. pkginfo.version(), "mide-plugins", "nvim"' in c, \
            "install() moves mcpp-ide-<version>/mide-plugins/nvim"
        assert 'archive/refs/tags/v${version}.tar.gz' in c, \
            "GLOBAL is the tag archive (its saved name ends in .tar.gz)"

    @pytest.mark.static
    def test_shim_keeps_a_users_setup(self, meta):
        # init.lua runs before plugin/ files: a module it loaded (its own
        # setup() and options) is left alone, and the opt-out is honoured
        shim = _shim(meta)
        guard = "if vim.g.mcpp_auto_start == false or package.loaded['mcpp'] then"
        assert guard in shim
        assert shim.index(guard) < shim.index("require('mcpp').setup()")
        assert "vim.g.mcpp_auto_start = false" in shim, "the shim names the opt-out"


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
        # pulls xim:mcpp-ide as a dep; Neovim is detected, or installed only
        # when none is on PATH
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_plugin_copy_on_nvim_site(self):
        pack = nvim_pack_copy()
        assert os.path.isfile(os.path.join(pack, "lua", "mcpp", "init.lua")), \
            f"plugin not installed into {pack}"
        assert os.path.isfile(os.path.join(pack, "lua", "mcpp", "session.lua")), \
            f"the session module missing in {pack}"
        assert os.path.isfile(os.path.join(pack, "plugin", "xim-mcpp-auto.lua")), \
            f"auto-start shim missing in {pack}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_plugin_loadable_by_nvim(self):
        # a plain headless run (no --clean): site pack start dirs are on the
        # default runtimepath, so require('mcpp') must answer, and the shim
        # has defined :Mcpp
        assert_command_output(
            f'PATH="{SUBOS_BIN}:$PATH" '
            'nvim --headless \'+lua assert(require("mcpp"), "mcpp not on rtp"); '
            'assert(vim.fn.exists(":Mcpp") == 2, ":Mcpp not defined")\' +qa'
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_backend_shim(self):
        # the plugin finds the backend on PATH; that is the mcpp-ide
        # package's shim, and its presence here closes the loop
        assert_xvm_shim_exists("mcpp-ide")

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
