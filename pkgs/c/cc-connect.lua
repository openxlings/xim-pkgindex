package = {
    spec = "1",

    name = "cc-connect",
    description = "Bridge local AI coding agents (Claude Code, Codex, Cursor, Gemini CLI, etc.) to messaging platforms (Feishu, Slack, Telegram, Discord, ...)",
    homepage = "https://github.com/chenhg5/cc-connect",
    maintainers = {"chenhg5"},
    licenses = {"MIT"},
    repo = "https://github.com/chenhg5/cc-connect",
    ci = { mirror = true, update = true },
    docs = "https://github.com/chenhg5/cc-connect#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "ai-agent", "tools"},
    keywords = {"claude-code", "ai", "agent", "feishu", "lark", "slack", "messaging-bridge"},

    programs = {"cc-connect"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/chenhg5/cc-connect/releases/download/v{version}/cc-connect-v{version}-linux-amd64.tar.gz",
            ["latest"] = { ref = "1.3.2" },
            ["1.3.3-beta.1"] = {
                url = "https://github.com/chenhg5/cc-connect/releases/download/v1.3.3-beta.1/cc-connect-v1.3.3-beta.1-linux-amd64.tar.gz",
                sha256 = "8e54e56e9018258fa27f6509c7744313704ad26b093f467c7a458e46f41c07bf",
            },
            ["1.3.2"] = {
                url = "https://github.com/chenhg5/cc-connect/releases/download/v1.3.2/cc-connect-v1.3.2-linux-amd64.tar.gz",
                sha256 = "4ed25a62166c1a3a7c41eb3320d9b90172c56749aec5b88d36380829e4c8a182",
            },
        },
        macosx = {
            url_template = "https://github.com/chenhg5/cc-connect/releases/download/v{version}/cc-connect-v{version}-darwin-arm64.tar.gz",
            ["latest"] = { ref = "1.3.2" },
            ["1.3.3-beta.1"] = {
                url = "https://github.com/chenhg5/cc-connect/releases/download/v1.3.3-beta.1/cc-connect-v1.3.3-beta.1-darwin-arm64.tar.gz",
                sha256 = "4ae6cdabbebe487abba66899707f614f497a6a8f732a16c961228151d261c515",
            },
            ["1.3.2"] = {
                url = "https://github.com/chenhg5/cc-connect/releases/download/v1.3.2/cc-connect-v1.3.2-darwin-arm64.tar.gz",
                sha256 = "f03153feef8e46c606d0097a491e92448289fe3b91b70cba0b05f8740dfafe95",
            },
        },
        windows = {
            url_template = "https://github.com/chenhg5/cc-connect/releases/download/v{version}/cc-connect-v{version}-windows-amd64.zip",
            ["latest"] = { ref = "1.3.2" },
            ["1.3.3-beta.1"] = {
                url = "https://github.com/chenhg5/cc-connect/releases/download/v1.3.3-beta.1/cc-connect-v1.3.3-beta.1-windows-amd64.zip",
                sha256 = "445c6206a2432adbdf00eb83289349c6db179f64f9626bb9a0004c619044b95f",
            },
            ["1.3.2"] = {
                url = "https://github.com/chenhg5/cc-connect/releases/download/v1.3.2/cc-connect-v1.3.2-windows-amd64.zip",
                sha256 = "88cbc4cbc3cfddb826e4b2030f4a34afd60b55dfc642d27ad2932d0b53cf5623",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Archive layout: every platform's archive contains a single file at top
-- level named `cc-connect-v<ver>-<os>-<arch>` (or `.exe` on Windows). We
-- rename to a clean `cc-connect` / `cc-connect.exe` so callers don't have
-- to know the build triple.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local download_dir = path.directory(pkginfo.install_file())
    local ver = pkginfo.version()
    local src, dst
    if is_host("windows") then
        src = path.join(download_dir, "cc-connect-v" .. ver .. "-windows-amd64.exe")
        dst = path.join(pkginfo.install_dir(), "cc-connect.exe")
    elseif is_host("macosx") then
        src = path.join(download_dir, "cc-connect-v" .. ver .. "-darwin-arm64")
        dst = path.join(pkginfo.install_dir(), "cc-connect")
    else
        src = path.join(download_dir, "cc-connect-v" .. ver .. "-linux-amd64")
        dst = path.join(pkginfo.install_dir(), "cc-connect")
    end
    os.mv(src, dst)
    if not is_host("windows") then
        os.exec("chmod +x " .. dst)
    end
    return true
end

function config()
    xvm.add("cc-connect", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("cc-connect")
    return true
end
