-- NATS Server - High-Performance server for NATS.io, the cloud and edge native
-- messaging system.
--
-- Verified 2026-11-25 against the upstream GitHub release v2.15.3: every
-- SHA256 below was verified against both the upstream `SHA256SUMS` file and
-- downloaded archives. All six archives pack a single top-level directory
-- `nats-server-v2.15.3-<os>-<arch>/` containing `nats-server[.exe]`,
-- `LICENSE`, and `README.md`.
--
-- Binary inspection:
--   linux/x86_64, linux/aarch64: statically linked Go ELF executables
--     (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable).
--   windows/x86_64, windows/aarch64: PE32+ console executables importing only
--     `kernel32.dll` (no external MSVC runtime DLL dependency).
package = {
    spec = "2",

    name = "nats-server",
    description = "High-Performance server for NATS.io, the cloud and edge native messaging system",
    homepage = "https://nats.io",
    authors = {"The NATS Authors"},
    maintainers = {"https://github.com/nats-io/nats-server/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/nats-io/nats-server",
    docs = "https://docs.nats.io/running-a-nats-service/introduction",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"messaging", "server", "network", "tools"},
    keywords = {"nats", "nats-server", "messaging", "pubsub", "jetstream", "cloud-native"},

    programs = {"nats-server"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/nats-io/nats-server/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/nats-io/nats-server/releases/download/${tag}/nats-server-v${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/nats-io/nats-server/releases/download/${tag}/nats-server-v${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/nats-io/nats-server/releases/download/${tag}/nats-server-v${version}-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/nats-io/nats-server/releases/download/${tag}/nats-server-v${version}-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/nats-io/nats-server/releases/download/${tag}/nats-server-v${version}-windows-amd64.zip",
                            aarch64 = "https://github.com/nats-io/nats-server/releases/download/${tag}/nats-server-v${version}-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/nats-io/nats-server/releases/download/v${version}/nats-server-v${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.15.3" },
            ["2.15.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "32e18c1e78d7ef4f86e483070eef3abb2647c3d4d67e29668077c7ad81da0797",
                    aarch64 = "4a2088b3ec7103bf79d6484f55e80ab5d10204811d9ae6f7a33e8544d98dd45d",
                },
            },
        },
        macosx = {
            source = "https://github.com/nats-io/nats-server/releases/download/v${version}/nats-server-v${version}-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.15.3" },
            ["2.15.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d274cfb9d6e26ffbb04007bfe744d46a8b4f4e5d218741f8ee89aa687c658bc1",
                    aarch64 = "a7e25e32247024449e32dcb7129ff416dca3a2cd569fe3c205603ecf8fe5f810",
                },
            },
        },
        windows = {
            source = "https://github.com/nats-io/nats-server/releases/download/v${version}/nats-server-v${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "2.15.3" },
            ["2.15.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b202c46689a56b17e88939b6c53a25294021b000b9c7225209bcb1bbda347bad",
                    aarch64 = "76e51178ca20683d537c1bf627dd0fff8b28114c6aafd371c49a5ccb62a1355b",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function _top_dirs(ver)
    return {
        "nats-server-v" .. ver .. "-linux-amd64",
        "nats-server-v" .. ver .. "-linux-arm64",
        "nats-server-v" .. ver .. "-darwin-amd64",
        "nats-server-v" .. ver .. "-darwin-arm64",
        "nats-server-v" .. ver .. "-windows-amd64",
        "nats-server-v" .. ver .. "-windows-arm64",
    }
end

function installed()
    return payload.present({ "nats-server", "LICENSE" })
        or payload.present({ "nats-server.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local filename = normalized:match("([^/]+)$") or ""
    local is_win = normalized:match("%.zip$") ~= nil
    local dir_name = filename:match("^(nats%-server%-.+)%.tar%.gz$")
        or filename:match("^(nats%-server%-.+)%.zip$")

    payload.unpack{
        extracted = dir_name and { dir_name } or _top_dirs(pkginfo.version()),
        strip = 1,
    }
    payload.require({ is_win and "nats-server.exe" or "nats-server", "LICENSE" })
    return true
end

function config()
    xvm.add("nats-server", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("nats-server")
    return true
end
