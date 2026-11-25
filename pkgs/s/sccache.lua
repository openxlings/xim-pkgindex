-- sccache - Shared compilation cache for C/C++, Rust, and CUDA (by Mozilla).
--
-- Verified against official upstream release mozilla/sccache v0.20.1:
--   * linux/x86_64   : sccache-v0.20.1-x86_64-unknown-linux-musl.tar.gz
--                      static-pie linked ELF (`readelf -d` has no DT_NEEDED,
--                      no PT_INTERP, `ldd` reports `statically linked`)
--   * linux/aarch64  : sccache-v0.20.1-aarch64-unknown-linux-musl.tar.gz
--                      statically linked ELF (no .dynamic section, no DT_NEEDED)
--   * macosx/x86_64  : sccache-v0.20.1-x86_64-apple-darwin.tar.gz (Mach-O x86_64)
--   * macosx/aarch64 : sccache-v0.20.1-aarch64-apple-darwin.tar.gz (Mach-O arm64)
--   * windows/x86_64 : sccache-v0.20.1-x86_64-pc-windows-msvc.zip (PE32+ x86-64,
--                      statically linked CRT; imports only Windows OS DLLs,
--                      no VCRUNTIME140.dll / MSVCP140.dll dependency)
--   * windows/aarch64: sccache-v0.20.1-aarch64-pc-windows-msvc.zip (PE32+ ARM64,
--                      statically linked CRT; imports only Windows OS DLLs,
--                      no VCRUNTIME140.dll / MSVCP140.dll dependency)
--
-- Every archive extracts into `sccache-v<ver>-<target>/` containing
-- `sccache` (or `sccache.exe`), `LICENSE`, and `README.md`.

package = {
    spec = "2",

    name = "sccache",
    description = "Shared compilation cache for C/C++, Rust, and CUDA",
    homepage = "https://github.com/mozilla/sccache",
    authors = {"Mozilla"},
    maintainers = {"Mozilla"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mozilla/sccache",
    docs = "https://github.com/mozilla/sccache/blob/main/README.md",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"build", "compiler", "cache", "cli", "tools"},
    keywords = {"sccache", "ccache", "cache", "rust", "c++", "cuda", "compiler"},

    programs = {"sccache"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/mozilla/sccache/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/mozilla/sccache/releases/download/${tag}/sccache-v${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/mozilla/sccache/releases/download/${tag}/sccache-v${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/mozilla/sccache/releases/download/${tag}/sccache-v${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/mozilla/sccache/releases/download/${tag}/sccache-v${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/mozilla/sccache/releases/download/${tag}/sccache-v${version}-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/mozilla/sccache/releases/download/${tag}/sccache-v${version}-aarch64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "0.20.1" },
            ["0.20.1"] = {
                x86_64 = {
                    url = "https://github.com/mozilla/sccache/releases/download/v0.20.1/sccache-v0.20.1-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "c9f6c5a3ae84d9da0956b28c357a365827bda33f3383647fc0b67484c74a5ea9",
                },
                aarch64 = {
                    url = "https://github.com/mozilla/sccache/releases/download/v0.20.1/sccache-v0.20.1-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "505324daad5fcbb1a3cab5d57d26ef42baf4d10b236df7de93a008196f1f2230",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.20.1" },
            ["0.20.1"] = {
                x86_64 = {
                    url = "https://github.com/mozilla/sccache/releases/download/v0.20.1/sccache-v0.20.1-x86_64-apple-darwin.tar.gz",
                    sha256 = "9e828824e52e12bd9c164859e893f0fb344cb3811faf7ea708f3c718d108c100",
                },
                aarch64 = {
                    url = "https://github.com/mozilla/sccache/releases/download/v0.20.1/sccache-v0.20.1-aarch64-apple-darwin.tar.gz",
                    sha256 = "d2658c9a24bab25a24fdc1917cb5b614b7c20a4ce8f363e5303d37b7e699d5ec",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.20.1" },
            ["0.20.1"] = {
                x86_64 = {
                    url = "https://github.com/mozilla/sccache/releases/download/v0.20.1/sccache-v0.20.1-x86_64-pc-windows-msvc.zip",
                    sha256 = "ca500a01139e9af8d5f5a5e69b6a0dd941ed79ed3399a91cc35bba484fe732fa",
                },
                aarch64 = {
                    url = "https://github.com/mozilla/sccache/releases/download/v0.20.1/sccache-v0.20.1-aarch64-pc-windows-msvc.zip",
                    sha256 = "9c289e040e49a2028518614cef410d8d6ccd1a8d74a0889e066a48cdd1459b67",
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

function installed()
    if type(payload.present) == "function" then
        return payload.present({ "sccache" }) or payload.present({ "sccache.exe" })
    end
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/sccache") or os.isfile(dir .. "/sccache.exe")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("sccache: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "sccache.exe" or "sccache"

    if type(payload.unpack) == "function" then
        payload.unpack{ extracted = stem, strip = 1 }
        payload.require({ exe })
    else
        os.tryrm(dir)
        local src = parent .. "/" .. stem
        if os.isdir(src) then
            local dst_parent = dir:match("^(.*)/[^/]+$")
            if dst_parent then fs.mkdir_p(dst_parent) end
            os.mv(src, dir)
        elseif is_win and os.isfile(archive) then
            fs.mkdir_p(dir)
            local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("/", "\\"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" --strip-components=1 -C "%s"',
                                      systar, archive:gsub("/", "\\"), dir:gsub("/", "\\")))
        else
            error("sccache: extracted directory not found: " .. src)
        end
        if not os.isfile(dir .. "/" .. exe) then
            error("sccache: executable missing after install at " .. dir .. "/" .. exe)
        end
    end

    if not is_win and os.isfile(dir .. "/sccache") then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/sccache"))
    end
    return true
end

function config()
    xvm.add("sccache", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("sccache")
    return true
end
