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
        # install now detects/installs VSCode instead of being a no-op (req 1)
        assert 'has_command("code")' in install_hook.group(1)
        assert "system.rundir()" in config_hook.group(1)
        # clangd.path is written from the extracted settings helper
        assert 'settings["clangd.path"]' in meta.raw_content

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_declares_required_deps(self, meta):
        deps = re.search(r"deps\s*=\s*\{([^}]*)\}", meta.raw_content, re.DOTALL)
        assert deps, "missing deps declaration"
        deps_body = deps.group(1)
        # mcpp is the only hard dependency.
        assert re.search(r'["\']xim:mcpp["\']', deps_body), "missing dependency: xim:mcpp"
        # code (req 1) and llvm-tools (req 2) are intentionally NOT pinned as deps.
        assert not re.search(r'["\']xim:code["\']', deps_body), \
            "code must be detected/installed on demand, not pinned as a dep"
        assert "llvm-tools" not in deps_body, \
            "llvm-tools version follows the selected package version, not a dep pin"
        # any declared dep must use the xim namespace
        assert not re.search(r'["\']mcpp["\']', deps_body), \
            "dependency should use xim namespace: mcpp"

    @pytest.mark.static
    def test_uses_package_version_for_llvm_tools(self, meta):
        assert "LLVM_TOOLS_VERSION" not in meta.raw_content
        # clangd/llvm-tools version follows the explicitly selected package version
        assert "pkginfo.version()" in meta.raw_content
        assert 'pkgmanager.install("llvm-tools@" .. ver)' in meta.raw_content
        assert 'pkginfo.dep_install_dir("llvm-tools", ver)' in meta.raw_content
        # the default-toolchain-mutating side effect is gone
        assert "mcpp toolchain install" not in meta.raw_content

    @pytest.mark.static
    def test_supports_windows(self, meta):
        # windows mirrors the linux block: only mcpp is a hard dep, and the
        # version menu offers the same llvm-tools versions.
        windows = re.search(r"windows\s*=\s*\{(.*?)\n        \}", meta.raw_content, re.DOTALL)
        assert windows, "missing windows xpm block"
        windows_body = windows.group(1)
        assert re.search(r'["\']xim:mcpp["\']', windows_body), "windows missing dependency: xim:mcpp"
        assert not re.search(r'["\']xim:code["\']', windows_body)
        assert "llvm-tools" not in windows_body
        assert '["auto"]' in windows_body
        assert '["20.1.7"]' in windows_body
        assert '["22.1.8"]' in windows_body

    @pytest.mark.static
    def test_supports_macosx(self, meta):
        # macosx mirrors the linux block. llvm-tools carries an Apple Silicon
        # (macosx-arm64) bundle carved from the upstream LLVM release.
        macosx = re.search(r"macosx\s*=\s*\{(.*?)\n        \}", meta.raw_content, re.DOTALL)
        assert macosx, "missing macosx xpm block"
        macosx_body = macosx.group(1)
        assert re.search(r'["\']xim:mcpp["\']', macosx_body), "macosx missing dependency: xim:mcpp"
        assert not re.search(r'["\']xim:code["\']', macosx_body)
        assert "llvm-tools" not in macosx_body
        assert '["auto"]' in macosx_body
        assert '["20.1.7"]' in macosx_body
        assert '["22.1.8"]' in macosx_body

    @pytest.mark.static
    def test_clangd_path_is_host_aware(self, meta):
        # clangd binary is `clangd.exe` on windows, `clangd` elsewhere.
        assert 'os.host() == "windows"' in meta.raw_content
        assert '"clangd.exe"' in meta.raw_content

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
        build = meta.raw_content.index('system.exec("mcpp build --no-cache")')
        assert manifest_check < build

    @pytest.mark.static
    def test_enables_clangd_experimental_modules(self, meta):
        assert '"clangd.arguments"' in meta.raw_content
        assert '"--experimental-modules-support"' in meta.raw_content

    @pytest.mark.static
    def test_gates_modules_flag_for_broken_combo(self, meta):
        # issue #393: clangd 20.1.7 on Windows crashes (0xC0000005) with the
        # experimental modules flag; gate it off for that exact combination and
        # strip it from any pre-existing config so affected users self-heal.
        assert "modules_flag_supported" in meta.raw_content
        assert 'os.host() == "windows"' in meta.raw_content
        assert 'ver == "20.1.7"' in meta.raw_content
        assert "remove_flag" in meta.raw_content
        assert "393" in meta.raw_content

    @pytest.mark.static
    def test_installs_vscode_clangd_extension(self, meta):
        assert "code --install-extension " in meta.raw_content
        assert "llvm-vs-code-extensions.vscode-clangd" in meta.raw_content
        # only install when not already present
        assert "has_extension" in meta.raw_content
        assert "code --list-extensions" in meta.raw_content

    @pytest.mark.static
    def test_triggers_mcpp_build(self, meta):
        # build runs first -- it (re)generates compile_commands.json, which
        # clangd needs and which `auto` reads to detect the toolchain -- then
        # llvm-tools is installed for the resolved version.
        build = meta.raw_content.index('system.exec("mcpp build --no-cache")')
        install_tools = meta.raw_content.index('pkgmanager.install("llvm-tools@" .. ver)')
        assert build < install_tools

    @pytest.mark.static
    def test_auto_detects_llvm_from_cdb(self, meta):
        # `latest` -> `auto`: read the compiler from compile_commands.json and
        # match clangd to the project's real LLVM version. Non-clang toolchains
        # (gcc/msvc) are reported and skipped.
        assert 'ref = "auto"' in meta.raw_content
        assert '["auto"]' in meta.raw_content
        assert 'ver == "auto"' in meta.raw_content
        assert "cdb_compiler" in meta.raw_content
        assert "clang_toolchain_version" in meta.raw_content
        assert 'json.loadfile' in meta.raw_content
        # version is parsed straight from the toolchain path, no --version probe
        assert 'xim%-x%-llvm' in meta.raw_content
        assert '"clang version' not in meta.raw_content
        assert "only configures clangd for LLVM projects" in meta.raw_content

    @pytest.mark.static
    def test_removes_cdb_before_build(self, meta):
        remove_cdb = meta.raw_content.index('os.tryrm(path.join(root, "compile_commands.json"))')
        build = meta.raw_content.index('system.exec("mcpp build --no-cache")')
        assert remove_cdb < build

    @pytest.mark.static
    def test_does_not_mutate_tool_homes(self, meta):
        assert "MCPP_HOME" not in meta.raw_content
        assert "XLINGS_HOME" not in meta.raw_content
        assert ".xlings" not in meta.raw_content

    @pytest.mark.static
    def test_install_hook_installs_code_and_extension(self, meta):
        # req 1: install detects VSCode, installs it on demand when missing,
        # and installs the clangd extension.
        hook = re.search(r"function install\(\)(.*?)\nend", meta.raw_content, re.DOTALL)
        assert hook, "missing install hook"
        body = hook.group(1)
        assert 'has_command("code")' in body
        assert 'pkgmanager.install("code")' in body
        assert 'has_extension(' in body
        assert "code --install-extension " in body

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
