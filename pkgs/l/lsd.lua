-- lsd: the next gen ls command (lsd-rs/lsd).
--
-- Official prebuilt archives verified against lsd-rs/lsd release v1.2.0:
--   * linux/x86_64:  lsd-v1.2.0-x86_64-unknown-linux-musl.tar.gz
--                    static-pie musl ELF (readelf -l: no PT_INTERP;
--                    ldd: "statically linked")
--   * linux/aarch64: lsd-v1.2.0-aarch64-unknown-linux-musl.tar.gz
--                    static musl ELF (readelf -l: no PT_INTERP;
--                    readelf -d: no dynamic section)
--   * macosx/x86_64 & aarch64: official Mach-O 64-bit binaries
--   * windows/x86_64: lsd-v1.2.0-x86_64-pc-windows-msvc.zip
--                     PE32+ console x86-64 binary importing VCRUNTIME140.dll
--                     and UCRT API sets without bundling them, so xim:vcruntime
--                     DLLs are copied app-local beside lsd.exe (windows/aarch64
--                     is not published upstream and xim:vcruntime covers x86_64 only)
--
-- All release archives extract into `lsd-v<ver>-<target>/` containing
-- `lsd` (or `lsd.exe`), `lsd.1`, `LICENSE`, `README.md`, and `autocomplete/`.
package = {
    spec = "2",

    name = "lsd",
    description = "The next gen ls command",
    homepage = "https://github.com/lsd-rs/lsd",
    authors = {"Peltoche", "lsd-rs contributors"},
    maintainers = {"lsd-rs"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/lsd-rs/lsd",
    docs = "https://github.com/lsd-rs/lsd#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "ls", "tools"},
    keywords = {"ls", "lsd", "cli", "rust", "file-manager"},

    programs = {"lsd"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/lsd-rs/lsd/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/lsd-rs/lsd/releases/download/v${version}/lsd-v${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "1.2.0" },
            ["1.2.0"] = {
                sha256 = {
                    x86_64 = "77849da1210336534258551a581401ba19ae6b8d7b66a2a1feff148ad41e3814",
                    aarch64 = "642ecb1a763b9f790a99c83a1445c117a6813ed4edb5d498d4420423c6353eb8",
                },
            },
        },
        macosx = {
            source = "https://github.com/lsd-rs/lsd/releases/download/v${version}/lsd-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.2.0" },
            ["1.2.0"] = {
                sha256 = {
                    x86_64 = "00d3c50551b270bbdf7da97816e5ba7f5fd10294cd310165f7f8b5523e738b9c",
                    aarch64 = "9e34a5d392ff913302098aad0543dafa1883c531eaf229b82f086c3fca675e3e",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/lsd-rs/lsd/releases/download/v${version}/lsd-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.2.0" },
            ["1.2.0"] = {
                sha256 = {
                    x86_64 = "a65b9f457153934a7ce1f7e0fe1c4922a95bb2822222126e4fbaa6ee9c0d78e5",
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
    return payload.present({ "lsd" }) or payload.present({ "lsd.exe" })
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
            error("lsd: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "lsd: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("lsd: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    payload.require({ is_win and "lsd.exe" or "lsd" })
    return true
end

function config()
    xvm.add("lsd", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("lsd")
    return true
end
