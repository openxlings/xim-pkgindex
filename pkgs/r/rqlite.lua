-- rqlite: upstream portable client/server archives, verified against GitHub
-- Release v10.8.0 asset digests and downloaded bytes on 2026-11-27.
-- Linux x86_64 and aarch64 are GNU ELF builds (libc/libm); both use the
-- declared glibc runtime and xlings' automatic ELF loader/RPATH sealing.
-- The amd64-musl asset is dynamically linked too, not a static alternative.
-- Windows x86_64 is PE32+ and uses Windows' UCRT. No macOS or Windows ARM64
-- portable asset exists in this release. Linux also ships rqbench; retain it.

package = {
    spec = "2",
    name = "rqlite",
    description = "Lightweight distributed relational database powered by SQLite",
    homepage = "https://rqlite.io",
    authors = {"Philip O'Toole", "rqlite contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/rqlite/rqlite",
    docs = "https://rqlite.io/docs/",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "cli", "tools"},
    keywords = {"rqlite", "sqlite", "sql", "database", "raft"},
    programs = {"rqlite", "rqlited"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/rqlite/rqlite/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/rqlite/rqlite/releases/download/${tag}/rqlite-${tag}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/rqlite/rqlite/releases/download/${tag}/rqlite-${tag}-linux-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/rqlite/rqlite/releases/download/${tag}/rqlite-${tag}-win64.zip",
                        },
                    },
                },
            },
        },
    },
    xpm = {
        linux = {
            source = { GLOBAL = "https://github.com/rqlite/rqlite/releases/download/v${version}/rqlite-v${version}-linux-${arch_alias}.tar.gz" },
            deps = {
                runtime = { "xim:glibc@2.44.3" },
                -- 0.18.0 corrupts these Go ELFs when adding RPATH.
                build = { "xim:patchelf@>=0.19.3" },
            },
            ["latest"] = { ref = "10.8.0" },
            ["10.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3bf0f1dba46b4d069ef3c49dc1fe1d1a05d5ad9d16d1de9daa4afea1f0203038",
                    aarch64 = "a26bb98755bb608cff457e3d0a2161bca42dbe8bc507a6373595c04d44d576f9",
                },
            },
        },
        windows = {
            source = { GLOBAL = "https://github.com/rqlite/rqlite/releases/download/v${version}/rqlite-v${version}-win64.zip" },
            ["latest"] = { ref = "10.8.0" },
            ["10.8.0"] = {
                sha256 = {
                    x86_64 = "a5da71daafe91b5dee72b03753f26b2871725dcc01a508a1fc5b3691e1f5ef07",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files(windows)
    if windows then return { "rqlite.exe", "rqlited.exe" } end
    return { "rqlite", "rqlited", "rqbench" }
end

function installed()
    return payload.present(required_files(false)) or payload.present(required_files(true))
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local name = archive:match("([^/]+)$")
    local windows = archive:match("%.zip$") ~= nil
    payload.unpack({ extracted = name:gsub("%.tar%.gz$", ""):gsub("%.zip$", "") })
    return payload.require(required_files(windows))
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("rqlite", { bindir = dir })
    xvm.add("rqlited", { bindir = dir, binding = "rqlite@" .. pkginfo.version() })
    if os.isfile(dir .. "/rqbench") then
        xvm.add("rqbench", { bindir = dir, binding = "rqlite@" .. pkginfo.version() })
    end
    return true
end

function uninstall()
    -- xvm.add qualifies secondary-index keys; xvm.remove expects the stored key.
    local store = pkginfo.install_dir():gsub("\\", "/"):match("/([^/]+)/[^/]+/?$") or ""
    local namespace = store:match("^(.-)%-x%-")
    local version = pkginfo.version()
    if namespace and namespace ~= "" and namespace ~= "xim" then
        version = namespace .. ":" .. version
    end
    if os.isfile(pkginfo.install_dir() .. "/rqbench") then
        xvm.remove("rqbench", version)
    end
    xvm.remove("rqlited", version)
    xvm.remove("rqlite", version)
    return true
end
