-- vegeta - HTTP load testing tool and library (tsenart/vegeta).
--
-- Verified 2026-11-26 against upstream GitHub release v12.13.0 and
-- `vegeta_12.13.0_checksums.txt`: every SHA-256 below matched the upstream
-- checksums file, GitHub release asset digests, and downloaded archive bytes:
--   linux/x86_64    vegeta_12.13.0_linux_amd64.tar.gz   (static Go ELF, no .dynamic section)
--   linux/aarch64   vegeta_12.13.0_linux_arm64.tar.gz   (static Go ELF, no .dynamic section)
--   macosx/x86_64   vegeta_12.13.0_darwin_amd64.tar.gz  (Mach-O 64-bit x86_64)
--   macosx/aarch64  vegeta_12.13.0_darwin_arm64.tar.gz  (Mach-O 64-bit arm64)
--   windows/x86_64  vegeta_12.13.0_windows_amd64.zip    (PE32+ x86-64 CUI, imports kernel32.dll only)
--   windows/aarch64 vegeta_12.13.0_windows_arm64.zip    (PE32+ ARM64 CUI, imports kernel32.dll only)
--
-- Upstream also publishes 32-bit x86, ARMv6/7, FreeBSD, and OpenBSD builds,
-- which are outside `archs`. All six supported archives contain only the
-- single executable at root (`vegeta` / `vegeta.exe`, no wrapper directory).

package = {
    spec = "2",

    name = "vegeta",
    description = "HTTP load testing tool and library",
    homepage = "https://github.com/tsenart/vegeta",
    authors = {"Tomás Senart"},
    maintainers = {"https://github.com/tsenart/vegeta/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/tsenart/vegeta",
    docs = "https://github.com/tsenart/vegeta#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"http", "benchmark", "cli", "tools"},
    keywords = {"vegeta", "http", "load-testing", "benchmark", "cli", "go"},

    programs = {"vegeta"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/tsenart/vegeta/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/tsenart/vegeta/releases/download/${tag}/vegeta_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/tsenart/vegeta/releases/download/${tag}/vegeta_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/tsenart/vegeta/releases/download/${tag}/vegeta_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/tsenart/vegeta/releases/download/${tag}/vegeta_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/tsenart/vegeta/releases/download/${tag}/vegeta_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/tsenart/vegeta/releases/download/${tag}/vegeta_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PE executables import only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/tsenart/vegeta/releases/download/v${version}/vegeta_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "12.13.0" },
            ["12.13.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e8759ce45c14e18374bdccd3ba6068197bc3a9f9b7e484db3837f701b9d12e61",
                    aarch64 = "950381173a5575e25e8e086f36fc03bf65d61a2433329b48e41e1cb5e4133bba",
                },
            },
        },
        macosx = {
            source = "https://github.com/tsenart/vegeta/releases/download/v${version}/vegeta_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "12.13.0" },
            ["12.13.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4e912c83ce07db4e1e394e1cbb657f2396dff2f7ed90f03869a184cc17d0f994",
                    aarch64 = "fc408e242c4f4839e6fe536dbf1130bb02f430134827f6d831bf367a0929a799",
                },
            },
        },
        windows = {
            source = "https://github.com/tsenart/vegeta/releases/download/v${version}/vegeta_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "12.13.0" },
            ["12.13.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "421362edb7c8e1b97db9faf43806d2a8850067afc97c2f1bf9bc5cdcdfc9c0b6",
                    aarch64 = "d8852495569b006b5db920f437865756573a494123aa8ec5d7af166cf2ce1263",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

function installed()
    return payload.present({ "vegeta" }) or payload.present({ "vegeta.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("vegeta: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "vegeta.exe" or "vegeta"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly from the archive into install_dir so files from unrelated flat
    -- packages in the shared download directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("vegeta: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            shell.exec({ "tar", "-xzf", normalized, "-C", dir })
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("vegeta: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            shell.exec({ "chmod", "+x", dir .. "/" .. exe })
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("vegeta", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("vegeta")
    return true
end
