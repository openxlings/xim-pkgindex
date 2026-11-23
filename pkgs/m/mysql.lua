-- MySQL Community Server - open-source relational database management system.
--
-- Platforms and sources:
--   macosx   x86_64, aarch64   Official Oracle MySQL 9.7.4 LTS tarball (.tar.gz, macos15 deployment floor, self-contained @loader_path dylibs)
--   windows  x86_64            Official Oracle MySQL 9.7.4 LTS archive (.zip) + app-local xim:vcruntime DLLs
--
-- Linux is intentionally not declared: Oracle's generic glibc Linux tarballs link
-- against `libaio.so.1` and `libnuma.so.1`, neither of which is currently provided
-- by this index (`dep-closure-check.sh` D2 rejects host-only sonames under xlings' glibc).
-- Upstream publishes no Windows ARM64 MySQL Community Server binary zip.
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
        },
        windows = {
            deps = { runtime = { "xim:vcruntime" } },
            ["latest"] = { ref = "9.7.4" },
            ["9.7"] = { ref = "9.7.4" },
            ["9.7.4"] = {
                x86_64 = {
                    url = "https://cdn.mysql.com/Downloads/MySQL-9.7/mysql-9.7.4-winx64.zip",
                    sha256 = "641bdaf01004927194c561b956f14f915a3166c9b0f9b1b5464ae63152bf4b96",
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
