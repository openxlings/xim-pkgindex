-- SurrealDB - a scalable, distributed, collaborative, document-graph database.
--
-- Platforms and upstream release assets (surrealdb/surrealdb):
--   linux    x86_64, aarch64   surreal-v${version}.linux-{amd64,arm64}.tgz + xim:glibc + xim:gcc-runtime
--   macosx   x86_64, aarch64   surreal-v${version}.darwin-{amd64,arm64}.tgz
--   windows  x86_64            surreal-v${version}.windows-amd64.exe (raw PE binary; no windows-arm64 asset upstream)
--
-- Linux prebuilt binaries (v4.0.1) dynamically link glibc (libc.so.6, libm.so.6,
-- ld-linux, max GLIBC_2.34) and libgcc_s.so.1 (max GCC_4.2.0), so both
-- xim:glibc@>=2.39 and xim:gcc-runtime are declared for complete RPATH/INTERP closure.
-- Windows executable imports only Windows system DLLs and UCRT API sets
-- (no VCRUNTIME140.dll or MSVCP140.dll).
--
-- Binary name is `surreal` (`surreal.exe` on Windows) while package name is
-- `surrealdb`, so config() registers `surreal` as the program shim and
-- `surrealdb` as a `group` placeholder (and uninstall() removes both).

package = {
    spec = "2",

    name = "surrealdb",
    description = "A scalable, distributed, collaborative, document-graph database, for the realtime web",
    homepage = "https://surrealdb.com",
    authors = {"SurrealDB Ltd."},
    maintainers = {"https://github.com/surrealdb/surrealdb"},
    licenses = {"BSL-1.1"},
    repo = "https://github.com/surrealdb/surrealdb",
    docs = "https://surrealdb.com/docs",
    -- Mirror omitted: upstream publishes .tgz archives on Linux/macOS, which
    -- tools/xpkg_ci.py:validate_archive() does not support yet (only .tar.gz,
    -- .tar.xz, .tar.bz2, and .zip).

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "nosql", "graph", "cli", "tools"},
    keywords = {"surrealdb", "surreal", "database", "graph", "document", "sql", "surrealql", "rust"},

    programs = {"surreal"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/surrealdb/surrealdb/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.linux-amd64.tgz",
                            aarch64 = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.linux-arm64.tgz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.darwin-amd64.tgz",
                            aarch64 = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.darwin-arm64.tgz",
                        },
                        windows = {
                            x86_64 = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.windows-amd64.exe",
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
            source = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.linux-${arch_alias}.tgz",
            ["latest"] = { ref = "4.0.1" },
            ["4.0.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9d9d26313bf3f1aeffd066def9493932c79053fc9bca8f1b39f83d511f65577d",
                    aarch64 = "52b385d8894a61f650679fea21036f0261c4676e3b8e5a84ecb7e4a46baf8f66",
                },
            },
        },
        macosx = {
            source = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.darwin-${arch_alias}.tgz",
            ["latest"] = { ref = "4.0.1" },
            ["4.0.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3659503199db7586216742ab1474d0d7202ed5a1e99eff1a7f619580f766397a",
                    aarch64 = "82ef9da958ccccbf13a7d8574208dbeec2ebf4f8732a510246c8d73ef6e3947d",
                },
            },
        },
        windows = {
            -- Upstream publishes only windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.windows-${arch_alias}.exe",
            ["latest"] = { ref = "4.0.1" },
            ["4.0.1"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "150cf2138b0064dc85825b443e5a87d3bf9338a0e085d01fe09a00466576d595",
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
    if archive:lower():match("%.exe$") or archive:match("windows") then
        return "surreal.exe"
    end
    return "surreal"
end

function installed()
    return payload.present({ "surreal" }) or payload.present({ "surreal.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:lower():match("%.exe$") ~= nil or normalized:match("windows") ~= nil

    os.tryrm(dir)

    if is_win then
        if not os.isfile(archive) then
            error(string.format("surrealdb: windows binary not found at %s", archive))
        end
        fs.mkdir_p(dir)
        os.mv(archive, dir .. "/surreal.exe")
        payload.require({ "surreal.exe" })
        return true
    end

    local src = parent .. "/surreal"
    if os.isfile(src) then
        fs.mkdir_p(dir)
        os.mv(src, dir .. "/surreal")
    elseif os.isfile(archive) and (normalized:match("%.tgz$") or normalized:match("%.tar%.gz$")) then
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xzf "%s" -C "%s"', archive, dir))
    else
        error(string.format("surrealdb: extracted binary (%s) not found in %s",
                            target_exe(), parent))
    end

    system.exec(string.format('chmod +x "%s"', dir .. "/surreal"))
    payload.require({ "surreal" })
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local cfg = { bindir = dir }
    if os.isfile(dir .. "/surreal.exe") then
        cfg.alias = "surreal.exe"
    end
    xvm.add("surreal", cfg)
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove("surreal")
    xvm.remove(package.name)
    return true
end
