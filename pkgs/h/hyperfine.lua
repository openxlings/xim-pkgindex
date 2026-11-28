-- hyperfine: a command-line benchmarking tool.
--
-- Official prebuilt archives verified against sharkdp/hyperfine release v2.0.0:
--   * linux/x86_64:  static-pie musl ELF binary (readelf -d: no DT_NEEDED, statically linked)
--   * linux/aarch64: static musl ELF binary (readelf -d: no dynamic section, statically linked)
--   * macosx/x86_64 & aarch64: official Mach-O binaries
--   * windows/x86_64: official MSVC PE32+ binary; hyperfine.exe dynamically imports
--     VCRUNTIME140.dll without bundling it, so xim:vcruntime DLLs are copied app-local
--     beside hyperfine.exe (windows/aarch64 is omitted until xim:vcruntime supports ARM64)
--
-- All release archives extract into `hyperfine-v<ver>-<target>/` containing
-- `hyperfine` (or `hyperfine.exe`), manpage, autocomplete scripts, and licenses.
package = {
    spec = "2",

    name = "hyperfine",
    description = "A command-line benchmarking tool",
    homepage = "https://github.com/sharkdp/hyperfine",
    authors = {"David Peter"},
    maintainers = {"David Peter"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/sharkdp/hyperfine",
    docs = "https://github.com/sharkdp/hyperfine#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "benchmark", "tools"},
    keywords = {"benchmark", "cli", "hyperfine", "performance", "rust"},

    programs = {"hyperfine"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/sharkdp/hyperfine/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sharkdp/hyperfine/releases/download/${tag}/hyperfine-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/sharkdp/hyperfine/releases/download/${tag}/hyperfine-${tag}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sharkdp/hyperfine/releases/download/${tag}/hyperfine-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/sharkdp/hyperfine/releases/download/${tag}/hyperfine-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/sharkdp/hyperfine/releases/download/${tag}/hyperfine-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "2.0.0" },
            ["2.0.0"] = {
                x86_64 = {
                    url = "https://github.com/sharkdp/hyperfine/releases/download/v2.0.0/hyperfine-v2.0.0-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "38e59087bd65520930a13cf513d8a493b7043741e8ad62349a8a9929eb61bc5c",
                },
                aarch64 = {
                    url = "https://github.com/sharkdp/hyperfine/releases/download/v2.0.0/hyperfine-v2.0.0-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "f0591c2cb8f66f2d2624d23979cf96dc99a67cb935f9925c82b9a4e3ffe5b2e1",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "2.0.0" },
            ["2.0.0"] = {
                x86_64 = {
                    url = "https://github.com/sharkdp/hyperfine/releases/download/v2.0.0/hyperfine-v2.0.0-x86_64-apple-darwin.tar.gz",
                    sha256 = "8afe204926afefa406ad320cef0672b739e5f676c623fbd6d43d779bacd684e3",
                },
                aarch64 = {
                    url = "https://github.com/sharkdp/hyperfine/releases/download/v2.0.0/hyperfine-v2.0.0-aarch64-apple-darwin.tar.gz",
                    sha256 = "590b839cfea386b384ce0b42d16daf2910277cf30950656194bb3a5f20dea81e",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            ["latest"] = { ref = "2.0.0" },
            ["2.0.0"] = {
                x86_64 = {
                    url = "https://github.com/sharkdp/hyperfine/releases/download/v2.0.0/hyperfine-v2.0.0-x86_64-pc-windows-msvc.zip",
                    sha256 = "3dec51acee1060908e67948838d6bc0a7aacde0774acebfa4afb220dcf0bc078",
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
    return payload.present({ "hyperfine" }) or payload.present({ "hyperfine.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    payload.unpack{ extracted = stem, strip = 1 }

    if is_win and pkginfo.dep_install_dir then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "hyperfine: xim:vcruntime payload directory is missing")
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
        end
    end

    payload.require({ is_win and "hyperfine.exe" or "hyperfine" })
    return true
end

function config()
    xvm.add("hyperfine", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("hyperfine")
    return true
end
