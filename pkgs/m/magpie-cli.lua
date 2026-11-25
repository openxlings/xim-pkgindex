-- magpie-cli — the terminal build of magpie: TUI, web UI and CLI for one local
-- gateway that points every AI coding agent at the model you pick.
--
-- Upstream publishes the same program in two builds per platform. This
-- package is the terminal build (`magpie-cli-*`), which is headless and
-- needs no GTK/WebKitGTK; the desktop build is `pkgs/m/magpie.lua`.
--
-- Both builds unpack to a command named `magpie` and report the same
-- `magpie 0.1.4657`. Registering both packages as `magpie` at this version
-- would be an xvm shared-name collision ("another package already owns this
-- exact name and version"), so this recipe renames the payload to
-- `magpie-cli` and registers that name. Installing both packages then leaves
-- two commands: `magpie` (desktop) and `magpie-cli` (terminal). The program
-- accepts any argv[0] -- verified by running a renamed copy.
--
-- PLATFORM MATRIX:
--
--   linux    x86_64, aarch64   raw ELF (statically linked Go binary)
--   macosx   x86_64, aarch64   raw Mach-O executable
--   windows  x86_64, aarch64   raw .exe
--
-- Upstream also publishes `magpie-cli-android-arm64` for Termux. xlings has
-- no Android host platform (it looks up linux/macosx/windows only), so that
-- asset cannot be selected by any client and is deliberately not declared.
--
-- No runtime deps: the Linux binary is static (readelf -d shows no
-- DT_NEEDED), and the other builds are single executables. Declaring
-- `xim:glibc` would make elfpatch rewrite a payload that does not need it.
--
-- GLOBAL is the authoritative upstream release; no verified CN mirror exists.
--
-- MANUAL MAINTENANCE — there is deliberately no extensions.autoupdate.
-- yetone/magpie has more than 1000 releases; GitHub's list-releases API
-- answers page 11 with 422 "Only the first 1000 results are available",
-- and the pinned xpkgindex-update treats that as an error, so automatic
-- discovery cannot enumerate this project. Bump by hand: take the newest
-- release tag, copy each asset's sha256 from that release's SHA256SUMS, and
-- move every platform's `latest` ref together.

package = {
    spec = "2",

    name = "magpie-cli",
    description = "Terminal build of magpie (TUI, web UI and CLI) for routing every AI coding agent through one local gateway",
    homepage = "https://usemagpie.ai",
    repo = "https://github.com/yetone/magpie",
    docs = "https://usemagpie.ai/docs/start",
    authors = {"yetone"},
    maintainers = {"yetone"},
    licenses = {"MIT"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "cli", "tools"},
    keywords = {"magpie", "ai-agent", "claude-code", "codex", "gateway", "model-router", "tui"},
    programs = {"magpie-cli"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "0.1.4657" },
            ["0.1.4657"] = {
                x86_64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-cli-linux-amd64",
                    sha256 = "52c8efaa2cd43e9801b19b5c3ab3abc9d4d4a4b4efcf1e85edd4c3542e4b472c",
                },
                aarch64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-cli-linux-arm64",
                    sha256 = "36f717e2f7f2d937dac7c6272c7c4cf12200c0ba4bb7905edb60747efce843ba",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.1.4657" },
            ["0.1.4657"] = {
                x86_64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-cli-darwin-amd64",
                    sha256 = "7bf97b01638df9d4f5b72e533ada67f0f0bdd4d05c23e5bdb9054dc99b404da9",
                },
                aarch64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-cli-darwin-arm64",
                    sha256 = "19185305feb4c7ca35002f44d854b8fa3ff4380e4bd149602f98219a4e14fb6a",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.1.4657" },
            ["0.1.4657"] = {
                x86_64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-cli-windows-amd64.exe",
                    sha256 = "7b520b795ac320e90d164abf8dec96c7416cc440cad3b527f467f397cbdbefac",
                },
                aarch64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-cli-windows-arm64.exe",
                    sha256 = "06c48152b46a0cd9d12c56365f29211349a744f85296a5eca6150919cd393c61",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

-- Every asset is a raw executable; xlings does not unpack it (it only
-- extracts recognised archive suffixes). Move it under the command name this
-- package registers, because upstream names every asset `magpie`.
function install()
    local dir = pkginfo.install_dir()
    local file = pkginfo.install_file()
    os.tryrm(dir)
    os.mkdir(dir)

    local windows = file:lower():match("%.exe$") ~= nil
    local exe = path.join(dir, windows and "magpie-cli.exe" or "magpie-cli")
    os.mv(file, exe)
    if not windows then
        system.exec(string.format([[chmod +x "%s"]], exe))
    end
    return os.isfile(exe)
end

function installed()
    local dir = pkginfo.install_dir()
    if os.isfile(path.join(dir, "magpie-cli.exe")) then
        return true
    end
    return os.isfile(path.join(dir, "magpie-cli"))
end

function config()
    xvm.add("magpie-cli", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("magpie-cli")
    return true
end