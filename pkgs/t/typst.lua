-- typst: a modern markup-based typesetting system designed as an alternative
-- to LaTeX.
--
-- Official prebuilt archives verified against typst/typst release v0.15.1
-- (upstream does not publish .sha256 sidecar files; digests computed directly
-- from the official release assets):
--   * linux/x86_64:  static-pie musl ELF (readelf -d: no DT_NEEDED / PT_INTERP;
--                    ldd: "statically linked")
--   * linux/aarch64: statically linked musl ELF (no dynamic section / PT_INTERP;
--                    ldd: "not a dynamic executable")
--     -> No glibc or gcc-runtime dependency on Linux.
--   * macosx:        x86_64-apple-darwin and aarch64-apple-darwin `.tar.xz`
--   * windows:       x86_64-pc-windows-msvc `.zip`; typst.exe imports
--                    VCRUNTIME140.dll, so `xim:vcruntime` DLLs are copied
--                    app-local beside typst.exe. Windows ARM64
--                    (`typst-aarch64-pc-windows-msvc.zip`) also imports
--                    VCRUNTIME140.dll and waits for `xim:vcruntime` ARM64 DLL
--                    support.
package = {
    spec = "2",

    name = "typst",
    description = "A new markup-based typesetting system that is powerful and easy to learn",
    homepage = "https://typst.app",
    authors = {"The Typst Project Developers"},
    maintainers = {"https://github.com/typst/typst/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/typst/typst",
    docs = "https://typst.app/docs",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "typesetting", "document", "tools"},
    keywords = {"typst", "typesetting", "pdf", "latex", "markdown", "rust"},

    programs = {"typst"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/typst/typst/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/typst/typst/releases/download/${tag}/typst-x86_64-unknown-linux-musl.tar.xz",
                            aarch64 = "https://github.com/typst/typst/releases/download/${tag}/typst-aarch64-unknown-linux-musl.tar.xz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/typst/typst/releases/download/${tag}/typst-x86_64-apple-darwin.tar.xz",
                            aarch64 = "https://github.com/typst/typst/releases/download/${tag}/typst-aarch64-apple-darwin.tar.xz",
                        },
                        windows = {
                            x86_64 = "https://github.com/typst/typst/releases/download/${tag}/typst-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "0.15.1" },
            ["0.15.1"] = {
                x86_64 = {
                    url = "https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz",
                    sha256 = "a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c",
                },
                aarch64 = {
                    url = "https://github.com/typst/typst/releases/download/v0.15.1/typst-aarch64-unknown-linux-musl.tar.xz",
                    sha256 = "5aa8d74a3d906e60ea12a66ac2f37f8eef1b14cbad7182a745e393a10c23dcee",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.15.1" },
            ["0.15.1"] = {
                x86_64 = {
                    url = "https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-apple-darwin.tar.xz",
                    sha256 = "7f9fdd9584866245de9a79e0add8f9236fae6f40a8a45e2c4771ccc14db4e0fa",
                },
                aarch64 = {
                    url = "https://github.com/typst/typst/releases/download/v0.15.1/typst-aarch64-apple-darwin.tar.xz",
                    sha256 = "48f62ed034aa3a7978309579ac6ca00045e2ef0da73114e8af27cfd8e74dc05a",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            -- Windows ARM64 waits for `xim:vcruntime` ARM64 runtime DLL support.
            ["latest"] = { ref = "0.15.1" },
            ["0.15.1"] = {
                x86_64 = {
                    url = "https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-pc-windows-msvc.zip",
                    sha256 = "19ce3551153c2fe7ee9fa2f95208310c8f4d3209fedb699e0333faf8913f6736",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

-- Upstream archives extract into `typst-<triple>/` with `typst` (or
-- `typst.exe`), LICENSE, NOTICE, and README.md at the top level.
function installed()
    return payload.present({ "typst" }) or payload.present({ "typst.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.xz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    if not is_win and normalized:match("%.tar%.xz$") and not os.isdir(parent .. "/" .. stem) and os.isfile(archive) then
        system.exec(string.format('tar -xJf "%s" -C "%s"', archive, parent))
    end

    payload.unpack{ extracted = stem, strip = 1 }

    if is_win and pkginfo.dep_install_dir then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "typst: xim:vcruntime payload directory is missing")
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
        end
    end

    payload.require({ is_win and "typst.exe" or "typst" })
    return true
end

function config()
    xvm.add("typst", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("typst")
    return true
end
