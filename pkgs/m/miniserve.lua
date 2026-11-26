-- miniserve - a CLI tool to serve files and directories over HTTP (svenstaro/miniserve).
--
-- Distribution: upstream publishes raw single-file binaries on GitHub Releases
-- (no archive container). All 5 supported asset basenames are distinct across
-- platforms and architectures.
--
-- Verified against svenstaro/miniserve release v0.35.0 (SHA-256 matched GitHub
-- release asset digests and locally computed checksums):
--   linux/x86_64    miniserve-0.35.0-x86_64-unknown-linux-musl   (ELF64 statically linked, no dynamic section)
--   linux/aarch64   miniserve-0.35.0-aarch64-unknown-linux-musl  (ELF64 statically linked, no dynamic section)
--   macosx/x86_64   miniserve-0.35.0-x86_64-apple-darwin         (Mach-O 64-bit x86_64)
--   macosx/aarch64  miniserve-0.35.0-aarch64-apple-darwin        (Mach-O 64-bit arm64)
--   windows/x86_64  miniserve-0.35.0-x86_64-pc-windows-msvc.exe  (PE32+ CUI; static CRT, no VCRUNTIME140.dll import)
--
-- Upstream v0.35.0 publishes no windows/aarch64 binary, so windows covers x86_64 only.
-- Windows x86_64 imports only OS/UCRT-free system DLLs (advapi32, api-ms-win-core-synch-l1-2-0,
-- bcrypt, bcryptprimitives, iphlpapi, kernel32, ntdll, ws2_32), so xim:vcruntime is not needed.

package = {
    spec = "2",

    name = "miniserve",
    description = "For when you really just want to serve some files over HTTP right now",
    homepage = "https://github.com/svenstaro/miniserve",
    authors = {"svenstaro"},
    maintainers = {"svenstaro"},
    licenses = {"MIT"},
    repo = "https://github.com/svenstaro/miniserve",
    docs = "https://github.com/svenstaro/miniserve#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"web", "server", "http", "webdav", "cli", "tools"},
    keywords = {"miniserve", "http", "file-server", "static-server", "webdav", "rust"},

    programs = {"miniserve"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/svenstaro/miniserve/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/svenstaro/miniserve/releases/download/${tag}/miniserve-${version}-x86_64-unknown-linux-musl",
                            aarch64 = "https://github.com/svenstaro/miniserve/releases/download/${tag}/miniserve-${version}-aarch64-unknown-linux-musl",
                        },
                        macosx = {
                            x86_64 = "https://github.com/svenstaro/miniserve/releases/download/${tag}/miniserve-${version}-x86_64-apple-darwin",
                            aarch64 = "https://github.com/svenstaro/miniserve/releases/download/${tag}/miniserve-${version}-aarch64-apple-darwin",
                        },
                        windows = {
                            x86_64 = "https://github.com/svenstaro/miniserve/releases/download/${tag}/miniserve-${version}-x86_64-pc-windows-msvc.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/svenstaro/miniserve/releases/download/v${version}/miniserve-${version}-${arch}-unknown-linux-musl",
            ["latest"] = { ref = "0.35.0" },
            ["0.35.0"] = {
                sha256 = {
                    x86_64 = "c630ee030d5d9d83c88c5cc72f43ae215b0c214d64fd7afc92244fe369af2964",
                    aarch64 = "732b1d5b30a3903580cee9ca24b2ff04ba2a5c78fa1ba6579dc5154fc431b40a",
                },
            },
        },
        macosx = {
            source = "https://github.com/svenstaro/miniserve/releases/download/v${version}/miniserve-${version}-${arch}-apple-darwin",
            ["latest"] = { ref = "0.35.0" },
            ["0.35.0"] = {
                sha256 = {
                    x86_64 = "63a99448bf7c450f1264a1af313646df30251bdbc3284b8f4d2d55cee2b98c55",
                    aarch64 = "8e8dc916b1dc3bc2a46bf5a44308caf7db153e6940db178668929e1de40d1fbb",
                },
            },
        },
        windows = {
            source = "https://github.com/svenstaro/miniserve/releases/download/v${version}/miniserve-${version}-${arch}-pc-windows-msvc.exe",
            -- Upstream publishes no aarch64-pc-windows-msvc binary.
            ["latest"] = { ref = "0.35.0" },
            ["0.35.0"] = {
                sha256 = {
                    x86_64 = "3229e75b40b3870382d23c9a0ecec880b9bd5f6e49160ce602bb15d00f275b6a",
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
    local file = tostring(pkginfo.install_file() or "")
    return file:lower():match("%.exe$") ~= nil
end

function installed()
    return payload.present({ "miniserve" })
        or payload.present({ "miniserve.exe" })
end

function install()
    local src = tostring(pkginfo.install_file() or "")
    if src == "" then
        error("miniserve: install_file is empty")
    end
    if not os.isfile(src) then
        error("miniserve: downloaded binary not found at " .. src)
    end

    local dir = pkginfo.install_dir()
    local is_win = is_windows()
    local exe = is_win and "miniserve.exe" or "miniserve"
    local target = dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)

    if not is_win then
        shell.exec({ "chmod", "+x", target })
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("miniserve", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("miniserve")
    return true
end
