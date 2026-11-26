-- hexyl: a command-line hex viewer.
--
-- Official prebuilt archives verified against sharkdp/hexyl release v0.17.0:
--   * linux/x86_64:  hexyl-v0.17.0-x86_64-unknown-linux-musl.tar.gz
--                    static-pie musl ELF (readelf -l: no PT_INTERP;
--                    readelf -d: no DT_NEEDED; ldd: "statically linked")
--   * linux/aarch64: hexyl-v0.17.0-aarch64-unknown-linux-gnu.tar.gz
--                    (upstream publishes no aarch64-unknown-linux-musl archive)
--                    dynamically linked GNU ELF, INTERP /lib/ld-linux-aarch64.so.1,
--                    NEEDED: libgcc_s.so.1, libpthread.so.0, libc.so.6
--                    (GLIBC_2.17, GCC_3.0/GCC_3.3/GCC_4.2.0)
--                    -> declares xim:glibc and xim:gcc-runtime on linux
--   * macosx/x86_64 & aarch64: official Mach-O binaries
--   * windows/x86_64: hexyl-v0.17.0-x86_64-pc-windows-msvc.zip
--                     PE32+ binary importing VCRUNTIME140.dll and UCRT API sets
--                     without bundling them, so xim:vcruntime DLLs are copied
--                     app-local beside hexyl.exe (windows/aarch64 is not published
--                     upstream and xim:vcruntime covers x86_64 only)
--
-- All release archives extract into `hexyl-v<ver>-<target>/` containing
-- `hexyl` (or `hexyl.exe`), `hexyl.1`, `CHANGELOG.md`, `README.md`, and licenses.
package = {
    spec = "2",

    name = "hexyl",
    description = "A command-line hex viewer",
    homepage = "https://github.com/sharkdp/hexyl",
    authors = {"David Peter"},
    maintainers = {"David Peter"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/sharkdp/hexyl",
    docs = "https://github.com/sharkdp/hexyl#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "hex", "tools"},
    keywords = {"hex", "viewer", "hexdump", "cli", "hexyl", "rust"},

    programs = {"hexyl"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/sharkdp/hexyl/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-aarch64-unknown-linux-gnu.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/sharkdp/hexyl/releases/download/${tag}/hexyl-${tag}-x86_64-pc-windows-msvc.zip",
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
                runtime = { "xim:glibc", "xim:gcc-runtime" },
            },
            ["latest"] = { ref = "0.17.0" },
            ["0.17.0"] = {
                x86_64 = {
                    url = "https://github.com/sharkdp/hexyl/releases/download/v0.17.0/hexyl-v0.17.0-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "82b374b800cc965f4116b9d5d6a50394945170d4f65b9ef6ced3b82b014de8a6",
                },
                aarch64 = {
                    url = "https://github.com/sharkdp/hexyl/releases/download/v0.17.0/hexyl-v0.17.0-aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "70b97648935f98801fd3c3e4758ff4e92afcf7e75316ff65d4e4f5d2e321b658",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.17.0" },
            ["0.17.0"] = {
                x86_64 = {
                    url = "https://github.com/sharkdp/hexyl/releases/download/v0.17.0/hexyl-v0.17.0-x86_64-apple-darwin.tar.gz",
                    sha256 = "55346f1dcee92bf93f32e104b0fb9d31fab8eec36532a9b6107b4e0e0aef5f46",
                },
                aarch64 = {
                    url = "https://github.com/sharkdp/hexyl/releases/download/v0.17.0/hexyl-v0.17.0-aarch64-apple-darwin.tar.gz",
                    sha256 = "d8c50f5ec688faf566ea4c13d6aa12a5681dc370dab3ffba0a9db935a5986630",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            ["latest"] = { ref = "0.17.0" },
            ["0.17.0"] = {
                x86_64 = {
                    url = "https://github.com/sharkdp/hexyl/releases/download/v0.17.0/hexyl-v0.17.0-x86_64-pc-windows-msvc.zip",
                    sha256 = "ab5c3442cff63f585553d4fce330eaa1ef1bd2584643f1a0e29ab7c13fc9566d",
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
    return payload.present({ "hexyl" }) or payload.present({ "hexyl.exe" })
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
            error("hexyl: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "hexyl: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("hexyl: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    payload.require({ is_win and "hexyl.exe" or "hexyl" })
    return true
end

function config()
    xvm.add("hexyl", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("hexyl")
    return true
end
