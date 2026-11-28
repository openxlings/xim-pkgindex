-- delta: syntax-highlighting pager for git, diff, grep, and blame output.
--
-- Official prebuilt archives verified against dandavison/delta release 0.22.0:
--   * linux/x86_64: static-pie musl binary (no dynamic library deps)
--   * linux/aarch64: dynamically linked GNU binary (upstream publishes no musl
--     build for aarch64; readelf -d shows libgcc_s.so.1, libpthread.so.0,
--     libm.so.6, libdl.so.2, libc.so.6, ld-linux-aarch64.so.1 -> xim:glibc +
--     xim:gcc-runtime)
--   * macosx: aarch64-apple-darwin only (upstream 0.22.0 has no official
--     x86_64-apple-darwin archive, so x86_64 is omitted rather than built from
--     source)
--   * windows: x86_64-pc-windows-msvc only (upstream has no official Windows
--     ARM64 archive; delta.exe imports VCRUNTIME140.dll, so xim:vcruntime DLLs
--     are copied app-local beside delta.exe)
package = {
    spec = "2",

    name = "delta",
    description = "A syntax-highlighting pager for git, diff, grep, and blame output",
    homepage = "https://dandavison.github.io/delta/",
    authors = {"Dan Davison"},
    maintainers = {"Dan Davison"},
    licenses = {"MIT"},
    repo = "https://github.com/dandavison/delta",
    docs = "https://dandavison.github.io/delta/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "git", "diff", "tools"},
    keywords = {"delta", "git", "diff", "pager", "syntax-highlighting", "rust"},

    programs = {"delta"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/dandavison/delta/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-aarch64-unknown-linux-gnu.tar.gz",
                        },
                        macosx = {
                            aarch64 = "https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-x86_64-pc-windows-msvc.zip",
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
            ["latest"] = { ref = "0.22.0" },
            ["0.22.0"] = {
                x86_64 = {
                    url = "https://github.com/dandavison/delta/releases/download/0.22.0/delta-0.22.0-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "04bc8cde7e73e8603ce75fe6054453f316ca47263aa7d5832748ab442f5ad051",
                },
                aarch64 = {
                    url = "https://github.com/dandavison/delta/releases/download/0.22.0/delta-0.22.0-aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "9f462d3ffb74d188964f2f0c408619f1d63f60425f87f3dce83bab0db1c71313",
                },
            },
        },
        macosx = {
            -- Only aarch64-apple-darwin is published by upstream 0.22.0.
            ["latest"] = { ref = "0.22.0" },
            ["0.22.0"] = {
                aarch64 = {
                    url = "https://github.com/dandavison/delta/releases/download/0.22.0/delta-0.22.0-aarch64-apple-darwin.tar.gz",
                    sha256 = "1baa389d6de21e41f6de8a328ed2e19a4fdef6112641420bf591ead50299cab5",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            -- Only x86_64-pc-windows-msvc is published by upstream 0.22.0.
            ["latest"] = { ref = "0.22.0" },
            ["0.22.0"] = {
                x86_64 = {
                    url = "https://github.com/dandavison/delta/releases/download/0.22.0/delta-0.22.0-x86_64-pc-windows-msvc.zip",
                    sha256 = "c9e1eb86cceaa4713c47bdeb4ce2476b78ac7f1082dac8b9cb66cad508cbdd5c",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

-- Upstream archives extract into `delta-<ver>-<target>/` with `delta` (or
-- `delta.exe`), LICENSE, and README.md at the top level.
function installed()
    return payload.present({ "delta" }) or payload.present({ "delta.exe" })
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
                           "delta: xim:vcruntime payload directory is missing")
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
        end
    end

    payload.require({ is_win and "delta.exe" or "delta" })
    return true
end

function config()
    xvm.add("delta", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("delta")
    return true
end
