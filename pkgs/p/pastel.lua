-- pastel: a command-line tool to generate, analyze, convert and manipulate colors.
--
-- Official prebuilt archives verified against sharkdp/pastel release v0.12.0:
--   * linux/x86_64:  pastel-v0.12.0-x86_64-unknown-linux-musl.tar.gz
--                    static-pie musl ELF (no PT_INTERP, no DT_NEEDED; ldd: "statically linked")
--   * linux/aarch64: pastel-v0.12.0-aarch64-unknown-linux-gnu.tar.gz
--                    (upstream publishes no aarch64 musl archive)
--                    dynamically linked ELF, INTERP /lib/ld-linux-aarch64.so.1,
--                    NEEDED: libc.so.6, libm.so.6, libpthread.so.0,
--                            libgcc_s.so.1, libdl.so.2
--                    (GLIBC_2.17/2.18, GCC_3.0/3.3/4.2.0)
--                    -> declares xim:glibc and xim:gcc-runtime on linux
--   * macosx:        x86_64-apple-darwin and aarch64-apple-darwin `.tar.gz`
--   * windows/x86_64: pastel-v0.12.0-x86_64-pc-windows-msvc.zip
--                    PE32+ x86_64 importing VCRUNTIME140.dll and UCRT API sets,
--                    so `xim:vcruntime` DLLs are copied app-local beside pastel.exe
--                    (windows/aarch64 is omitted; upstream publishes no ARM64 Windows zip
--                     and xim:vcruntime covers x86_64 only).
--
-- All release archives extract into `pastel-v<ver>-<target>/` containing
-- `pastel` (or `pastel.exe`), manpages, autocomplete scripts, and licenses.
package = {
    spec = "2",

    name = "pastel",
    description = "A command-line tool to generate, analyze, convert and manipulate colors",
    homepage = "https://github.com/sharkdp/pastel",
    authors = {"David Peter"},
    maintainers = {"David Peter"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/sharkdp/pastel",
    docs = "https://github.com/sharkdp/pastel#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "color", "tools"},
    keywords = {"color", "cli", "pastel", "palette", "rust"},

    programs = {"pastel"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/sharkdp/pastel/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sharkdp/pastel/releases/download/${tag}/pastel-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/sharkdp/pastel/releases/download/${tag}/pastel-${tag}-aarch64-unknown-linux-gnu.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sharkdp/pastel/releases/download/${tag}/pastel-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/sharkdp/pastel/releases/download/${tag}/pastel-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/sharkdp/pastel/releases/download/${tag}/pastel-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
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
            source = "https://github.com/sharkdp/pastel/releases/download/v${version}/pastel-v${version}-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.12.0" },
            ["0.12.0"] = {
                arch_alias = {
                    x86_64 = "x86_64-unknown-linux-musl",
                    aarch64 = "aarch64-unknown-linux-gnu",
                },
                sha256 = {
                    x86_64 = "96ddd6593d08fd3868f2423f18ed5c6117a5f1aab335c1fc9e8347db7f219f2a",
                    aarch64 = "f437e19974399ab7ae99fa52b76a2cdfad4fafafde3b48243100d371894935ba",
                },
            },
        },
        macosx = {
            source = "https://github.com/sharkdp/pastel/releases/download/v${version}/pastel-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.12.0" },
            ["0.12.0"] = {
                sha256 = {
                    x86_64 = "ea941d276c41285b188cd51ff497145a348fa0f0e955e7c2ddd4ea7ca42e712c",
                    aarch64 = "7fd81518fac1dab7bd60e4759194a942c51bb911ef5de4513f4a9e3fb4b8ac1c",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/sharkdp/pastel/releases/download/v${version}/pastel-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.12.0" },
            ["0.12.0"] = {
                sha256 = {
                    x86_64 = "51e914b0308b089f032c481e786d67a9f11d8857f4ffe99405f3452e77582393",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "pastel" }) or payload.present({ "pastel.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    payload.unpack{ extracted = stem, strip = 1 }

    if is_win then
        if not pkginfo.dep_install_dir then
            error("pastel: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "pastel: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("pastel: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    payload.require({ is_win and "pastel.exe" or "pastel" })
    return true
end

function config()
    xvm.add("pastel", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("pastel")
    return true
end
