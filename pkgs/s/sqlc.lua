-- sqlc - Generate type-safe code from SQL (`sqlc` CLI).
--
-- Verified 2026-11-26 against upstream GitHub release v1.31.1
-- (`sqlc-dev/sqlc`). Every SHA256 below matches upstream release digests and
-- locally downloaded archives:
--   * linux   x86_64, aarch64   `sqlc_<ver>_linux_{amd64,arm64}.tar.gz`
--                               (flat archive containing `sqlc`; statically
--                               linked Go ELF with no dynamic section or
--                               external libc dependency via `readelf -d`/`ldd`).
--   * macosx  x86_64, aarch64   `sqlc_<ver>_darwin_{amd64,arm64}.tar.gz`
--                               (flat archive containing `sqlc`).
--   * windows x86_64, aarch64   `sqlc_<ver>_windows_{amd64,arm64}.zip`
--                               (flat archive containing `sqlc.exe`; PE32+
--                               console executables importing only
--                               `kernel32.dll`, no VCRUNTIME dependency).

package = {
    spec = "2",

    name = "sqlc",
    description = "Generate type-safe code from SQL",
    homepage = "https://sqlc.dev",
    maintainers = {"https://github.com/sqlc-dev/sqlc/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/sqlc-dev/sqlc",
    docs = "https://docs.sqlc.dev",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "sql", "codegen", "cli", "tools"},
    keywords = {"sqlc", "sql", "codegen", "postgresql", "mysql", "sqlite", "go"},

    programs = {"sqlc"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/sqlc-dev/sqlc/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sqlc-dev/sqlc/releases/download/${tag}/sqlc_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/sqlc-dev/sqlc/releases/download/${tag}/sqlc_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sqlc-dev/sqlc/releases/download/${tag}/sqlc_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/sqlc-dev/sqlc/releases/download/${tag}/sqlc_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/sqlc-dev/sqlc/releases/download/${tag}/sqlc_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/sqlc-dev/sqlc/releases/download/${tag}/sqlc_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/sqlc-dev/sqlc/releases/download/v${version}/sqlc_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.31.1" },
            ["1.31.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "497ae4fcdfa64c5b0c311ffe4c2bd991e43991e82e5367792ed78bc2dca27354",
                    aarch64 = "b7cae247740d0c51a1e657479e5b2d21e6fef428f596682a01bc55bf4ab8a23d",
                },
            },
        },
        macosx = {
            source = "https://github.com/sqlc-dev/sqlc/releases/download/v${version}/sqlc_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.31.1" },
            ["1.31.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c5af76772e3785d21663a62697056b383f07629979b1bd25b93872e73dbd519b",
                    aarch64 = "21602158c99eb1f2bae197a66abfb1941d1e9e50b23125bb193349c6b1acc71e",
                },
            },
        },
        windows = {
            source = "https://github.com/sqlc-dev/sqlc/releases/download/v${version}/sqlc_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.31.1" },
            ["1.31.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "352711fa7dcb05dcdfefca0ad71b2c9a74fd090f8d7fc609419de4cbc725429f",
                    aarch64 = "b3d7a016c177923cb426f0d544d3ffbe2ff97306137bb77f668af709b5613692",
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

function installed()
    return payload.present({ "sqlc" })
        or payload.present({ "sqlc.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil or os.getenv("OS") == "Windows_NT"
    local bin = is_win and "sqlc.exe" or "sqlc"

    os.tryrm(dir)

    if is_win and normalized:match("%.zip$") then
        payload.unpack{}
    elseif os.isfile(archive) then
        -- Extract flat .tar.gz directly into install_dir so files never mix
        -- with other flat archives in the shared runtimedir.
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xf "%s" -C "%s"', archive, dir))
        if not is_win then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. bin))
        end
    elseif os.isfile(parent .. "/" .. bin) then
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. bin, dir .. "/" .. bin)
        if not is_win then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. bin))
        end
    else
        error("sqlc: archive or extracted binary not found at " .. archive)
    end

    payload.require({ bin })
    return true
end

function config()
    xvm.add("sqlc", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("sqlc")
    return true
end
