-- dbmate - A lightweight, framework-agnostic database migration tool (`amacneil/dbmate`).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/dbmate` on POSIX or
-- `<install_dir>/dbmate.exe` on Windows.
--
-- Verified against amacneil/dbmate release v2.38.2 (SHA-256 matched GitHub
-- release asset digests and locally downloaded bytes):
--   linux/x86_64    dbmate-linux-amd64        (ELF64 static, readelf -d: no dynamic section, readelf -l: no PT_INTERP, ldd: not dynamic)
--   linux/aarch64   dbmate-linux-arm64        (ELF64 static, readelf -d: no dynamic section, readelf -l: no PT_INTERP)
--   macosx/x86_64   dbmate-macos-amd64        (Mach-O 64-bit x86_64)
--   macosx/aarch64  dbmate-macos-arm64        (Mach-O 64-bit arm64)
--   windows/x86_64  dbmate-windows-amd64.exe  (PE32+ console x86-64, imports KERNEL32.dll + api-ms-win-crt-*; no VCRUNTIME DLL dependency; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "dbmate",
    description = "A lightweight, framework-agnostic database migration tool",
    homepage = "https://github.com/amacneil/dbmate",
    authors = {"Adrian Macneil"},
    maintainers = {"https://github.com/amacneil/dbmate/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/amacneil/dbmate",
    docs = "https://github.com/amacneil/dbmate#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "migrations", "cli", "tools"},
    keywords = {"dbmate", "database", "migrations", "sql", "postgres", "mysql", "sqlite", "clickhouse", "cli"},

    programs = {"dbmate"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/amacneil/dbmate/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/amacneil/dbmate/releases/download/${tag}/dbmate-linux-amd64",
                            aarch64 = "https://github.com/amacneil/dbmate/releases/download/${tag}/dbmate-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/amacneil/dbmate/releases/download/${tag}/dbmate-macos-amd64",
                            aarch64 = "https://github.com/amacneil/dbmate/releases/download/${tag}/dbmate-macos-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/amacneil/dbmate/releases/download/${tag}/dbmate-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/amacneil/dbmate/releases/download/v${version}/dbmate-linux-${arch_alias}",
            ["latest"] = { ref = "2.38.2" },
            ["2.38.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4c6059e4e52558605d39e8c8075f3b15f96cac293043c0c71bb464d8950f235c",
                    aarch64 = "5d70ac9a7d337daa79d3f9821cf8bab3fbcfc41b5167557d9e096b8a31a61743",
                },
            },
        },
        macosx = {
            source = "https://github.com/amacneil/dbmate/releases/download/v${version}/dbmate-macos-${arch_alias}",
            ["latest"] = { ref = "2.38.2" },
            ["2.38.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "2d504d0150dd56d3af7ed9698547942d62f144df02fed39d8d65347145d546ee",
                    aarch64 = "3cbd137e01bd068e9f0183a2da951cedfae6dbad0387f45d56a626abf4bb237a",
                },
            },
        },
        windows = {
            -- Upstream publishes only dbmate-windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/amacneil/dbmate/releases/download/v${version}/dbmate-windows-${arch_alias}.exe",
            ["latest"] = { ref = "2.38.2" },
            ["2.38.2"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "d4caa0b63ab6a54a381eb2789f8bb438bab8c1a6f63b1a6572b5a6f324d234d6",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file, dir)
    local base = (tostring(file or ""):gsub("\\", "/"):match("([^/]+)$") or ""):lower()
    if base:match("%.exe$") or base:match("^dbmate%-windows") then
        return true
    end
    if os.getenv("OS") == "Windows_NT" then
        return true
    end
    local d = tostring(dir or "")
    return d:match("^[A-Za-z]:") ~= nil or d:find("\\", 1, true) ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/dbmate") or os.isfile(dir .. "/dbmate.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src, dir)
    local target = dir .. (is_win and "/dbmate.exe" or "/dbmate")

    if not os.isfile(src) then
        error("dbmate: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("dbmate: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("dbmate", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("dbmate")
    return true
end
