-- skeema - Declarative pure-SQL schema management for MySQL and MariaDB (`skeema` CLI).
--
-- Verified 2026-11-26 against upstream GitHub release v1.14.2
-- (`skeema/skeema`). Every SHA256 below matches both upstream
-- `skeema_checksums_1.14.2.txt` and locally downloaded archives:
--   * linux   x86_64, aarch64   `skeema_<ver>_linux_{amd64,arm64}.tar.gz`
--                               (flat archive: `skeema`, `LICENSE`, `README.md`;
--                               statically linked Go ELF64 executables with no
--                               dynamic section or external libc dependency via
--                               `readelf -d`).
--   * macosx  x86_64, aarch64   `skeema_<ver>_mac_{amd64,arm64}.tar.gz`
--                               (flat archive: `skeema`, `LICENSE`, `README.md`).
--   * windows: not published by upstream `skeema/skeema` releases.

package = {
    spec = "2",

    name = "skeema",
    description = "Declarative pure-SQL schema management for MySQL and MariaDB",
    homepage = "https://www.skeema.io",
    maintainers = {"https://github.com/skeema/skeema/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/skeema/skeema",
    docs = "https://www.skeema.io/docs/commands",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "mysql", "mariadb", "schema", "cli", "tools"},
    keywords = {"skeema", "mysql", "mariadb", "sql", "schema", "migrations", "cli"},

    programs = {"skeema"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/skeema/skeema/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/skeema/skeema/releases/download/${tag}/skeema_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/skeema/skeema/releases/download/${tag}/skeema_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/skeema/skeema/releases/download/${tag}/skeema_${version}_mac_amd64.tar.gz",
                            aarch64 = "https://github.com/skeema/skeema/releases/download/${tag}/skeema_${version}_mac_arm64.tar.gz",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/skeema/skeema/releases/download/v${version}/skeema_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.14.2" },
            ["1.14.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3c5424486cd788c0a32568c771389e60d7bd95469fbd37d522d3695be6baba6f",
                    aarch64 = "290adf616cf7fd80964f7ecbe5112abccbcded5a9604566a815691a21be41ec3",
                },
            },
        },
        macosx = {
            source = "https://github.com/skeema/skeema/releases/download/v${version}/skeema_${version}_mac_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.14.2" },
            ["1.14.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3058f7735fa098ef8a82f27e6a3c91c55b044954a65bf8df16beeab3846ec524",
                    aarch64 = "3a1f939088c58818a56321a54854bb81f43b260b0fec34afa638077276a15183",
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

local function required_files()
    return { "skeema", "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("skeema: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly into install_dir so files from unrelated flat packages in
    -- the shared download directory cannot leak into this payload.
    if os.isfile(archive) then
        system.exec(string.format('tar -xf "%s" -C "%s"', normalized, dir))
    elseif os.isfile(parent .. "/skeema") then
        for _, f in ipairs(required_files()) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
    else
        error("skeema: archive or extracted binary not found at " .. archive)
    end

    if os.isfile(dir .. "/skeema") then
        system.exec(string.format('chmod +x "%s"', dir .. "/skeema"))
    end

    payload.require(required_files())
    return true
end

function config()
    xvm.add("skeema", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("skeema")
    return true
end
