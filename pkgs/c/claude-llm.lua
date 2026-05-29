package = {
    spec = "1",
    name = "claude-llm",
    description = "Configure Claude Code to use DeepSeek Anthropic-compatible API",
    homepage = "https://platform.deepseek.com/api_keys",
    licenses = {"Apache-2.0"},

    type = "config",
    namespace = "config",
    status = "dev",
    categories = {"ai", "claude", "config"},
    keywords = {"claude", "claude-code", "deepseek", "llm"},

    xpm = {
        windows = {
            deps = { "xim:claude@2.1.153" },
            ["latest"] = { ref = "deepseek" },
            ["deepseek"] = { ref = "deepseek-v4-pro" },
            ["deepseek-v4-pro"] = {},
            ["deepseek-v4-flash"] = {}
        },
        linux = {
            deps = { "xim:claude@2.1.153" },
            ["latest"] = { ref = "deepseek" },
            ["deepseek"] = { ref = "deepseek-v4-pro" },
            ["deepseek-v4-pro"] = {},
            ["deepseek-v4-flash"] = {}
        },
        macosx = {
            deps = { "xim:claude@2.1.153" },
            ["latest"] = { ref = "deepseek" },
            ["deepseek"] = { ref = "deepseek-v4-pro" },
            ["deepseek-v4-pro"] = {},
            ["deepseek-v4-flash"] = {}
        },
    },
}

import("xim.libxpkg.json")
import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")


local version_to_model_name = {
    ["deepseek-v4-pro"] = "deepseek-v4-pro[1m]",
    ["deepseek-v4-flash"] = "deepseek-v4-flash",
}

local function __trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function __home_dir()
    if os.host() == "windows" then
        local userprofile = os.getenv("USERPROFILE")
        if userprofile and userprofile ~= "" then
            return userprofile
        end

        local homedrive = os.getenv("HOMEDRIVE")
        local homepath = os.getenv("HOMEPATH")
        if homedrive and homepath and homedrive ~= "" and homepath ~= "" then
            return homedrive .. homepath
        end
    end

    local home = os.getenv("HOME")
    if home and home ~= "" then
        return home
    end

    local fallback = os.getenv("USERPROFILE")
    if fallback and fallback ~= "" then
        return fallback
    end

    error("无法定位用户主目录，未写入 Claude 配置", 0)
end

local function __backup_if_exists(file)
    if os.isfile(file) then
        local backup = file .. ".bak." .. os.date("%Y%m%d-%H%M%S")
        os.cp(file, backup)
        log.info("已备份已有配置: " .. backup)
    end
end

local function __load_json_object(file)
    if not os.isfile(file) then
        return {}
    end

    local value = try {
        function()
            return json.loadfile(file)
        end,
        catch = function(err)
            log.warn("已有 JSON 配置读取失败，将使用新配置覆盖: " .. file)
            return {}
        end
    }

    if type(value) ~= "table" then
        return {}
    end
    return value
end

local function __existing_deepseek_api_key(env)
    if type(env) ~= "table" then
        return nil
    end
    if env["ANTHROPIC_BASE_URL"] ~= "https://api.deepseek.com/anthropic" then
        return nil
    end

    local existing_api_key = __trim(env["ANTHROPIC_AUTH_TOKEN"])
    if existing_api_key == "" then
        return nil
    end
    return existing_api_key
end

local function __read_deepseek_api_key(existing_api_key)
    print("请先在 DeepSeek 平台创建或复制 API Key:")
    print("")
    print("  -> https://platform.deepseek.com/api_keys")
    print("")
    print("复制 DeepSeek API Key 后粘贴到下面, 按回车继续")
    io.write("DeepSeek API Key: ")
    io.flush()

    local api_key = __trim(io.read("*l"))
    if api_key == "" then
        if existing_api_key then
            log.warn("未输入新的 DeepSeek API Key，将复用已有 key，不修改 ANTHROPIC_AUTH_TOKEN")
            return existing_api_key, true
        end
        log.error("未输入 DeepSeek API Key，且没有可复用的旧 DeepSeek key")
        error("未输入 DeepSeek API Key，且没有可复用的旧 DeepSeek key", 0)
    end
    return api_key, false
