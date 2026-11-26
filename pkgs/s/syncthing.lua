-- Syncthing - Continuous file synchronization program.
--
-- Verified 2026-11-26 against upstream GitHub release v2.1.7
-- (`syncthing/syncthing`). Every SHA256 below matches both upstream
-- `sha256sum.txt.asc` and locally downloaded archives:
--   * linux   x86_64, aarch64   `.tar.gz` (`syncthing-linux-<arch>-v<ver>/`);
--                               both binaries are statically linked Go ELFs
--                               with no `.dynamic` section (`readelf -d`, `ldd`).
--   * macosx  x86_64, aarch64   `.zip` (`syncthing-macos-<arch>-v<ver>/`).
--   * windows x86_64, aarch64   `.zip` (`syncthing-windows-<arch>-v<ver>/`);
--                               PE32+ executables (`syncthing.exe`) import
--                               only `KERNEL32.dll` and Windows UCRT
--                               (`api-ms-win-crt-*.dll`), with no
--                               `VCRUNTIME140.dll` dependency.

package = {
    spec = "2",

    name = "syncthing",
    description = "Open Source Continuous File Synchronization",
    homepage = "https://syncthing.net",
    authors = {"The Syncthing Authors"},
    maintainers = {"https://github.com/syncthing/syncthing/graphs/contributors"},
    licenses = {"MPL-2.0"},
    repo = "https://github.com/syncthing/syncthing",
    docs = "https://docs.syncthing.net/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "sync", "cli", "tools"},
    keywords = {"syncthing", "sync", "file-sync", "p2p", "backup"},

    programs = {"syncthing"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/syncthing/syncthing/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/syncthing/syncthing/releases/download/${tag}/syncthing-linux-amd64-v${version}.tar.gz",
                            aarch64 = "https://github.com/syncthing/syncthing/releases/download/${tag}/syncthing-linux-arm64-v${version}.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/syncthing/syncthing/releases/download/${tag}/syncthing-macos-amd64-v${version}.zip",
                            aarch64 = "https://github.com/syncthing/syncthing/releases/download/${tag}/syncthing-macos-arm64-v${version}.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/syncthing/syncthing/releases/download/${tag}/syncthing-windows-amd64-v${version}.zip",
                            aarch64 = "https://github.com/syncthing/syncthing/releases/download/${tag}/syncthing-windows-arm64-v${version}.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/syncthing/syncthing/releases/download/v${version}/syncthing-linux-${arch_alias}-v${version}.tar.gz",
            ["latest"] = { ref = "2.1.7" },
            ["2.1.7"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "2edc416e7ed136b7c858ed5f3f02a3b8316589605e54c380228ceea7acbf0142",
                    aarch64 = "48e456690cd2b97e7d26b02b5ac35f62a3b36172267b144cfeaf02c993ab955c",
                },
            },
        },
        macosx = {
            source = "https://github.com/syncthing/syncthing/releases/download/v${version}/syncthing-macos-${arch_alias}-v${version}.zip",
            ["latest"] = { ref = "2.1.7" },
            ["2.1.7"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b8be90176d0f24daebae7b5aaddac52ebfae395df6d99f5e0e54656db00868cb",
                    aarch64 = "2df075b463231a307c91da657157beaed06383a941ba7ea04d33d536e3c4af38",
                },
            },
        },
        windows = {
            source = "https://github.com/syncthing/syncthing/releases/download/v${version}/syncthing-windows-${arch_alias}-v${version}.zip",
            ["latest"] = { ref = "2.1.7" },
            ["2.1.7"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3ce7da770f546a8d02b65b2e7ee31f2a3b8b7c3f990ede045590cca4172ecfe1",
                    aarch64 = "d535ffd611b3af223de64bc5dfc60c378881eb13d5c8ecb1431b7407094c15ff",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function top_dirs()
    local v = "-v" .. pkginfo.version()
    return {
        "syncthing-linux-amd64" .. v,
        "syncthing-linux-arm64" .. v,
        "syncthing-macos-amd64" .. v,
        "syncthing-macos-arm64" .. v,
        "syncthing-windows-amd64" .. v,
        "syncthing-windows-arm64" .. v,
    }
end

function installed()
    return payload.present({ "syncthing" })
        or payload.present({ "syncthing.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("windows") ~= nil or os.getenv("OS") == "Windows_NT"

    local candidates = top_dirs()
    if stem ~= "" then
        table.insert(candidates, 1, stem)
    end

    payload.unpack{
        extracted = candidates,
        strip = 1,
    }

    local ext = is_win and ".exe" or ""
    payload.require({ "syncthing" .. ext })
    return true
end

function config()
    xvm.add("syncthing", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("syncthing")
    return true
end
