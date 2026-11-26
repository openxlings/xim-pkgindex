-- eza -- a modern, maintained replacement for `ls`, written in Rust.
--
-- Verified against official upstream release `eza-community/eza` v0.23.5
-- (published 2026-07-09); all SHA-256 digests match upstream checksums and
-- locally downloaded archives.
--
-- Supported platforms & architectures (official prebuilt binaries only):
--   * linux/x86_64  : eza_x86_64-unknown-linux-musl.tar.gz
--                     Archive root contains `./eza` (no enclosing directory).
--                     `static-pie linked` ELF with no `.interp` and zero
--                     DT_NEEDED entries.
--   * linux/aarch64 : eza_aarch64-unknown-linux-gnu.tar.gz
--                     Upstream publishes no `aarch64-unknown-linux-musl` asset,
--                     only `-gnu`. Archive root contains `./eza`. `readelf -d`
--                     shows DT_NEEDED: `libgcc_s.so.1`, `libpthread.so.0`,
--                     `libm.so.6`, `libdl.so.2`, `libc.so.6`,
--                     `ld-linux-aarch64.so.1` (GLIBC_2.17/2.18).
--                     `xpm.linux.deps.runtime` declares `xim:glibc` and
--                     `xim:gcc-runtime` to satisfy the Linux closure check on
--                     aarch64 (`x86_64` musl static-pie has sealed=0 and passes
--                     dep-closure-check.sh cleanly).
--   * windows/x86_64: eza.exe_x86_64-pc-windows-gnu.zip
--                     Archive root contains `eza.exe` (no enclosing directory).
--                     MinGW/GNU PE32+ executable linking `msvcrt.dll` and
--                     Windows system DLLs (no `VCRUNTIME140.dll` dependency).
--
-- Omitted platforms / architectures:
--   * macosx          : Upstream `eza-community/eza` does NOT publish prebuilt
--                       macOS (`apple-darwin`) release assets on GitHub
--                       Releases (macOS distribution is via Homebrew/MacPorts).
--   * windows/aarch64 : Upstream publishes no Windows ARM64 release asset.

package = {
    spec = "2",

    name = "eza",
    description = "A modern, maintained replacement for ls",
    homepage = "https://eza.rocks",
    maintainers = {"eza-community"},
    licenses = {"MIT"},
    repo = "https://github.com/eza-community/eza",
    docs = "https://github.com/eza-community/eza#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "filesystem", "tools"},
    keywords = {"ls", "eza", "exa", "cli", "filesystem", "rust"},

    programs = {"eza"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/eza-community/eza/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/eza-community/eza/releases/download/v${version}/eza_x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/eza-community/eza/releases/download/v${version}/eza_aarch64-unknown-linux-gnu.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/eza-community/eza/releases/download/v${version}/eza.exe_x86_64-pc-windows-gnu.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc", "xim:gcc-runtime" },
            },
            ["latest"] = { ref = "0.23.5" },
            ["0.23.5"] = {
                x86_64 = {
                    url = "https://github.com/eza-community/eza/releases/download/v0.23.5/eza_x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "e06eebab74b73d6b7d51a796a353824b001bea82df077706382e100815d28904",
                },
                aarch64 = {
                    url = "https://github.com/eza-community/eza/releases/download/v0.23.5/eza_aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "40b87ae8628aa2ff0f0d2dc24ab52f689631366385c3da630bae745671fd71ec",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.23.5" },
            ["0.23.5"] = {
                x86_64 = {
                    url = "https://github.com/eza-community/eza/releases/download/v0.23.5/eza.exe_x86_64-pc-windows-gnu.zip",
                    sha256 = "c830638c844a5b89d39ba662b5549903a71fa539018e813880f5b8afa77bac2e",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.winpath")

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("%.zip$") ~= nil
end

local function exe_name()
    return is_windows() and "eza.exe" or "eza"
end

function installed()
    return os.isfile(pkginfo.install_dir() .. "/" .. exe_name())
end

function install()
    local dir = pkginfo.install_dir()
    local archive = tostring(pkginfo.install_file() or "")
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local windows_target = is_windows()
    local exe = windows_target and "eza.exe" or "eza"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    local dst = dir .. "/" .. exe
    local moved = false
    for _, src in ipairs({ parent .. "/" .. exe, exe }) do
        if os.isfile(src) then
            os.mv(src, dst)
            moved = true
            break
        end
    end

    if not moved and normalized:match("%.zip$") and windows_target then
        local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
    end

    if not os.isfile(dst) then
        error("eza executable is missing after install in " .. dir)
    end
    return true
end

function config()
    xvm.add("eza", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("eza")
    return true
end