end

local function __ensure_onboarding_completed()
    local config_file = path.join(__home_dir(), ".claude.json")
    __backup_if_exists(config_file)

    local config = __load_json_object(config_file)
    config["hasCompletedOnboarding"] = true

    json.savefile(config_file, config, { indent = true })
    log.info("已确保 Claude onboarding 状态: hasCompletedOnboarding=true")
end

local function __log_env_update(key, value, hidden)
    if hidden then
        log.info("已配置 Claude env.%s = <已隐藏>", key)
    else
        --log.info("已配置 Claude env.%s = %s", key, value)
    end
end

local function __set_env(env, key, value, hidden)
    env[key] = value
    __log_env_update(key, value, hidden)
end

local function __apply_deepseek_env(env, api_key, keep_existing_key)
    if not keep_existing_key then
        __set_env(env, "ANTHROPIC_AUTH_TOKEN", api_key, true)
    end

    local model_name = version_to_model_name[pkginfo.version()] or "deepseek-v4-pro[1m]"

    log.info("配置 Claude 使用 DeepSeek 模型: " .. model_name)

    __set_env(env, "ANTHROPIC_BASE_URL", "https://api.deepseek.com/anthropic")
    __set_env(env, "ANTHROPIC_MODEL", model_name)
    __set_env(env, "ANTHROPIC_DEFAULT_OPUS_MODEL", model_name)
    __set_env(env, "ANTHROPIC_DEFAULT_SONNET_MODEL", model_name)
    __set_env(env, "ANTHROPIC_DEFAULT_HAIKU_MODEL", "deepseek-v4-flash")
    __set_env(env, "CLAUDE_CODE_SUBAGENT_MODEL", "deepseek-v4-flash")
    __set_env(env, "CLAUDE_CODE_EFFORT_LEVEL", "max")
    __set_env(env, "API_TIMEOUT_MS", "3000000")
    __set_env(env, "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "1")
end

local function __apply_claude_token_cache_fix(env)
    log.info("修复 Claude token 缓存机制: 禁用 attribution header, 避免随机值导致的缓存失效")
    __set_env(env, "CLAUDE_CODE_ATTRIBUTION_HEADER", "0")
end

local function __write_claude_settings(settings_file, settings, api_key, keep_existing_key)
    local claude_dir = path.directory(settings_file)
    if not os.isdir(claude_dir) then
        os.mkdir(claude_dir)
    end

    __backup_if_exists(settings_file)

    if type(settings.env) ~= "table" then
        settings.env = {}
    end
    __apply_deepseek_env(settings.env, api_key, keep_existing_key)
    __apply_claude_token_cache_fix(settings.env)
    json.savefile(settings_file, settings, { indent = true })

    log.info("已写入 Claude DeepSeek 配置: " .. settings_file)
end

local function __verify_claude()
    log.info("正在调用 Claude Code 发起一次配置验证请求...")
    print("")
    system.exec([[claude -p --setting-sources user --tools "" --no-session-persistence tell_model_name_and_calculate_1_plus_2_use_chinese]])
    print("")
end

function install()
    return true
end

function config()
    local settings_file = path.join(__home_dir(), ".claude", "settings.json")
    local settings = __load_json_object(settings_file)
    if type(settings.env) ~= "table" then
        settings.env = {}
    end
    local existing_api_key = __existing_deepseek_api_key(settings.env)
    local api_key, keep_existing_key = __read_deepseek_api_key(existing_api_key)
    __ensure_onboarding_completed()
    __write_claude_settings(settings_file, settings, api_key, keep_existing_key)
    log.info("Claude DeepSeek 配置已完成。运行 claude 命令开始使用...")
    __verify_claude()
    return true
end

function uninstall()
    return true
end
