-- Official standalone CLI binaries, not the Brook GUI or OpenWrt builds.
-- v20270101 is an upstream numeric release, published on 2026-09-14.
-- Linux ELF payloads are static Go executables and need no runtime packages.
package = {
    spec = "2",
    name = "brook",
    description = "A cross-platform programmable network tool",
    type = "package",
    licenses = {"GPL-3.0-only"},
    repo = "https://github.com/txthinking/brook",
    homepage = "https://www.txthinking.com/brook.html",
    docs = "https://www.txthinking.com/brook.html",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "tools"},
    keywords = {"brook", "proxy", "socks5", "network"},
    programs = {"brook"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/txthinking/brook/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/txthinking/brook/releases/download/${tag}/brook_linux_amd64",
                        aarch64 = "https://github.com/txthinking/brook/releases/download/${tag}/brook_linux_arm64",
                    },
                    macosx = {
                        x86_64 = "https://github.com/txthinking/brook/releases/download/${tag}/brook_darwin_amd64",
                        aarch64 = "https://github.com/txthinking/brook/releases/download/${tag}/brook_darwin_arm64",
                    },
                    windows = {
                        x86_64 = "https://github.com/txthinking/brook/releases/download/${tag}/brook_windows_amd64.exe",
                        aarch64 = "https://github.com/txthinking/brook/releases/download/${tag}/brook_windows_arm64.exe",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/txthinking/brook/releases/download/v${version}/brook_linux_${arch_alias}",
            ["latest"] = { ref = "20270101" },
            ["20270101"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f8fbef10e740334a21d7b0c020594210d9b0c47b2bf13c3056793107e0de1344",
                    aarch64 = "5c631bcae7a0fbb52e084df508561f3f38f8c5c476506737eb12d4d435e4c15e",
                },
            },
        },
        macosx = {
            source = "https://github.com/txthinking/brook/releases/download/v${version}/brook_darwin_${arch_alias}",
            ["latest"] = { ref = "20270101" },
            ["20270101"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fa857d9f6df1a3600de24322ea196f66b8e9610057014bc2228e3e8e5a13d8bc",
                    aarch64 = "899de1b5c5c70f750177b856589105690e6811c174de1996127fa34b7a8e48be",
                },
            },
        },
        windows = {
            source = "https://github.com/txthinking/brook/releases/download/v${version}/brook_windows_${arch_alias}.exe",
            ["latest"] = { ref = "20270101" },
            ["20270101"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "21bbf4b29c3fdcf7d751a319b278b4b6155151a5cf3eef699105d6f3b41a7e29",
                    aarch64 = "9474d1349d31558543e0a1e237df19ba2b6caa943e7e28284b7f12f4cc1c59dd",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/brook") or os.isfile(dir .. "/brook.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local windows = tostring(src):lower():match("%.exe$") ~= nil
    local target = dir .. (windows and "/brook.exe" or "/brook")
    if not os.isfile(src) then
        error("brook: downloaded binary is missing: " .. tostring(src))
    end
    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not windows then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("brook: installed executable is missing: " .. target)
    end
    return true
end

function config()
    xvm.add("brook", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("brook")
    return true
end
