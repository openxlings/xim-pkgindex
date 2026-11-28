-- cloudflared - Cloudflare Tunnel client (cloudflare/cloudflared).
--
-- Platform and architecture coverage (verified against cloudflare/cloudflared 2026.11.2):
--   linux    x86_64, aarch64   cloudflared-linux-{amd64,arm64}   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   cloudflared-{amd64,arm64}.pkg     (signed component .pkg, cpio Payload holds ./cloudflared)
--   windows  x86_64            cloudflared-windows-amd64.exe     (PE32+ console, imports KERNEL32.dll + UCRT API sets only)
--
-- Notes:
--   * Upstream also publishes 386, arm, armhf, .deb, .rpm, .msi, and FIPS variants,
--     omitted as xlings targets x86_64 and aarch64. Upstream does not publish a
--     windows-arm64 release asset.
--   * macOS uses the official signed `.pkg` assets rather than `.tgz` because
--     `tools/xpkg_ci.py` mirror validation does not support `.tgz`.
--   * Linux ELFs have no dynamic section or PT_INTERP (`readelf -d`/`-l`) and
--     Windows PE imports only `KERNEL32.dll` and Windows 10 Universal CRT API
--     sets (`api-ms-win-crt-*.dll`), with no VCRUNTIME140.dll dependency.

package = {
    spec = "2",

    name = "cloudflared",
    description = "Cloudflare Tunnel client (formerly Argo Tunnel)",
    homepage = "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/",
    authors = {"Cloudflare, Inc."},
    maintainers = {"https://github.com/cloudflare/cloudflared"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/cloudflare/cloudflared",
    docs = "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "tunnel", "proxy", "security", "cli", "tools"},
    keywords = {"cloudflared", "cloudflare", "tunnel", "argo", "proxy", "dns", "ssh", "zero-trust"},

    programs = {"cloudflared"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/cloudflare/cloudflared/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-linux-amd64",
                            aarch64 = "https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-amd64.pkg",
                            aarch64 = "https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-arm64.pkg",
                        },
                        windows = {
                            x86_64 = "https://github.com/cloudflare/cloudflared/releases/download/${tag}/cloudflared-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/cloudflare/cloudflared/releases/download/${version}/cloudflared-linux-${arch_alias}",
            ["latest"] = { ref = "2026.11.2" },
            ["2026.11.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "56f13335143ec0e22772963290683a84a04114a35ec64cbc794a4d39ff9bb8cf",
                    aarch64 = "04a7b7f08bce85d56b26ffe1fdbfbb21a074495a363d16f0783c40e25b5c5281",
                },
            },
        },
        macosx = {
            source = "https://github.com/cloudflare/cloudflared/releases/download/${version}/cloudflared-${arch_alias}.pkg",
            ["latest"] = { ref = "2026.11.2" },
            ["2026.11.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ff0b005a556b5d3f8c247677bb5486bb5689888a2dd8da71815654462716df4a",
                    aarch64 = "111085fc547a158401376582c342da9f1abd80e7e9eebe76770e1b9ed1f69a03",
                },
            },
        },
        windows = {
            -- Upstream publishes only windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/cloudflare/cloudflared/releases/download/${version}/cloudflared-windows-${arch_alias}.exe",
            ["latest"] = { ref = "2026.11.2" },
            ["2026.11.2"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "555b46c85582461d189cac30d14ad05480d612613801be9f110b8ce08c5b2113",
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
    return payload.present({ "cloudflared" }) or payload.present({ "cloudflared.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("cloudflared: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:lower():match("%.exe$") ~= nil or normalized:lower():match("windows") ~= nil
    local is_pkg = normalized:lower():match("%.pkg$") ~= nil
    local exe = is_win and "cloudflared.exe" or "cloudflared"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_pkg then
        -- macOS upstream ships a signed component .pkg whose cpio Payload holds ./cloudflared.
        if os.isfile(archive) then
            local pkg_tmp = dir .. "/._pkg"
            os.tryrm(pkg_tmp)
            system.exec(string.format([[pkgutil --expand-full "%s" "%s"]], normalized, pkg_tmp))
            local candidates = {
                pkg_tmp .. "/Payload/cloudflared",
                pkg_tmp .. "/Payload/usr/local/bin/cloudflared",
            }
            local moved = false
            for _, src in ipairs(candidates) do
                if os.isfile(src) then
                    os.mv(src, dir .. "/cloudflared")
                    moved = true
                    break
                end
            end
            os.tryrm(pkg_tmp)
            if not moved then
                error("cloudflared: extracted binary not found inside " .. normalized)
            end
        elseif os.isfile(parent .. "/cloudflared") then
            os.mv(parent .. "/cloudflared", dir .. "/cloudflared")
        else
            error("cloudflared: neither pkg archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        -- Linux and Windows release assets are standalone single-file binaries.
        if os.isfile(archive) then
            os.mv(archive, dir .. "/" .. exe)
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("cloudflared: binary not found at " .. archive)
        end
    end

    if not is_win and os.isfile(dir .. "/cloudflared") then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/cloudflared"))
    end

    payload.require({ exe })
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local cfg = { bindir = dir }
    if os.isfile(dir .. "/cloudflared.exe") then
        cfg.alias = "cloudflared.exe"
    end
    xvm.add("cloudflared", cfg)
    return true
end

function uninstall()
    xvm.remove("cloudflared")
    return true
end
