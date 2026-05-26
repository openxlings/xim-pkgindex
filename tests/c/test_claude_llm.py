"""Tests for pkgs/c/claude-llm.lua."""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_xim_add_succeeds,
)
from tests.lib.xpkg_parser import parse_xpkg


PKG_FILE = "pkgs/c/claude-llm.lua"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def raw_content():
    return Path(PKG_FILE).read_text(encoding="utf-8")


@pytest.mark.static
class TestClaudeLlmStatic:
    """Static package contract tests."""

    def test_required_fields_and_spec(self, meta):
        assert_required_fields(meta)
        assert_valid_spec(meta)
        assert_valid_type(meta)
        assert_no_typos(PKG_FILE)

    def test_metadata(self, meta):
        assert meta.name == "claude-llm"
        assert meta.pkg_type == "config"
        assert meta.namespace == "config"

    def test_platforms_depend_on_claude(self, raw_content, meta):
        assert set(meta.platforms.keys()) == {"windows", "linux", "macosx"}

        for platform in ("windows", "linux", "macosx"):
            assert platform in raw_content

        assert raw_content.count("[\"latest\"] = { ref = \"deepseek\" }") == 3
        assert raw_content.count("[\"deepseek\"] = {}") == 3
        assert raw_content.count("\"xim:claude\"") == 3

    def test_imports_are_limited_to_libxpkg(self, raw_content, meta):
        assert "xim.libxpkg.json" in meta.imports
        assert "xim.libxpkg.log" in meta.imports
        assert "xim.libxpkg.system" in meta.imports

        for imported in meta.imports:
            assert imported.startswith("xim.libxpkg."), imported

        forbidden = [
            "import(\"core.",
            "import(\"detect.",
            "import(\"lib.detect.",
            "import(\"xim.base.runtime",
            "import(\"common\")",
            "import(\"platform\")",
            "runtime.",
            "is_host(",
            "os.scriptdir(",
            "raise(",
        ]
        for token in forbidden:
            assert token not in raw_content

    def test_top_level_is_declarative(self, raw_content):
        first_function = raw_content.index("local function")
        top_level = raw_content[:first_function]

        forbidden_runtime_calls = [
            "os.getenv(",
            "os.isfile(",
            "os.isdir(",
            "os.cp(",
            "os.mkdir(",
            "io.read(",
            "system.exec(",
            "json.loadfile(",
            "json.savefile(",
        ]
        for token in forbidden_runtime_calls:
            assert token not in top_level

    def test_install_is_trivial_and_config_does_work(self, meta, raw_content):
        install_hook = re.search(r"function install\(\)(.*?)\nend", raw_content, re.S)
        config_hook = re.search(r"function config\(\)(.*?)\nend", raw_content, re.S)

        assert install_hook is not None
        assert config_hook is not None
        assert "return true" in install_hook.group(1)
        assert "__write_claude_settings(settings_file, settings, api_key, keep_existing_key)" in config_hook.group(1)
        assert "__ensure_onboarding_completed()" in config_hook.group(1)

        assert "settings = __load_json_object(settings_file)" in raw_content
        assert "settings.env = {}" in raw_content

    def test_uses_standard_lua_error_not_xmake_raise(self, raw_content):
        assert "error(" in raw_content
        assert "raise(" not in raw_content
        assert "无法定位用户主目录，未写入 Claude 配置" in raw_content

    def test_configures_expected_claude_files(self, raw_content):
        assert ".claude" in raw_content
        assert "settings.json" in raw_content
        assert ".claude.json" in raw_content
        assert "hasCompletedOnboarding" in raw_content
        assert "os.getenv(\"HOME\")" in raw_content
        assert "os.getenv(\"USERPROFILE\")" in raw_content

    def test_preserves_and_merges_existing_claude_settings(self, raw_content):
        assert "local settings = __load_json_object(settings_file)" in raw_content
        assert "if type(settings.env) ~= \"table\" then" in raw_content
        assert "settings.env = {}" in raw_content
        assert "__apply_deepseek_env(settings.env, api_key, keep_existing_key)" in raw_content
        assert "json.savefile(settings_file, settings" in raw_content
        assert "json.savefile(settings_file, {" not in raw_content

    def test_existing_config_is_backed_up_before_write(self, raw_content):
        assert "__backup_if_exists(settings_file)" in raw_content
        assert "__backup_if_exists(config_file)" in raw_content
        assert ".bak." in raw_content
        assert "os.date(\"%Y%m%d-%H%M%S\")" in raw_content
        assert "os.cp(file, backup)" in raw_content

    def test_prompts_and_trims_deepseek_api_key(self, raw_content):
        assert "https://platform.deepseek.com/api_keys" in raw_content
        assert "DeepSeek API Key" in raw_content
        assert "io.read(\"*l\")" in raw_content
        assert ":match(\"^%s*(.-)%s*$\")" in raw_content

    def test_prompts_with_standard_lua_and_logs_status_with_libxpkg(self, raw_content):
        assert 'print("请先在 DeepSeek 平台创建或复制 API Key:")' in raw_content
        assert 'io.write("DeepSeek API Key: ")' in raw_content
        assert "io.flush()" in raw_content
        assert "cprint(" not in raw_content
        assert "log.info(\"已配置 Claude env.%s = %s\", key, value)" in raw_content
        assert "log.info(\"已配置 Claude env.%s = <已隐藏>\", key)" in raw_content

    def test_applies_expected_deepseek_environment(self, raw_content):
        expected_values = {
            "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
            "ANTHROPIC_MODEL": "deepseek-v4-pro[1m]",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1m]",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-pro[1m]",
            "CLAUDE_CODE_SUBAGENT_MODEL": "deepseek-v4-pro[1m]",
            "CLAUDE_CODE_EFFORT_LEVEL": "max",
            "API_TIMEOUT_MS": "3000000",
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
        }

        for key, value in expected_values.items():
            assert f'__set_env(env, "{key}", "{value}")' in raw_content

        assert '__set_env(env, "ANTHROPIC_AUTH_TOKEN", api_key, true)' in raw_content
        assert "sk-xxx" not in raw_content

    def test_attribution_header_is_separate_token_cache_fix(self, raw_content):
        deepseek_env_function = re.search(
            r"local function __apply_deepseek_env\(env, api_key, keep_existing_key\)(.*?)\nend",
            raw_content,
            re.S,
        )
        assert deepseek_env_function is not None
        assert "CLAUDE_CODE_ATTRIBUTION_HEADER" not in deepseek_env_function.group(1)

        assert "local function __apply_claude_token_cache_fix(env)" in raw_content
        assert (
            '__set_env(env, "CLAUDE_CODE_ATTRIBUTION_HEADER", "0")'
            in raw_content
        )
        assert "__apply_claude_token_cache_fix(settings.env)" in raw_content
        assert "修复 Claude token 缓存机制" in raw_content

    def test_empty_input_reuses_existing_deepseek_key_only_when_present(self, raw_content):
        assert "local existing_api_key = __existing_deepseek_api_key(settings.env)" in raw_content
        assert "local api_key, keep_existing_key = __read_deepseek_api_key(existing_api_key)" in raw_content
        assert "return existing_api_key, true" in raw_content
        assert "不修改 ANTHROPIC_AUTH_TOKEN" in raw_content
        assert "log.warn(" in raw_content
        assert "if not keep_existing_key then" in raw_content
        assert "没有可复用的旧 DeepSeek key" in raw_content

    def test_existing_key_reuse_requires_deepseek_endpoint(self, raw_content):
        assert (
            'env["ANTHROPIC_BASE_URL"] ~= "https://api.deepseek.com/anthropic"'
            in raw_content
        )
        assert 'local existing_api_key = __trim(env["ANTHROPIC_AUTH_TOKEN"])' in raw_content
        assert "return existing_api_key" in raw_content

    def test_verification_command_avoids_new_directory_prompt(self, raw_content):
        assert "system.exec(" in raw_content
        assert "claude -p" in raw_content
        assert "--setting-sources user" in raw_content
        assert '--tools ""' in raw_content
        assert "--no-session-persistence" in raw_content
        assert "DeepSeek 配置验证成功" not in raw_content


@pytest.mark.index
class TestClaudeLlmIndex:
    def test_xim_add_succeeds(self):
        assert_xim_add_succeeds(PKG_FILE)


@pytest.mark.isolation
class TestClaudeLlmIsolation:
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    def test_no_bashrc_modification(self):
        assert_no_bashrc_modification(PKG_FILE)

    def test_no_direct_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    def test_uses_new_api(self):
        assert_uses_new_api(PKG_FILE)
