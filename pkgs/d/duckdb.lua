-- DuckDB - an analytical in-process SQL database management system.
--
-- Platforms and upstream release assets (duckdb/duckdb):
--   linux    x86_64, aarch64   duckdb-cli-linux-{amd64,arm64}.tar.gz + xim:glibc + xim:gcc-runtime
--   macosx   x86_64, aarch64   duckdb-cli-osx-{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   duckdb-cli-windows-{amd64,arm64}.zip
--
-- Linux prebuilt binaries dynamically link glibc (libc, libm, libdl, libpthread,
-- ld-linux) and GCC's C++ runtime (libstdc++.so.6, libgcc_s.so.1), so both
-- xim:glibc and xim:gcc-runtime are declared for complete RPATH/INTERP closure.
-- Windows executables import only Windows system DLLs (KERNEL32, WS2_32, RstrtMgr).
package = {
    spec = "2",

    name = "duckdb",
    description = "An in-process analytical SQL database management system",
    homepage = "https://duckdb.org",
    authors = {"DuckDB Foundation", "Mark Raasveldt", "Hannes Mühleisen"},
    maintainers = {"https://github.com/duckdb/duckdb"},
    licenses = {"MIT"},
    repo = "https://github.com/duckdb/duckdb",
    docs = "https://duckdb.org/docs/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "sql", "analytics", "cli", "tools"},
    keywords = {"duckdb", "sql", "olap", "analytics", "parquet", "database"},

    programs = {"duckdb"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/duckdb/duckdb/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-osx-amd64.tar.gz",
                            aarch64 = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-osx-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-windows-amd64.zip",
                            aarch64 = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime" },
            },
            source = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.0.1" },
            ["2.0.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b676268be4d39e4e41a904442c9796c9914e645cc085c7505f048f2c992b5eca",
                    aarch64 = "84e37891fcc45c887e30220f51a4914995cd8174139e87f8efd311ac83c956a7",
                },
            },
        },
        macosx = {
            source = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-osx-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.0.1" },
            ["2.0.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f63131b6e1e69ded1a55e0b96f2f1d77658e4cf5b666346487c927820a4d53c5",
                    aarch64 = "7809dc1ea9215db53f76bdd539e38186c2310b6a3b5800581bf65876048556aa",
                },
            },
        },
        windows = {
            source = "https://github.com/duckdb/duckdb/releases/download/v${version}/duckdb-cli-windows-${arch_alias}.zip",
            ["latest"] = { ref = "2.0.1" },
            ["2.0.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9df372514a06e9edbdca294cc43fdfbfc4e80799c8292d0964239cfcbb8718cf",
                    aarch64 = "484f1c0df9949f33c30dd81288ac28bbf751a01c61045e8ad2c03527d33e3634",
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

local function target_exe()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    if archive:match("windows") or archive:match("%.exe$") then
        return "duckdb.exe"
    end
    return "duckdb"
end

function installed()
    return payload.present({ "duckdb" }) or payload.present({ "duckdb.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_zip = normalized:match("%.zip$") ~= nil
    local is_win = normalized:match("windows") ~= nil

    os.tryrm(dir)

    local found = nil
    for _, name in ipairs({ "duckdb", "duckdb.exe" }) do
        local src = parent .. "/" .. name
        if os.isfile(src) then
            found = name
            fs.mkdir_p(dir)
            os.mv(src, dir .. "/" .. name)
            break
        end
    end

    if not found then
        if is_zip then
            payload.unpack{}
            found = is_win and "duckdb.exe" or "duckdb"
        else
            error(string.format("duckdb: extracted binary (%s) not found in %s",
                                target_exe(), parent))
        end
    end

    if found == "duckdb" then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. found))
    end

    payload.require({ found })
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local cfg = { bindir = dir }
    if os.isfile(dir .. "/duckdb.exe") then
        cfg.alias = "duckdb.exe"
    end
    xvm.add("duckdb", cfg)
    return true
end

function uninstall()
    xvm.remove("duckdb")
    return true
end
