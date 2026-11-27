"""测试 mcpp 包"""
import re
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "mcpp"
INSTALL_VERSION = "0.0.56"
PKG_FILE = "pkgs/m/mcpp.lua"


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
    def test_latest_names_every_architecture(self, meta):
        # The latest target covers every architecture of its platform with a
        # checksum. Two spellings occur: the legacy `url = "XLINGS_RES"`
        # sentinel with a per-architecture sha256 table, and the entry the
        # unified updater writes (#1027), one table per architecture with its
        # GLOBAL and CN url and its sha256.
        def platform_block(platform, next_marker):
            start = meta.raw_content.index(f"        {platform} = {{", meta.raw_content.index("    xpm = {"))
            end = meta.raw_content.index(next_marker, start)
            return meta.raw_content[start:end]

        platforms = (
            ("linux", "        macosx = {", {"x86_64", "aarch64"}),
            ("macosx", "        windows = {", {"aarch64"}),
            ("windows", "\n        },\n    },", {"x86_64"}),
        )
        for platform, next_marker, expected_arches in platforms:
            block = platform_block(platform, next_marker)
            m = re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([0-9.]+)"\s*\}', block)
            assert m, f"no `latest` ref in {platform} block"
            latest = m.group(1)
            entry_start = block.index(f'["{latest}"]', m.end())
            next_entry = re.search(r'\n\s*\["[0-9.]+' + r'"\]\s*=', block[entry_start + 1:])
            entry_end = (entry_start + 1 + next_entry.start()) if next_entry else len(block)
            entry = block[entry_start:entry_end]
            if re.search(r'url\s*=\s*"XLINGS_RES"', entry):
                hashes = {
                    arch: digest.lower()
                    for arch, digest in re.findall(
                        r'\b(x86_64|aarch64)\s*=\s*"([0-9a-fA-F]{64})"', entry)
                }
                assert set(hashes) == expected_arches, f"{platform}: {latest}"
                continue
            arches = re.findall(r'\b(x86_64|aarch64)\s*=\s*\{', entry)
            assert set(arches) == expected_arches, f"{platform}: {latest}"
            for arch in expected_arches:
                part = entry[entry.index(f"{arch} = {{"):]
                part = part[:part.index("sha256")+80]
                assert re.search(r'GLOBAL\s*=\s*"https://github\.com/xlings-res/mcpp/releases/download/', part), arch
                assert re.search(r'CN\s*=\s*"https://gitcode\.com/xlings-res/mcpp/releases/download/', part), arch
                assert re.search(r'sha256\s*=\s*"[0-9a-f]{64}"', part), arch

        assert re.search(r'\bxpm\s*=\s*\{\s*source\s*=\s*"xlings-res"', meta.raw_content)

    @pytest.mark.static
    def test_install_uses_runtime_dir(self, meta):
        assert "path.directory(archive)" in meta.raw_content
        assert "path.filename(mcpp_dir)" in meta.raw_content


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


def _active_code():
    """去掉 `--` 行注释后的配方正文。

    注释可以解释"为什么不动 .bashrc"；判断代码行为时只看注释之外的部分。
    """
    with open(PKG_FILE, "r", encoding="utf-8") as f:
        return re.sub(r'(?m)^\s*--.*$', '', f.read())


class TestCompletion:
    """TAB 补全注册契约（`mcpp self completion`，bash/zsh/fish/PowerShell）。

    配方只声明意图：`register_completion{ name, bin, args }` 与
    `unregister_completion(name)`。生成脚本、校验、放置、写入 xlings 自己的 profile
    （标记块、整体替换/删除、换行风格、$XLINGS_HOME 引用、各 shell 守卫、旧版本
    一次探测即短路）的行为契约在 tests/test_shell_profile.py。系统 shell 配置一行
    都不碰 —— subos 隔离边界即此 feature 的边界。
    """

    @pytest.mark.static
    def test_declares_intent_through_the_shared_module(self):
        active = _active_code()
        assert "lib.register_completion{" in active
        assert "lib.unregister_completion(" in active
        assert '"self", "completion", "{shell}", "--print"' in active
        # profile 文件名、标记块、各 shell 守卫、脚本表都属于模块，不在配方里重复。
        for owned in ("xlings-profile", "# >>>", "# <<<", "BASH_VERSION",
                      "mcpp.bash", "mcpp.zsh", "system.exec"):
            assert owned not in active, f"completion machinery duplicated in the recipe: {owned}"

    @pytest.mark.static
    def test_the_module_is_imported_inside_the_hooks(self):
        # xlings runs uninstall() from a snapshot of the recipe in the install
        # directory; a top-level import() of an index module is a silent stub
        # there and the profile block would never be cut (openxlings/xlings#743).
        active = _active_code()
        top_level = [l for l in active.splitlines() if l.startswith("import(")]
        assert not any("shell_profile" in l for l in top_level), \
            "import xim.pkgindex.shell_profile inside the hook, not at the top of the file"
        assert 'local lib = import("xim.pkgindex.shell_profile")' in active
        assert 'type(lib.register_completion) ~= "function"' in active, \
            "a stub module must be refused"

    @pytest.mark.static
    def test_no_system_shell_config(self):
        active = _active_code()
        for forbidden in (".bashrc", "bash_profile", "config.fish",
                          "PowerShell_profile", "zshrc", "append_to_shell_profile"):
            assert forbidden not in active, f"system shell config referenced: {forbidden}"

    @pytest.mark.static
    def test_both_hooks_use_it(self):
        # 注册在 config()，清理在 uninstall()；缺一则 profile 里留下无主的块。
        active = _active_code()
        config = active[active.index("function config()"):active.index("function uninstall()")]
        uninstall = active[active.index("function uninstall()"):]
        assert "register_completion" in config and "unregister_completion" not in config
        assert "unregister_completion" in uninstall


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(under_test(PKG, INSTALL_VERSION), timeout=420)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_mcpp(self):
        # Whichever version this run installed: the lifecycle job installs
        # the version this module pins, a candidate job only the candidate.
        assert_command_output("mcpp --version", regex=r"mcpp \d+(\.\d+)+")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_mcpp_shim(self):
        assert_xvm_shim_exists("mcpp")
