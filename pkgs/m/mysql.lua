-- MySQL Community Server - open-source relational database management system.
--
-- Platforms and sources:
--   macosx   x86_64, aarch64   Official Oracle MySQL 9.7.4 / 8.4.11 LTS / 8.0.46 GA tarballs (.tar.gz, macos15 deployment floor, self-contained @loader_path dylibs)
--   windows  x86_64            Official Oracle MySQL 9.7.4 / 8.4.11 LTS / 8.0.46 GA archives (.zip) + app-local xim:vcruntime DLLs
--
-- Linux is intentionally not declared: Oracle's generic glibc Linux tarballs link
-- against `libaio.so.1` and `libnuma.so.1`, neither of which is currently provided
-- by this index (`dep-closure-check.sh` D2 rejects host-only sonames under xlings' glibc).
-- Upstream publishes no Windows ARM64 MySQL Community Server binary zip.
-- 8.4.11 is the latest 8.4 LTS release covering macOS x86_64+aarch64 and Windows x64
-- (8.4.13 lacks a macOS x86_64 tarball); 5.7.44 is omitted because it lacks macOS arm64.
--
-- First-time server startup requires initializing a data directory before launching
-- `mysqld`:
--   mysqld --initialize-insecure --datadir=<data-dir>
--
-- `ci = { mirror = true }` is set intentionally so CN users get mirror coverage;
-- MySQL Community Server is licensed under GPL-2.0-only, which permits mirroring
-- unmodified official binaries.
package = {
    spec = "2",

    name = "mysql",
    description = "MySQL Community Server - relational database server and CLI client (mysqld, mysql, mysqldump, mysqladmin)",
    homepage = "https://www.mysql.com",
    authors = {"Oracle Corporation"},
    maintainers = {"Oracle Corporation"},
    licenses = {"GPL-2.0-only"},
    repo = "https://github.com/mysql/mysql-server",
    docs = "https://dev.mysql.com/doc/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "sql", "server", "tools"},
    keywords = {"mysql", "mysqld", "database", "sql", "rdbms"},

    programs = {
        "mysql",
        "mysqld",
        "mysqladmin",
        "mysqldump",
        "mysqlcheck",
        "mysqlimport",
        "mysqlshow",
        "mysqlbinlog",
    },
    xvm_enable = true,

    xpm = {
        macosx = {
            ["latest"] = { ref = "9.7.4" },
            ["9.7"] = { ref = "9.7.4" },
            ["8.4"] = { ref = "8.4.11" },
            ["8.0"] = { ref = "8.0.46" },
            ["9.7.4"] = {
                x86_64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-9.7/mysql-9.7.4-macos15-x86_64.tar.gz",
                    sha256 = "4d5e110fe4e8fc87d6a4c30355096914be2606687cb5818a353190764302c26a",
                },
                aarch64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-9.7/mysql-9.7.4-macos15-arm64.tar.gz",
                    sha256 = "abf378ff27753325c908d687a3060f025c58b6530eda53ff4a0c6fc5ff3d7716",
                },
            },
            ["8.4.11"] = {
                x86_64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-macos15-x86_64.tar.gz",
                    sha256 = "90e8aea10698d01b978f0179e72e8d5e2cbe9f9bd5771e88b0b75d7c82244d3f",
                },
                aarch64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-macos15-arm64.tar.gz",
                    sha256 = "b96e00493bc3499b9ffd7f08d65c5d64933af0383a8287d9873b64f94c2d6009",
                },
            },
            ["8.0.46"] = {
                x86_64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.46-macos15-x86_64.tar.gz",
                    sha256 = "8590bc6c3203fe17f51f757dc9132fb755d1b73cbdad9d12a67f85025a3c3b8f",
                },
                aarch64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.46-macos15-arm64.tar.gz",
                    sha256 = "6ca4a361a45f5019fbf6d500997986b4aaf6f0e30ff9c41179d1e8ecd635f3db",
                },
            },
        },
        windows = {
            deps = { runtime = { "xim:vcruntime" } },
            ["latest"] = { ref = "9.7.4" },
            ["9.7"] = { ref = "9.7.4" },
            ["8.4"] = { ref = "8.4.11" },
            ["8.0"] = { ref = "8.0.46" },
            ["9.7.4"] = {
                x86_64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-9.7/mysql-9.7.4-winx64.zip",
                    sha256 = "641bdaf01004927194c561b956f14f915a3166c9b0f9b1b5464ae63152bf4b96",
                },
            },
            ["8.4.11"] = {
                x86_64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-winx64.zip",
                    sha256 = "a492371d687d2bab088b0062581144a0044b8964baefdf4faa579292b423d25c",
                },
            },
            ["8.0.46"] = {
                x86_64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.46-winx64.zip",
                    sha256 = "28e9eda019d88eff4478d811ea2110b83f02a3966be157fe91cc55def3ab0d4d",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local PROGRAMS = {
    "mysql",
    "mysqld",
    "mysqladmin",
    "mysqldump",
    "mysqlcheck",
    "mysqlimport",
    "mysqlshow",
    "mysqlbinlog",
}

local function expected_files(ext)
    local out = {}
    for _, prog in ipairs(PROGRAMS) do
        out[#out + 1] = "bin/" .. prog .. ext
    end
    return out
end

function installed()
    return payload.present(expected_files("")) or payload.present(expected_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    payload.unpack{ extracted = stem, strip = 1 }

    if is_win and pkginfo.dep_install_dir then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "mysql: xim:vcruntime payload directory is missing")
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir .. "/bin")
        end
    end

    payload.require(expected_files(is_win and ".exe" or ""))
    return true
end

function config()
    local bindir = pkginfo.install_dir() .. "/bin"
    local root = "mysql@" .. pkginfo.version()
    xvm.add("mysql", { bindir = bindir })
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
