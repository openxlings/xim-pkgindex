"""测试 mcpp-vscode-clangd 配置包"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)

PKG_FILE = "pkgs/m/mcpp-vscode-clangd.lua"


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
    def test_is_config_package(self, meta):
        assert meta.pkg_type == "config"

    @pytest.mark.static
    def test_name_is_clangd_specific(self, meta):
        assert meta.name == "mcpp-vscode-clangd"

    @pytest.mark.static
    def test_lifecycle_hooks_use_config(self, meta):
        assert not meta.has_installed
        assert meta.has_install
        assert meta.has_config

        install_hook = re.search(r"function install\(\)(.*?)\nend", meta.raw_content, re.DOTALL)
        config_hook = re.search(r"function config\(\)(.*?)\nend", meta.raw_content, re.DOTALL)
        assert install_hook, "missing install hook"
        assert config_hook, "missing config hook"
        assert install_hook.group(1).strip() == "return true"
        assert "system.rundir()" in config_hook.group(1)
        assert 'settings["clangd.path"]' in config_hook.group(1)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_declares_required_deps(self, meta):
        deps = re.search(r"deps\s*=\s*\{([^}]*)\}", meta.raw_content, re.DOTALL)
        assert deps, "missing deps declaration"
        deps_body = deps.group(1)
        for dep in ("xim:mcpp", "xim:code", "xim:llvm-tools@20.1.7"):
            assert re.search(rf'["\']{re.escape(dep)}["\']', deps_body), \
                f"missing dependency: {dep}"
        for dep in ("mcpp", "code", "llvm-tools@20.1.7"):
            assert not re.search(rf'["\']{re.escape(dep)}["\']', deps_body), \
                f"dependency should use xim namespace: {dep}"

    @pytest.mark.static
    def test_uses_package_version_for_llvm_tools(self, meta):
        assert "LLVM_TOOLS_VERSION" not in meta.raw_content
        assert 'pkginfo.dep_install_dir("llvm-tools", pkginfo.version())' in meta.raw_content
        assert 'mcpp toolchain install llvm@" .. pkginfo.version() .. " default' in meta.raw_content

    @pytest.mark.static
    def test_configures_clangd_path_only(self, meta):
        assert '"clangd.path"' in meta.raw_content
        assert "compile-commands-dir" not in meta.raw_content
        assert "files.associations" not in meta.raw_content

    @pytest.mark.static
    def test_uses_system_rundir(self, meta):
        assert 'import("xim.libxpkg.system")' in meta.raw_content
        assert "system.rundir()" in meta.raw_content

    @pytest.mark.static
    def test_skips_when_mcpp_manifest_missing(self, meta):
        assert 'import("xim.libxpkg.log")' in meta.raw_content
        assert 'os.isfile(path.join(root, "mcpp.toml"))' in meta.raw_content
        assert 'log.warn(' in meta.raw_content
        assert "mcpp-vscode-clangd skipped" in meta.raw_content
        manifest_check = meta.raw_content.index('os.isfile(path.join(root, "mcpp.toml"))')
        settings_update = meta.raw_content.index('settings["clangd.path"]')
        assert manifest_check < settings_update

    @pytest.mark.static
    def test_enables_clangd_experimental_modules(self, meta):
        assert '"clangd.arguments"' in meta.raw_content
        assert '"--experimental-modules-support"' in meta.raw_content

    @pytest.mark.static
    def test_installs_vscode_clangd_extension(self, meta):
        assert "code --install-extension llvm-vs-code-extensions.vscode-clangd" in meta.raw_content

    @pytest.mark.static
    def test_triggers_mcpp_build(self, meta):
        toolchain_install = meta.raw_content.index('mcpp toolchain install llvm@" .. pkginfo.version() .. " default')
        build = meta.raw_content.index("mcpp build")
        assert toolchain_install < build

    @pytest.mark.static
    def test_removes_cdb_before_build(self, meta):
        remove_cdb = meta.raw_content.index('os.tryrm(path.join(root, "compile_commands.json"))')
        build = meta.raw_content.index("mcpp build")
        assert remove_cdb < build

    @pytest.mark.static
    def test_does_not_mutate_tool_homes(self, meta):
        assert "MCPP_HOME" not in meta.raw_content
        assert "XLINGS_HOME" not in meta.raw_content
        assert ".xlings" not in meta.raw_content

    @pytest.mark.static
    def test_install_hook_stays_small(self, meta):
        hook = re.search(r"function install\(\)(.*?)\nend", meta.raw_content, re.DOTALL)
        assert hook, "missing install hook"
        lines = [line for line in hook.group(1).splitlines() if line.strip()]
        assert len(lines) == 1

    @pytest.mark.static
    def test_no_custom_project_dir_helpers(self, meta):
        assert "shell_quote" not in meta.raw_content
        assert "read_file" not in meta.raw_content
        assert "project_dir" not in meta.raw_content
        assert "ensure_mcpp_project" not in meta.raw_content


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
