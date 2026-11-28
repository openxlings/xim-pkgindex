-- frp - A fast reverse proxy to help you expose a local server behind a NAT or firewall to the internet (`frpc`, `frps`).
--
-- Verified 2026-11-26 against upstream GitHub release v0.72.0
-- (`fatedier/frp`). Every SHA256 below matches both upstream
-- `frp_sha256_checksums.txt` and locally downloaded archives:
--   * linux   x86_64, aarch64   `.tar.gz` (`frp_<ver>_linux_<arch>/`); both
--                               binaries (`frpc`, `frps`) are statically linked
--                               Go ELFs with no dynamic section or external
--                               libc dependency (`readelf -d`, `ldd`).
--   * macosx  x86_64, aarch64   `.tar.gz` (`frp_<ver>_darwin_<arch>/`).
--   * windows x86_64, aarch64   `.zip` (`frp_<ver>_windows_<arch>/`); both
--                               PE32+ executables (`frpc.exe`, `frps.exe`)
--                               import only `kernel32.dll` (no VCRUNTIME DLL
--                               dependency).

package = {
    spec = "2",

    name = "frp",
    description = "Fast reverse proxy to help expose a local server behind a NAT or firewall to the internet",
    homepage = "https://gofrp.org",
    authors = {"fatedier"},
    maintainers = {"https://github.com/fatedier/frp/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/fatedier/frp",
    docs = "https://gofrp.org/en/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "proxy", "cli", "tools"},
    keywords = {"frp", "frpc", "frps", "reverse-proxy", "tunnel", "nat"},

    programs = {"frpc", "frps"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/fatedier/frp/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/fatedier/frp/releases/download/${tag}/frp_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/fatedier/frp/releases/download/${tag}/frp_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/fatedier/frp/releases/download/${tag}/frp_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/fatedier/frp/releases/download/${tag}/frp_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/fatedier/frp/releases/download/${tag}/frp_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/fatedier/frp/releases/download/${tag}/frp_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.72.0" },
            ["0.72.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "daf719b32ca2778770bb92955e231a07414d754378b9af328aa2642862479804",
                    aarch64 = "02180b857480302fd934e9ddbd50fe2f73229f99062f88756abc6de9df5e95cf",
                },
            },
        },
        macosx = {
            source = "https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.72.0" },
            ["0.72.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "60439dc6bf794c4182a1a4cac147d642f839d55201607208979eb23aecd09be9",
                    aarch64 = "6e8576c5b6b9914a86850f6ff4fb81c5a09e706f91f70f64d5f398558bdc9db8",
                },
            },
        },
        windows = {
            source = "https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.72.0" },
            ["0.72.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5197c1b69564089cdc229fc1260a0e25db1e722b1b7db45fe1542c3c43edf9ae",
                    aarch64 = "e4b83b66c4045971dd9a47cdef16dd02af471aaa6667dd303e63b1a669162927",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function top_dirs()
    local v = "frp_" .. pkginfo.version() .. "_"
    return {
        v .. "linux_amd64",
        v .. "linux_arm64",
        v .. "darwin_amd64",
        v .. "darwin_arm64",
        v .. "windows_amd64",
        v .. "windows_arm64",
    }
end

function installed()
    return payload.present({ "frpc", "frps", "LICENSE" })
        or payload.present({ "frpc.exe", "frps.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("_windows_") ~= nil or os.getenv("OS") == "Windows_NT"

    local candidates = top_dirs()
    if stem ~= "" then
        table.insert(candidates, 1, stem)
    end

    payload.unpack{
        extracted = candidates,
        strip = 1,
    }

    local ext = is_win and ".exe" or ""
    payload.require({ "frpc" .. ext, "frps" .. ext, "LICENSE" })
    return true
end

function config()
    local bindir = pkginfo.install_dir()
    local binding = "frp@" .. pkginfo.version()
    -- Binding-group root: the package name names no executable, so `type =
    -- "group"` prevents creating an orphan `frp` shim in `bin/`.
    xvm.add(package.name, { type = "group" })
    xvm.add("frpc", { bindir = bindir, binding = binding })
    xvm.add("frps", { bindir = bindir, binding = binding })
    return true
end

function uninstall()
    xvm.remove("frps")
    xvm.remove("frpc")
    xvm.remove(package.name)
    return true
end
