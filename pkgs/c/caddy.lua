-- Caddy - extensible web server and reverse proxy with automatic HTTPS.
--
-- Platform and architecture coverage (verified 2026-11-24 against v2.11.9):
--   linux    x86_64, aarch64   caddy_<ver>_linux_<arch>.tar.gz  (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   caddy_<ver>_mac_<arch>.tar.gz
--   windows  x86_64, aarch64   caddy_<ver>_windows_<arch>.zip
--
-- Every upstream archive is flat at root (`caddy` / `caddy.exe`, `LICENSE`, `README.md`),
-- verified against upstream `caddy_2.11.9_checksums.txt` (SHA-512) and hashed (SHA-256).

package = {
    spec = "2",

    name = "caddy",
    description = "Fast, extensible web server and reverse proxy with automatic HTTPS",
    homepage = "https://caddyserver.com",
    authors = {"Matthew Holt and contributors"},
    maintainers = {"caddyserver"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/caddyserver/caddy",
    docs = "https://caddyserver.com/docs/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"web", "server", "proxy", "http", "tools"},
    keywords = {"caddy", "http", "https", "tls", "reverse-proxy", "web-server"},

    programs = {"caddy"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/caddyserver/caddy/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_mac_amd64.tar.gz",
                            aarch64 = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_mac_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    -- Upstream uses CGO_ENABLED=0; Linux binaries are static Go ELF executables
    -- with zero external shared-library dependencies.
    xpm = {
        linux = {
            source = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.11.9" },
            ["2.11.9"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5b8cb7faf8726a2028ad96a66e54e6e81e8f361bc6175e5d22bbd997cc5177fb",
                    aarch64 = "5e377cff994fc9362a6fcf695c53f226cfca3a3ef85bd3a3687cf252d6310165",
                },
            },
        },
        macosx = {
            source = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_mac_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.11.9" },
            ["2.11.9"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "22af256a2cc45606f6bfa8786cd89130529331319665926f4e972234a658fb30",
                    aarch64 = "d075afc620376679a77b453399bf7ada264cab3280b2833e4ed1372abc0c1c13",
                },
            },
        },
        windows = {
            source = "https://github.com/caddyserver/caddy/releases/download/v${version}/caddy_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.11.9" },
            ["2.11.9"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ad93112d335ee687100c4c9f11bced16ca590377976b7fe7883882b9e797e472",
                    aarch64 = "bdf5fa34e7f3646ee04f59634d66cbcbfa39516f08108d8661ff3ceb3913a0c7",
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
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/caddy") or os.isfile(dir .. "/caddy.exe")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "caddy.exe" or "caddy"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        if type(payload.unpack) == "function" then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            for _, f in ipairs({ exe, "LICENSE", "README.md" }) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("/", "\\"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, archive:gsub("/", "\\"), dir:gsub("/", "\\")))
        end
    else
        if not os.isfile(parent .. "/" .. exe) then
            error("caddy executable not found in extraction dir: " .. parent)
        end
        for _, f in ipairs({ exe, "LICENSE", "README.md" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
        system.exec(string.format([[chmod +x "%s"]], dir .. "/caddy"))
    end

    if not installed() then
        error("caddy executable is missing after install in " .. dir)
    end
    return true
end

function config()
    xvm.add("caddy", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("caddy")
    return true
end
