-- websocat — Command-line client for WebSockets, like netcat (or curl) for
-- ws:// with advanced socat-like functions (vi/websocat).
--
-- Distribution: upstream publishes raw standalone binaries for every target
-- (distinct filename per target triple, so mirror materialization has no
-- filename collision).
--   linux/x86_64   websocat.x86_64-unknown-linux-musl   (static-pie musl ELF, no DT_NEEDED)
--   linux/aarch64  websocat.aarch64-unknown-linux-musl  (static musl ELF, no dynamic section)
--   macosx/x86_64  websocat.x86_64-apple-darwin
--   macosx/aarch64 websocat.aarch64-apple-darwin
--   windows/x86_64 websocat.x86_64-pc-windows-gnu.exe   (MinGW-w64 PE32+, system DLLs only, no VCRUNTIME140.dll)
--
-- Windows aarch64 is not published by upstream and is omitted (fail-closed).
-- Verified against vi/websocat release v1.14.2 (2026-11-25): SHA-256 matched
-- GitHub release asset digests and local downloaded bytes.

package = {
    spec = "2",

    name = "websocat",
    description = "Command-line client for WebSockets, like netcat (or curl) for ws:// with advanced socat-like functions",
    homepage = "https://github.com/vi/websocat",
    maintainers = {"vi"},
    licenses = {"MIT"},
    repo = "https://github.com/vi/websocat",
    docs = "https://github.com/vi/websocat#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "network", "websocket", "tools"},
    keywords = {"websocat", "websocket", "ws", "wss", "netcat", "socat", "cli"},

    programs = {"websocat"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/vi/websocat/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/vi/websocat/releases/download/${tag}/websocat.x86_64-unknown-linux-musl",
                            aarch64 = "https://github.com/vi/websocat/releases/download/${tag}/websocat.aarch64-unknown-linux-musl",
                        },
                        macosx = {
                            x86_64 = "https://github.com/vi/websocat/releases/download/${tag}/websocat.x86_64-apple-darwin",
                            aarch64 = "https://github.com/vi/websocat/releases/download/${tag}/websocat.aarch64-apple-darwin",
                        },
                        windows = {
                            x86_64 = "https://github.com/vi/websocat/releases/download/${tag}/websocat.x86_64-pc-windows-gnu.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/vi/websocat/releases/download/v${version}/websocat.${arch}-unknown-linux-musl",
            ["latest"] = { ref = "1.14.2" },
            ["1.14.2"] = {
                sha256 = {
                    x86_64 = "cd26f92cb507f620e2d54fe6e126f4dc191f3eee90f2b53bccf07eac0645ec84",
                    aarch64 = "cdd6b0bee24c81c537cb9ef257b433625355e0bbe002235f8df1e70acbd2c1dd",
                },
            },
        },
        macosx = {
            source = "https://github.com/vi/websocat/releases/download/v${version}/websocat.${arch}-apple-darwin",
            ["latest"] = { ref = "1.14.2" },
            ["1.14.2"] = {
                sha256 = {
                    x86_64 = "220b2706d32b1b87d4aa5dc2f50741032874754658aaaac914738c4aad10be9c",
                    aarch64 = "c11a379994e7cf7f14c8e5575de1667eeb64c31bacb0aea97b13a7704502384a",
                },
            },
        },
        windows = {
            source = "https://github.com/vi/websocat/releases/download/v${version}/websocat.${arch}-pc-windows-gnu.exe",
            ["latest"] = { ref = "1.14.2" },
            ["1.14.2"] = {
                sha256 = {
                    x86_64 = "90797ce63356c5d2acb2e295c62642d8d28e86dd12908eaa5c3d254370036acd",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/websocat") or os.isfile(dir .. "/websocat.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/websocat.exe" or "/websocat")

    os.tryrm(dir)
    os.mkdir(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("websocat: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("websocat", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("websocat")
    return true
end
