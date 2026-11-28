-- AdGuard Home: portable upstream binaries, without service or DNS setup.
-- v1.0.0: Linux/macOS/Windows x86_64 and aarch64, verified against both
-- checksums.txt and GitHub asset digests. Every archive contains AdGuardHome/.
-- Linux ELF binaries are static (no dynamic section); both Windows binaries
-- import only kernel32.dll, with no delay imports or external CRT dependency.
-- Preserve the case-sensitive upstream program name. The lowercase package
-- is a group, not a second program/shim. Users choose their own writable
-- --config and --work-dir paths; installation never creates configuration,
-- starts the server, installs a service, or changes resolver settings.

package = {
    spec = "2",
    name = "adguardhome",
    description = "Network-wide ads and trackers blocking DNS server",
    homepage = "https://adguard.com/adguard-home/overview.html",
    authors = {"AdguardTeam"},
    maintainers = {"AdguardTeam"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/AdguardTeam/AdGuardHome",
    docs = "https://github.com/AdguardTeam/AdGuardHome/wiki",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "server", "tools"},
    keywords = {"adguardhome", "dns", "adblock", "privacy"},
    programs = {"AdGuardHome"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/AdguardTeam/AdGuardHome/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/AdguardTeam/AdGuardHome/releases/download/${tag}/AdGuardHome_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/AdguardTeam/AdGuardHome/releases/download/${tag}/AdGuardHome_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/AdguardTeam/AdGuardHome/releases/download/${tag}/AdGuardHome_darwin_amd64.zip",
                            aarch64 = "https://github.com/AdguardTeam/AdGuardHome/releases/download/${tag}/AdGuardHome_darwin_arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/AdguardTeam/AdGuardHome/releases/download/${tag}/AdGuardHome_windows_amd64.zip",
                            aarch64 = "https://github.com/AdguardTeam/AdGuardHome/releases/download/${tag}/AdGuardHome_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/AdguardTeam/AdGuardHome/releases/download/v${version}/AdGuardHome_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "19e023d98eb42eb1cdbfd6e4b6ebc937dade59e969506c62eafb3a3d6d2c1e4f",
                    aarch64 = "f5c331d29580726179d3119c0464ddacd6fdcd487a0a9e108532f58fdf772604",
                },
            },
        },
        macosx = {
            source = "https://github.com/AdguardTeam/AdGuardHome/releases/download/v${version}/AdGuardHome_darwin_${arch_alias}.zip",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "da7ce3790c268eb4f932a951d09c297dcbfcc8f256eccb86eaff8267a816b6c8",
                    aarch64 = "0a180a9a0a8e7a57b2a73e252ffcb4fda4a7c668576d0228aae96114689129ed",
                },
            },
        },
        windows = {
            source = "https://github.com/AdguardTeam/AdGuardHome/releases/download/v${version}/AdGuardHome_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "538f3863db11a054087e8b31eb7417a2c4b09a4cb689e29d59a49105dad45521",
                    aarch64 = "9fe6a71250599666c48a6a6a79f9d05069cb43490be0c39923fae14b81c69a48",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

function installed()
    return payload.present({ "AdGuardHome", "LICENSE.txt", "README.md", "CHANGELOG.md" })
        or payload.present({ "AdGuardHome.exe", "LICENSE.txt", "README.md", "CHANGELOG.md" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local exe = archive:find("_windows_", 1, true) and "AdGuardHome.exe" or "AdGuardHome"
    payload.unpack{ extracted = "AdGuardHome", strip = 1 }
    payload.require({ exe, "LICENSE.txt", "README.md", "CHANGELOG.md" })
    if exe == "AdGuardHome" then
        shell.exec({ "chmod", "+x", pkginfo.install_dir() .. "/" .. exe })
    end
    return true
end

function config()
    xvm.add("AdGuardHome", { bindir = pkginfo.install_dir() })
    xvm.add("adguardhome", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("AdGuardHome")
    xvm.remove("adguardhome")
    return true
end
