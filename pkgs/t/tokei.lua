-- tokei -- count your code, quickly (written in Rust).
--
-- Verified against official upstream release `XAMPPRocky/tokei` v12.1.2
-- (published 2021-01-12), which is the latest stable upstream release with
-- prebuilt binary assets (v13.0.0, v14.0.0, and v15.0.0 have no release assets).
--
-- Supported platforms & architectures (official prebuilt binaries only):
--   * linux/x86_64  : tokei-x86_64-unknown-linux-musl.tar.gz
--                     Archive root contains `tokei` (no enclosing directory).
--                     Statically linked musl ELF with no dynamic section and
--                     zero DT_NEEDED entries.
--   * linux/aarch64 : tokei-aarch64-unknown-linux-gnu.tar.gz
--                     Upstream publishes no `aarch64-unknown-linux-musl` asset,
--                     only `-gnu`. Archive root contains `tokei`. `readelf -d`
--                     shows DT_NEEDED: `libdl.so.2`, `libgcc_s.so.1`,
--                     `libc.so.6`, `libpthread.so.0` (GLIBC_2.17/2.18,
--                     interpreter `/lib/ld-linux-aarch64.so.1`).
--                     `xpm.linux.deps.runtime` declares `xim:glibc` and
--                     `xim:gcc-runtime` to satisfy the Linux closure check on
--                     aarch64 (`x86_64` static musl has 0 external sonames).
--   * windows/x86_64: tokei-x86_64-pc-windows-msvc.exe (standalone PE32+ binary,
--                     no archive wrapper). Imports MSVC runtime (`VCRUNTIME140`
--                     and UCRT API sets), so `xpm.windows.deps.runtime`
--                     declares `xim:vcruntime` and install() copies its DLLs
--                     app-local beside `tokei.exe`.
--
-- Omitted platforms / architectures:
--   * macosx          : Upstream v12.1.2 only publishes `x86_64-apple-darwin`
--                       and has NO `aarch64-apple-darwin` archive. Because CI
--                       runs `posix-test.sh` on `macos-latest` (arm64) whenever
--                       `xpm.macosx` is declared, `xpm.macosx` is omitted.
--   * windows/aarch64 : Upstream publishes no Windows ARM64 release asset.

package = {
    spec = "2",

    name = "tokei",
    description = "Count your code, quickly.",
    homepage = "https://github.com/XAMPPRocky/tokei",
    authors = {"Erin Power"},
    maintainers = {"Erin Power"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/XAMPPRocky/tokei",
    docs = "https://github.com/XAMPPRocky/tokei#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "statistics", "tools"},
    keywords = {"tokei", "cloc", "loc", "lines", "statistics", "rust"},

    programs = {"tokei"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/XAMPPRocky/tokei/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/XAMPPRocky/tokei/releases/download/${tag}/tokei-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/XAMPPRocky/tokei/releases/download/${tag}/tokei-aarch64-unknown-linux-gnu.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/XAMPPRocky/tokei/releases/download/${tag}/tokei-x86_64-pc-windows-msvc.exe",
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
            ["latest"] = { ref = "12.1.2" },
            ["12.1.2"] = {
                x86_64 = {
                    url = "https://github.com/XAMPPRocky/tokei/releases/download/v12.1.2/tokei-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "331e77046935d655dce8d97ebb943fcc7e9684586dadf3d197f3df5e760cd31b",
                },
                aarch64 = {
                    url = "https://github.com/XAMPPRocky/tokei/releases/download/v12.1.2/tokei-aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "ef514fd12cfc3ee2d1725e5ecb866ee1123163004879ec285b22f3323389ebe2",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            ["latest"] = { ref = "12.1.2" },
            ["12.1.2"] = {
                x86_64 = {
                    url = "https://github.com/XAMPPRocky/tokei/releases/download/v12.1.2/tokei-x86_64-pc-windows-msvc.exe",
                    sha256 = "b1d6c4b18f5fa238bd2c6e47caa65a7a3e4a1bd0de6df0b7c19c8083c941f57b",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("%.exe$") ~= nil
end

function installed()
    return payload.present({ "tokei" }) or payload.present({ "tokei.exe" })
end

function install()
    local dir = pkginfo.install_dir()
    local archive = tostring(pkginfo.install_file() or "")
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local windows_target = is_windows()
    local exe = windows_target and "tokei.exe" or "tokei"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    local dst = dir .. "/" .. exe
    if windows_target then
        if os.isfile(archive) then
            os.mv(archive, dst)
        else
            local filename = normalized:match("([^/]+)$") or ""
            for _, src in ipairs({ parent .. "/" .. filename, filename, parent .. "/tokei.exe", "tokei.exe" }) do
                if src ~= "" and os.isfile(src) then
                    os.mv(src, dst)
                    break
                end
            end
        end
        if pkginfo.dep_install_dir then
            local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                               "tokei: xim:vcruntime payload directory is missing")
            for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
                os.cp(dll, dir)
            end
        end
    else
        for _, src in ipairs({ parent .. "/" .. exe, exe }) do
            if os.isfile(src) then
                os.mv(src, dst)
                break
            end
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("tokei", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("tokei")
    return true
end
