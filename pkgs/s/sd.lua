-- sd: an intuitive find & replace CLI (`sd`).
--
-- Official prebuilt archives verified against chmln/sd release v1.1.0:
--   * linux/x86_64:  sd-v1.1.0-x86_64-unknown-linux-musl.tar.gz
--                    static-pie ELF (readelf -d: no PT_INTERP, no DT_NEEDED; ldd: "statically linked")
--   * linux/aarch64: sd-v1.1.0-aarch64-unknown-linux-musl.tar.gz
--                    static ELF (readelf -d: no dynamic section; ldd: not a dynamic executable)
--   * macosx:        x86_64-apple-darwin and aarch64-apple-darwin `.tar.gz` (Mach-O 64-bit)
--   * windows/x86_64: sd-v1.1.0-x86_64-pc-windows-msvc.zip
--                    PE32+ x86-64 importing VCRUNTIME140.dll and UCRT API sets,
--                    so `xim:vcruntime` DLLs are copied app-local beside sd.exe.
--   * windows/aarch64: upstream v1.1.0 publishes no Windows ARM64 release asset
--                    and `xim:vcruntime` is x86_64-only.
--
-- All release archives wrap files inside `sd-v<ver>-<target>/` containing
-- `sd` (or `sd.exe`), README.md, CHANGELOG.md, LICENSE, sd.1, and completions/.
-- Note: the v1.1.0 release binary reports `sd 1.0.0` on `--version`.
package = {
    spec = "2",

    name = "sd",
    description = "An intuitive find & replace CLI",
    homepage = "https://github.com/chmln/sd",
    authors = {"Gregory"},
    maintainers = {"https://github.com/chmln/sd/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/chmln/sd",
    docs = "https://github.com/chmln/sd#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "text", "tools"},
    keywords = {"sd", "sed", "find", "replace", "regex", "cli", "rust"},

    programs = {"sd"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/chmln/sd/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/chmln/sd/releases/download/${tag}/sd-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/chmln/sd/releases/download/${tag}/sd-${tag}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/chmln/sd/releases/download/${tag}/sd-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/chmln/sd/releases/download/${tag}/sd-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/chmln/sd/releases/download/${tag}/sd-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/chmln/sd/releases/download/v${version}/sd-v${version}-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.1.0" },
            ["1.1.0"] = {
                arch_alias = {
                    x86_64 = "x86_64-unknown-linux-musl",
                    aarch64 = "aarch64-unknown-linux-musl",
                },
                sha256 = {
                    x86_64 = "02f00f4777d43e8e95b7b8d49e1a0d6e502fed4b8e79c1c8b8063857a30caa2e",
                    aarch64 = "ec8c93c0533ff21f4851d11566808d4082544baf063d9b96ea77c27e98b7cd99",
                },
            },
        },
        macosx = {
            source = "https://github.com/chmln/sd/releases/download/v${version}/sd-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.1.0" },
            ["1.1.0"] = {
                sha256 = {
                    x86_64 = "1fca1e9c91813a8aac6821063c923107ba0f66a83309e095edcd3b202f67f97e",
                    aarch64 = "4bd3c09226376ca0a1d69589c91e86276fae36c5fbaaee669afce583f6682030",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/chmln/sd/releases/download/v${version}/sd-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.1.0" },
            ["1.1.0"] = {
                sha256 = {
                    x86_64 = "59837c2e7c911099aca1cc46b663bcdc5a949fd3e9fbbaf34fc73e5d5d71007c",
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
    return payload.present({ "sd" }) or payload.present({ "sd.exe" })
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
            error("sd: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "sd: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("sd: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    payload.require({ is_win and "sd.exe" or "sd" })
    return true
end

function config()
    xvm.add("sd", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("sd")
    return true
end
