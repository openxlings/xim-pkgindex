-- atuin: sync, search, and backup shell history with SQLite.
--
-- Official prebuilt archives verified against atuinsh/atuin release v18.25.1:
--   * linux/x86_64: static-pie musl binary (no PT_INTERP or DT_NEEDED)
--   * linux/aarch64: statically linked musl binary (no PT_INTERP or DT_NEEDED)
--   * macosx: both x86_64-apple-darwin and aarch64-apple-darwin tarballs
--     extract into `atuin-<arch>-apple-darwin/`
--   * windows: x86_64-pc-windows-msvc.zip only (upstream has no Windows ARM64
--     archive); flat zip layout (no enclosing directory) and atuin.exe is built
--     with static CRT (imports only Windows OS system DLLs, no VCRUNTIME140.dll)
package = {
    spec = "2",

    name = "atuin",
    description = "Magical shell history",
    homepage = "https://atuin.sh",
    licenses = {"MIT"},
    repo = "https://github.com/atuinsh/atuin",
    docs = "https://docs.atuin.sh/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "shell", "tools"},
    keywords = {"atuin", "shell", "history", "sqlite", "rust"},

    programs = {"atuin"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/atuinsh/atuin/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/atuinsh/atuin/releases/download/${tag}/atuin-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/atuinsh/atuin/releases/download/${tag}/atuin-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/atuinsh/atuin/releases/download/${tag}/atuin-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/atuinsh/atuin/releases/download/${tag}/atuin-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/atuinsh/atuin/releases/download/${tag}/atuin-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "18.25.1" },
            ["18.25.1"] = {
                x86_64 = {
                    url = "https://github.com/atuinsh/atuin/releases/download/v18.25.1/atuin-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "f2bc97588d5aa91f49b992298544e13776df044cb4baf606875c7cc8444e9e00",
                },
                aarch64 = {
                    url = "https://github.com/atuinsh/atuin/releases/download/v18.25.1/atuin-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "a76aff915be408f15eca033dfbd555bb8d1237e83b09562f7481636f7894555f",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "18.25.1" },
            ["18.25.1"] = {
                x86_64 = {
                    url = "https://github.com/atuinsh/atuin/releases/download/v18.25.1/atuin-x86_64-apple-darwin.tar.gz",
                    sha256 = "ef02c01ba521475be872dc7e725dfa6ad3b3459162a7d642633239f9dfc570eb",
                },
                aarch64 = {
                    url = "https://github.com/atuinsh/atuin/releases/download/v18.25.1/atuin-aarch64-apple-darwin.tar.gz",
                    sha256 = "c2d94ae74da55c644de08ce3eedb0abd5f4a32340f3e9b8e2dade29764ac524c",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "18.25.1" },
            ["18.25.1"] = {
                x86_64 = {
                    url = "https://github.com/atuinsh/atuin/releases/download/v18.25.1/atuin-x86_64-pc-windows-msvc.zip",
                    sha256 = "8c1a4c51251fd79f93551dcb66d23e8e34b3d49df56e47dbf853418cfadc167a",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

-- Posix tarballs extract into `atuin-<target>/` containing `atuin`, LICENSE,
-- README.md, and CHANGELOG.md. The Windows zip is flat (no enclosing dir), so
-- payload.unpack extracts the zip directly into pkginfo.install_dir() without
-- stripping components.
function installed()
    return payload.present({ "atuin", "LICENSE" })
        or payload.present({ "atuin.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    payload.unpack{ extracted = is_win and nil or stem }
    payload.require({ is_win and "atuin.exe" or "atuin", "LICENSE" })
    return true
end

function config()
    xvm.add("atuin", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("atuin")
    return true
end
