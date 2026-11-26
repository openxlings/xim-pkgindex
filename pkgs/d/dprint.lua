-- dprint: pluggable and configurable code formatting platform (dprint/dprint).
--
-- Verified against upstream GitHub release `dprint/dprint` 0.65.0
-- (published 2026-11-16); all SHA-256 digests match upstream `SHASUMS256.txt`,
-- GitHub release asset digests, and locally downloaded `.zip` archives.
--
-- Archive layout & binary inspection (0.65.0):
--   Every supported archive is a flat `.zip` containing a single executable
--   (`dprint` on Linux/macOS, `dprint.exe` on Windows) with no enclosing directory.
--   * linux/x86_64    : dprint-x86_64-unknown-linux-musl.zip
--                       static-pie ELF (no PT_INTERP, zero DT_NEEDED; ldd: "statically linked")
--   * linux/aarch64   : dprint-aarch64-unknown-linux-musl.zip
--                       statically linked ELF (no .dynamic section, zero DT_NEEDED)
--   * macosx/x86_64   : dprint-x86_64-apple-darwin.zip (Mach-O 64-bit x86_64)
--   * macosx/aarch64  : dprint-aarch64-apple-darwin.zip (Mach-O 64-bit arm64)
--   * windows/x86_64  : dprint-x86_64-pc-windows-msvc.zip
--                       PE32+ x86-64; statically links MSVC CRT (imports only
--                       Windows OS system DLLs, no VCRUNTIME140.dll -> no xim:vcruntime dep)
--   * windows/aarch64 : dprint-aarch64-pc-windows-msvc.zip
--                       PE32+ ARM64; statically links MSVC CRT (imports only
--                       Windows OS system DLLs, no VCRUNTIME140.dll -> no xim:vcruntime dep)

package = {
    spec = "2",

    name = "dprint",
    description = "Pluggable and configurable code formatting platform that unifies all your formatters",
    homepage = "https://dprint.dev",
    authors = {"David Sherret"},
    maintainers = {"David Sherret"},
    licenses = {"MIT"},
    repo = "https://github.com/dprint/dprint",
    docs = "https://dprint.dev/overview/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "formatter", "tools"},
    keywords = {"dprint", "formatter", "code-formatter", "typescript", "javascript", "json", "markdown", "rust"},

    programs = {"dprint"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/dprint/dprint/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/dprint/dprint/releases/download/${tag}/dprint-x86_64-unknown-linux-musl.zip",
                            aarch64 = "https://github.com/dprint/dprint/releases/download/${tag}/dprint-aarch64-unknown-linux-musl.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/dprint/dprint/releases/download/${tag}/dprint-x86_64-apple-darwin.zip",
                            aarch64 = "https://github.com/dprint/dprint/releases/download/${tag}/dprint-aarch64-apple-darwin.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/dprint/dprint/releases/download/${tag}/dprint-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/dprint/dprint/releases/download/${tag}/dprint-aarch64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/dprint/dprint/releases/download/${version}/dprint-${arch}-unknown-linux-musl.zip",
            ["latest"] = { ref = "0.65.0" },
            ["0.65.0"] = {
                sha256 = {
                    x86_64 = "61707303f4305891fecffec1f92ec8243b07e9d3ba8a7e81f7543fc77fb0002d",
                    aarch64 = "a427ef844b300d896b3f836706bb77d8df6b77f8f2627103c4a34ded94cf6ae1",
                },
            },
        },
        macosx = {
            source = "https://github.com/dprint/dprint/releases/download/${version}/dprint-${arch}-apple-darwin.zip",
            ["latest"] = { ref = "0.65.0" },
            ["0.65.0"] = {
                sha256 = {
                    x86_64 = "b94e2ede59904f34f8047ee9f069767acf19df389b3983f4b97a4fd64f5fcf15",
                    aarch64 = "5e57a5e75f5d29d1f9dcc10255fccb9815031f4720fe6759643d0ee12cf201f2",
                },
            },
        },
        windows = {
            source = "https://github.com/dprint/dprint/releases/download/${version}/dprint-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.65.0" },
            ["0.65.0"] = {
                sha256 = {
                    x86_64 = "83bc6c5df42d6001062a71ac475ceb5be119472af6afb3fce52ff13ed042db77",
                    aarch64 = "350e2e9c021f5f034796de9330a665346d50b72de892d04bb85db0d073b39112",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("windows") ~= nil
end

function installed()
    return payload.present({ "dprint" }) or payload.present({ "dprint.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("dprint: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "dprint.exe" or "dprint"

    os.tryrm(dir)

    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            fs.mkdir_p(dir)
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("dprint: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. exe .. ") exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            shell.exec({ "unzip", "-q", "-o", archive, "-d", dir })
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("dprint: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. exe .. ") exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            shell.exec({ "chmod", "+x", dir .. "/" .. exe })
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("dprint", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("dprint")
    return true
end
