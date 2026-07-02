package = {
    spec = "1",

    name = "claude",
    description = "Claude Code CLI from Anthropic",
    homepage = "https://github.com/anthropics/claude-code",
    licenses = {"MIT"},
    repo = "https://github.com/anthropics/claude-code",
    docs = "https://docs.anthropic.com/en/docs/claude-code/overview",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "cli", "tools"},
    keywords = {"claude", "anthropic", "agent", "cli"},

    programs = {"claude"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {"node", "npm"},
            ["latest"] = { ref = "2.1.142" },
            ["2.1.198"] = {},
            ["2.1.156"] = { },
            ["2.1.153"] = { },
            ["2.1.142"] = { },
            ["2.1.90"] = { },
            ["2.1.63"] = { },
        },
        macosx = {
            deps = {"node", "npm"},
            ["latest"] = { ref = "2.1.142" },
            ["2.1.198"] = {},
            ["2.1.156"] = { },
            ["2.1.153"] = { },
            ["2.1.142"] = { },
            ["2.1.90"] = { },
            ["2.1.63"] = { },
        },
        windows = {
            deps = {"node", "npm"},
            ["latest"] = { ref = "2.1.142" },
            ["2.1.198"] = {},
            ["2.1.156"] = { },
            ["2.1.153"] = { },
            ["2.1.142"] = { },
            ["2.1.90"] = { },
            ["2.1.63"] = { },
        },
    }
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")


-- 结构说明（基于 npm 包元数据 + 本地安装校验）:
--   1) 旧版（<= 2.1.100）：package.json 的 bin.claude = "cli.js"，
--      主入口位于 <install>/node_modules/@anthropic-ai/claude-code/cli.js，
--      需要通过 node 解释器执行。
--   2) 新版（>= 2.1.120）：package.json 的 bin.claude = "bin/claude.exe"，
--      install.cjs 在 postinstall 把对应平台的原生二进制覆盖到
--      <install>/node_modules/@anthropic-ai/claude-code/bin/claude.exe，
--      可直接执行（即使在 linux/macos 文件名也是 claude.exe）。
--   3) 这里运行时探测，向后兼容历史版本。npm .bin 包装在不同 OS 形态不同，
--      不直接依赖。
function __claude_entry()
    local pkg_root = path.join(pkginfo.install_dir(), "node_modules", "@anthropic-ai", "claude-code")
    local native = path.join(pkg_root, "bin", "claude.exe")
    if os.isfile(native) then
        return { path = native, mode = "native" }
    end
    local js = path.join(pkg_root, "cli.js")
    if os.isfile(js) then
        return { path = js, mode = "node" }
    end
    return nil
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local npm_install = string.format(
        [[npm install --prefix "%s" --no-fund --no-audit "@anthropic-ai/claude-code@%s"]],
        pkginfo.install_dir(),
        pkginfo.version()
    )
    os.exec(npm_install)

    if not __claude_entry() then
        raise("claude entry (bin/claude.exe or cli.js) not found after npm install")
    end

    return true
end

function config()
    local entry = __claude_entry()
    local alias
    if entry.mode == "native" then
        alias = string.format([["%s"]], entry.path)
    else
        alias = string.format([[node "%s"]], entry.path)
    end
    xvm.add("claude", {
        alias = alias,
        envs = {
            -- should be set by user, not hardcoded here
            --CLAUDE_CONFIG_DIR = path.join(pkginfo.install_dir(), "config"),
        }
    })
    return true
end

function uninstall()
    xvm.remove("claude")
    return true
end
