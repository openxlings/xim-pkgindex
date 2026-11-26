-- agg: asciinema gif generator (asciinema/agg).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/agg` (or `agg.exe` on Windows)
-- and marks executable on Unix.
--
-- Official prebuilt binaries verified against asciinema/agg release v1.9.0:
--   * linux/x86_64:  agg-x86_64-unknown-linux-musl
--                    static-pie musl ELF (no PT_INTERP, no DT_NEEDED)
--   * linux/aarch64: agg-aarch64-unknown-linux-gnu
--                    (upstream publishes no aarch64 musl binary)
--                    dynamically linked ELF, INTERP /lib/ld-linux-aarch64.so.1,
--                    NEEDED: libgcc_s.so.1, libpthread.so.0, libm.so.6,
--                            libdl.so.2, libc.so.6
--                    (GLIBC_2.17/2.18, GCC_3.0/3.3/4.2.0)
--                    -> declares xim:glibc and xim:gcc-runtime on linux
--   * macosx:        agg-x86_64-apple-darwin and agg-aarch64-apple-darwin (Mach-O 64-bit)
--   * windows/x86_64: agg-x86_64-pc-windows-msvc.exe
--                    PE32+ x86_64 importing VCRUNTIME140.dll and UCRT API sets,
--                    so `xim:vcruntime` DLLs are copied app-local beside agg.exe
--                    (windows/aarch64 is omitted; upstream publishes no ARM64 Windows binary
--                     and xim:vcruntime covers x86_64 only).
package = {
    spec = "2",

    name = "agg",
    description = "asciinema gif generator",
    homepage = "https://docs.asciinema.org/manual/agg/",
    authors = {"Marcin Kulik"},
    maintainers = {"asciinema"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/asciinema/agg",
    docs = "https://docs.asciinema.org/manual/agg/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "terminal", "gif", "asciinema", "tools"},
    keywords = {"agg", "asciinema", "gif", "asciicast", "terminal", "recording"},

    programs = {"agg"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/asciinema/agg/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/asciinema/agg/releases/download/${tag}/agg-x86_64-unknown-linux-musl",
                            aarch64 = "https://github.com/asciinema/agg/releases/download/${tag}/agg-aarch64-unknown-linux-gnu",
                        },
                        macosx = {
                            x86_64 = "https://github.com/asciinema/agg/releases/download/${tag}/agg-x86_64-apple-darwin",
                            aarch64 = "https://github.com/asciinema/agg/releases/download/${tag}/agg-aarch64-apple-darwin",
                        },
                        windows = {
                            x86_64 = "https://github.com/asciinema/agg/releases/download/${tag}/agg-x86_64-pc-windows-msvc.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            -- Upstream only ships a dynamically linked GNU binary for aarch64
            -- (no musl build). Declare runtime deps for its ELF closure.
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0" },
            },
            source = "https://github.com/asciinema/agg/releases/download/v${version}/agg-${arch_alias}",
            ["latest"] = { ref = "1.9.0" },
            ["1.9.0"] = {
                arch_alias = {
                    x86_64 = "x86_64-unknown-linux-musl",
                    aarch64 = "aarch64-unknown-linux-gnu",
                },
                sha256 = {
                    x86_64 = "ddcbf6ca044c8ac3a434dcb9ee89fb9e3be87209982b7c2adb55f782e8f0f390",
                    aarch64 = "2b4be407b97e00e1c313a41d154ced8fa3d02c560c8f47a0db4950a2576444c9",
                },
            },
        },
        macosx = {
            source = "https://github.com/asciinema/agg/releases/download/v${version}/agg-${arch}-apple-darwin",
            ["latest"] = { ref = "1.9.0" },
            ["1.9.0"] = {
                sha256 = {
                    x86_64 = "1462150b611d231d2950d10a676303eaeb1019ff330735882aaae09b52e2e1c1",
                    aarch64 = "742b2b6230529b72f310acb835e9479496000f2eabc97b0993cabe1d7fe70171",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/asciinema/agg/releases/download/v${version}/agg-${arch}-pc-windows-msvc.exe",
            ["latest"] = { ref = "1.9.0" },
            ["1.9.0"] = {
                sha256 = {
                    x86_64 = "810baf5506e74ca65d8ed85be3db58791086c8b7b0a17c9018d7fede473f0055",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/agg") or os.isfile(dir .. "/agg.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/agg.exe" or "/agg")

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)

    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    else
        if not pkginfo.dep_install_dir then
            error("agg: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "agg: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("agg: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    if not os.isfile(target) then
        error("agg: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("agg", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("agg")
    return true
end
