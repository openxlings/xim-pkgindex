-- migrate - Database migrations CLI (`golang-migrate/migrate`).
--
-- Verified 2026-11-26 against upstream GitHub release v4.20.1
-- (`golang-migrate/migrate`). Every SHA256 below matches both upstream
-- `sha256sum.txt` and locally downloaded archives:
--   * linux   x86_64, aarch64   `migrate.linux-{amd64,arm64}.tar.gz` (flat:
--                               `migrate`, `LICENSE`, `README.md`); static Go
--                               ELFs with no dynamic section or external libc
--                               dependency (`readelf -d`, `ldd`).
--   * macosx  x86_64, aarch64   `migrate.darwin-{amd64,arm64}.tar.gz` (flat).
--   * windows x86_64, aarch64   `migrate.windows-{amd64,arm64}.zip` (flat:
--                               `migrate.exe`, `LICENSE`, `README.md`); PE32+
--                               console executables importing only `kernel32.dll`
--                               (no VCRUNTIME DLL dependency).

package = {
    spec = "2",

    name = "migrate",
    description = "Database migrations CLI supporting multiple databases and migration sources",
    homepage = "https://github.com/golang-migrate/migrate",
    authors = {"Matthias Kadenbach", "Dale Hui"},
    maintainers = {"https://github.com/golang-migrate/migrate/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/golang-migrate/migrate",
    docs = "https://github.com/golang-migrate/migrate#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "migrations", "cli", "tools"},
    keywords = {"migrate", "golang-migrate", "database", "migrations", "sql", "cli"},

    programs = {"migrate"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/golang-migrate/migrate/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/golang-migrate/migrate/releases/download/${tag}/migrate.linux-amd64.tar.gz",
                            aarch64 = "https://github.com/golang-migrate/migrate/releases/download/${tag}/migrate.linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/golang-migrate/migrate/releases/download/${tag}/migrate.darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/golang-migrate/migrate/releases/download/${tag}/migrate.darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/golang-migrate/migrate/releases/download/${tag}/migrate.windows-amd64.zip",
                            aarch64 = "https://github.com/golang-migrate/migrate/releases/download/${tag}/migrate.windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/golang-migrate/migrate/releases/download/v${version}/migrate.linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "4.20.1" },
            ["4.20.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b1e13121d4178b7804a9fb29dca62d57b732390f7e5ae33f2cd65e9b192e1bd4",
                    aarch64 = "03ea70d9ba535b68fe03602120d1856a567cd0fa2fbca3748ba8070e9d4b8f60",
                },
            },
        },
        macosx = {
            source = "https://github.com/golang-migrate/migrate/releases/download/v${version}/migrate.darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "4.20.1" },
            ["4.20.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "acb7c3756fbfea5ae2985eaeb5aa7769ecfdd43bd179a7240f9bebf4b45fee89",
                    aarch64 = "d66f87e41eb6beda9328f0ef99a34c1c51411a0663a782111fb519f3652506c2",
                },
            },
        },
        windows = {
            source = "https://github.com/golang-migrate/migrate/releases/download/v${version}/migrate.windows-${arch_alias}.zip",
            ["latest"] = { ref = "4.20.1" },
            ["4.20.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bf68e2fdd1c8efd3cac59c6cb4cddca51546c402e3fc616172329d7686875ce8",
                    aarch64 = "7e7bf6db821e35831f4a36a57a8b64dd8f897a2a5e9d5c7921355fff3676032f",
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

local function required_files(exe)
    return { exe, "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("migrate"))
        or payload.present(required_files("migrate.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("migrate: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "migrate.exe" or "migrate"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly from the archive into install_dir so files from unrelated flat
    -- packages in the shared download directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            for _, f in ipairs(required_files(exe)) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            error("migrate: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            for _, f in ipairs(required_files(exe)) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            error("migrate: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("migrate", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("migrate")
    return true
end
