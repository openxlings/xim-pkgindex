-- mkcert — a simple zero-config tool to make locally trusted development
-- certificates with any names you'd like (FiloSottile/mkcert).
--
-- Distribution: upstream publishes raw single-file binaries (not archives).
-- Because the filename is not a recognized archive format, xlings downloads
-- the raw binary directly into runtimedir without extracting; `install()` moves
-- `pkginfo.install_file()` to `<install_dir>/mkcert` (or `mkcert.exe` on Windows)
-- and marks it executable on Unix.
--
-- Verified against FiloSottile/mkcert release v1.4.4:
--   linux/x86_64    mkcert-v1.4.4-linux-amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   mkcert-v1.4.4-linux-arm64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   mkcert-v1.4.4-darwin-amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  mkcert-v1.4.4-darwin-arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  mkcert-v1.4.4-windows-amd64.exe  (PE32+ console x86-64, imports kernel32.dll only)
--   windows/aarch64 mkcert-v1.4.4-windows-arm64.exe  (PE32+ console ARM64, imports kernel32.dll only)

package = {
    spec = "2",

    name = "mkcert",
    description = "A simple zero-config tool to make locally trusted development certificates with any names you'd like",
    homepage = "https://mkcert.dev",
    maintainers = {"FiloSottile"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/FiloSottile/mkcert",
    docs = "https://github.com/FiloSottile/mkcert#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "security", "tls", "tools"},
    keywords = {"mkcert", "tls", "ssl", "certificate", "ca", "localhost", "https"},

    programs = {"mkcert"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/FiloSottile/mkcert/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/FiloSottile/mkcert/releases/download/${tag}/mkcert-v${version}-linux-amd64",
                            aarch64 = "https://github.com/FiloSottile/mkcert/releases/download/${tag}/mkcert-v${version}-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/FiloSottile/mkcert/releases/download/${tag}/mkcert-v${version}-darwin-amd64",
                            aarch64 = "https://github.com/FiloSottile/mkcert/releases/download/${tag}/mkcert-v${version}-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/FiloSottile/mkcert/releases/download/${tag}/mkcert-v${version}-windows-amd64.exe",
                            aarch64 = "https://github.com/FiloSottile/mkcert/releases/download/${tag}/mkcert-v${version}-windows-arm64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/FiloSottile/mkcert/releases/download/v${version}/mkcert-v${version}-linux-${arch_alias}",
            ["latest"] = { ref = "1.4.4" },
            ["1.4.4"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "6d31c65b03972c6dc4a14ab429f2928300518b26503f58723e532d1b0a3bbb52",
                    aarch64 = "b98f2cc69fd9147fe4d405d859c57504571adec0d3611c3eefd04107c7ac00d0",
                },
            },
        },
        macosx = {
            source = "https://github.com/FiloSottile/mkcert/releases/download/v${version}/mkcert-v${version}-darwin-${arch_alias}",
            ["latest"] = { ref = "1.4.4" },
            ["1.4.4"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a32dfab51f1845d51e810db8e47dcf0e6b51ae3422426514bf5a2b8302e97d4e",
                    aarch64 = "c8af0df44bce04359794dad8ea28d750437411d632748049d08644ffb66a60c6",
                },
            },
        },
        windows = {
            source = "https://github.com/FiloSottile/mkcert/releases/download/v${version}/mkcert-v${version}-windows-${arch_alias}.exe",
            ["latest"] = { ref = "1.4.4" },
            ["1.4.4"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d2660b50a9ed59eada480750561c96abc2ed4c9a38c6a24d93e30e0977631398",
                    aarch64 = "793747256c562622d40127c8080df26add2fb44c50906ce9db63b42a5280582e",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/mkcert") or os.isfile(dir .. "/mkcert.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/mkcert.exe" or "/mkcert")

    os.tryrm(dir)
    os.mkdir(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("mkcert: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("mkcert", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("mkcert")
    return true
end
