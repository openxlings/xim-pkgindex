-- redis - in-memory data structure store (cache, database, message broker).
--
-- Platform and architecture coverage:
--   windows  x86_64   Self-contained MSYS2 build from redis-windows/redis-windows
--                     (`Redis-8.10.3-Windows-x64-msys2.zip`, BUILD_TLS=yes;
--                     bundles msys-2.0.dll, msys-crypto-3.dll, msys-gcc_s-seh-1.dll,
--                     msys-ssl-3.dll, and msys-stdc++-6.dll, so no xim:vcruntime dep).
--
-- Linux and macOS are intentionally omitted until an `xlings-res` factory
-- target (`tools/res/build.sh`, #1295) publishes prebuilt musl-static / static
-- binaries from official redis/redis sources: upstream distributes source
-- tarballs only for POSIX, and install-time source compilation is disallowed.
package = {
    spec = "2",

    name = "redis",
    description = "Redis - in-memory key-value data structure store, cache and message broker (self-contained Windows MSYS2 build with TLS enabled)",
    homepage = "https://redis.io",
    authors = {"Salvatore Sanfilippo", "Redis Ltd."},
    maintainers = {"https://github.com/redis/redis"},
    licenses = {"RSALv2", "SSPLv1", "AGPLv3"},
    repo = "https://github.com/redis/redis",
    docs = "https://redis.io/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"database", "cache", "server", "tools"},
    keywords = {"redis", "database", "cache", "nosql", "key-value", "in-memory"},

    programs = {
        "redis-server",
        "redis-cli",
        "redis-benchmark",
        "redis-check-aof",
        "redis-check-rdb",
        "redis-sentinel",
    },
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/redis-windows/redis-windows/releases",
            resources = {
                GLOBAL = {
                    url = {
                        windows = {
                            x86_64 = "https://github.com/redis-windows/redis-windows/releases/download/${version}/Redis-${version}-Windows-x64-msys2.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        windows = {
            ["latest"] = { ref = "8.10.3" },
            ["8.10.3"] = {
                x86_64 = {
                    url = "https://github.com/redis-windows/redis-windows/releases/download/8.10.3/Redis-8.10.3-Windows-x64-msys2.zip",
                    sha256 = "af16df340525b431e9ec8dabfd625d5e7a233f82805b5418819904ea909c447f",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local PROGRAMS = {
    "redis-server",
    "redis-cli",
    "redis-benchmark",
    "redis-check-aof",
    "redis-check-rdb",
    "redis-sentinel",
}

local WIN_REQUIRED = {
    "redis-server.exe",
    "redis-cli.exe",
    "redis-benchmark.exe",
    "redis-check-aof.exe",
    "redis-check-rdb.exe",
    "redis-sentinel.exe",
    "redis.conf",
    "sentinel.conf",
}

function installed()
    return payload.present(WIN_REQUIRED)
end

function install()
    local ver = pkginfo.version()
    payload.unpack{ extracted = "Redis-" .. ver .. "-Windows-x64-msys2", strip = 1 }
    payload.require(WIN_REQUIRED)
    return true
end

function config()
    local bindir = pkginfo.install_dir()
    local root = "redis-server@" .. pkginfo.version()
    xvm.add("redis-server", { bindir = bindir })
    for i = 2, #PROGRAMS do
        xvm.add(PROGRAMS[i], { bindir = bindir, binding = root })
    end
    return true
end

function uninstall()
    for i = #PROGRAMS, 1, -1 do
        xvm.remove(PROGRAMS[i])
    end
    return true
end
