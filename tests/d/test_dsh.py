"""测试 dsh 包 (DeepSeek Harness)"""
import pathlib
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "dsh"
PKG_FILE = "pkgs/d/dsh.lua"


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
    def test_no_ignore_scripts(self):
        """`--ignore-scripts` must never come back to this recipe.

        node-pty ships prebuilds for darwin/win32 only. On Linux its install
        script (`node scripts/prebuild.js || node-gyp rebuild`) is the ONLY
        thing that produces build/Release/pty.node, and prebuild.js downloads
        nothing — it just checks and exits 1. Skip it and `dsh --version`
        still passes while every profile boot dies on
        `Failed to load native module: pty.node`.

        This is a static guard because the runtime symptom is Linux-only and
        invisible to --version, which is exactly how it shipped once.
        """
        # The header discusses the flag on purpose, so only executable lines
        # are checked — a comment saying "never use --ignore-scripts" must not
        # be what trips the guard.
        code = [ln for ln in pathlib.Path(PKG_FILE).read_text(encoding="utf-8").splitlines()
                if not ln.lstrip().startswith("--")]
        assert "--ignore-scripts" not in "\n".join(code), (
            "npm install must run lifecycle scripts: node-pty has no linux-x64 "
            "prebuild and only its install script builds pty.node"
        )

    @pytest.mark.static
    def test_node_floor_declared(self):
        """Upstream requires `^22.19.0 || >=24.0.0`, and xim:node's 22 line
        tops out at 22.17.1 — below that floor — so >=24 is the only
        satisfiable constraint here, not a rounded-off simplification."""
        body = pathlib.Path(PKG_FILE).read_text(encoding="utf-8")
        assert body.count('"xim:node@>=24"') == 3, (
            "every platform section must pin the node floor upstream declares"
        )


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
    @skip_if_not('linux')
    def test_install(self):
        # ~530 npm packages; openclaw's 300s budget is not enough headroom.
        assert_install_succeeds(PKG, timeout=900)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_dsh_version(self):
        assert_command_output("dsh --version")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_dsh_loads_plugin_tree(self):
        """`--version` is NOT an acceptance test for this package.

        It never loads the plugin tree, so it passes even when the native
        modules the tree needs are missing. `--dump-config` composes the
        whole profile — it is the cheapest command that actually exercises
        what a user hits on `dsh --profile web`.
        """
        assert_command_output("dsh --profile web --dump-config",
                              contains="@deepseek-ai/dsh-base")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_dsh(self):
        assert_xvm_registered("dsh")
