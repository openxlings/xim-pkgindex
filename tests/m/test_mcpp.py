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

    注册面是 xlings 自己的 profile（~/.xlings/config/shell/xlings-profile.*），
    系统 shell 配置一行都不碰 —— subos 隔离边界即此 feature 的边界。

    libxpkg 的 system.unix_api().append_to_shell_profile 名义上是专用 API，
    实测（探针 xpkg）追加目标 = _RUNTIME.run_dir（调用 xlings 的 CWD）而非
    真实 profile 目录，且只有 posix/fish 两个分支、没有 PowerShell；隔离断言
    也禁止配方出现该调用名。等 libxpkg 侧修好 API，配方再迁移；在那之前由
    标记块管理提供同等能力。
    """

    @pytest.mark.static
    def test_registers_in_xlings_profiles_only(self):
        active = _active_code()
        for surface in ("xlings-profile.sh", "xlings-profile.fish",
                        "xlings-profile.ps1"):
            assert surface in active, f"completion surface missing: {surface}"
        # 系统 shell 配置只能出现在注释里（解释为什么不动它），代码里一个都没有。
        for forbidden in (".bashrc", "bash_profile", "config.fish",
                          "PowerShell_profile", "zshrc"):
            assert forbidden not in active, f"system shell config referenced: {forbidden}"

    @pytest.mark.static
    def test_scripts_generated_from_the_installed_binary(self):
        # 脚本来自 `mcpp self completion <shell> --print`（与装上的版本协议一致），
        # 配方不内嵌脚本内容 —— 内嵌会随上游协议漂移。
        active = _active_code()
        assert "self completion" in active
        assert "--print" in active
        assert "complete -o default -F _mcpp_complete" not in active, \
            "mcpp's bash script content is embedded in the recipe; it must come from the binary"

    @pytest.mark.static
    def test_all_four_shells_supported(self):
        active = _active_code()
        for script in ("mcpp.bash", "mcpp.zsh", "mcpp.fish", "mcpp.ps1"):
            assert script in active, f"missing completion script for: {script}"

    @pytest.mark.static
    def test_registration_is_best_effort(self):
        # 生命周期测试装 0.0.56 —— 早于 `self completion` 命令的版本。
        # 注册失败只损失补全，绝不能让安装/卸载失败。
        active = _active_code()
        assert "pcall(register_completions)" in active
        assert "pcall(remove_completions)" in active

    @pytest.mark.static
    def test_marked_block_replaced_and_removed_whole(self):
        # 块用 `# >>> mcpp completion ... >>>` 标记对整体替换/整体删除：
        # 重复 config() 不累积；uninstall() 干净移除（三个 profile + 脚本）。
        active = _active_code()
        assert "# >>> mcpp completion" in active
        assert "# <<< mcpp completion" in active
        for profile in ("xlings-profile.sh", "xlings-profile.fish",
                        "xlings-profile.ps1"):
            assert re.search(
                r'update_profile\(\s*path\.join\(sdir,\s*"' +
                re.escape(profile) + r'"\)\s*,\s*nil\)', active), \
                f"uninstall must remove the block from {profile}"

    @pytest.mark.static
    def test_sh_block_guards_mirror_xlings_profile(self):
        # xlings-profile.sh 会被 bash/zsh/纯 sh 共同 source：mcpp.bash/mcpp.zsh
        # 含 bash-/zsh-only 语法，守卫必须与 xlings profile 自己的补全分支
        # 同构，否则纯 sh/dash 解析报错、整个 profile 失效。
        active = _active_code()
        assert '${BASH_VERSION-}' in active
        assert 'command -v complete' in active
        assert '${ZSH_VERSION-}' in active
        assert 'typeset -f compdef' in active


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
