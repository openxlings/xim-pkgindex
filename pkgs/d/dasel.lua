-- Dasel - Query, transform, and modify JSON, TOML, YAML, XML, INI, HCL, KDL, and CSV (TomWright/dasel).
--
-- Verified 2026-11-26 against upstream GitHub release v3.11.2 (note unversioned
-- asset filenames under `releases/download/v3.11.2/`); every SHA256 below
-- matched both the GitHub Release asset digests and downloaded bytes:
--   linux/x86_64    dasel_linux_amd64.gz     (gzip-compressed static Go ELF, no .dynamic section)
--   linux/aarch64   dasel_linux_arm64.gz     (gzip-compressed static Go ELF, no .dynamic section)
--   macosx/x86_64   dasel_darwin_amd64.gz    (gzip-compressed Mach-O 64-bit x86_64)
--   macosx/aarch64  dasel_darwin_arm64.gz    (gzip-compressed Mach-O 64-bit arm64)
--   windows/x86_64  dasel_windows_amd64.exe  (PE32+ console x86-64, imports kernel32.dll only)
--   windows/aarch64 omitted — upstream v3.11.2 publishes no Windows ARM64 asset.
--
-- POSIX assets are single-file `.gz` compressed binaries (not `.tar.gz`), and
-- Windows assets are raw `.exe` binaries so Windows installation needs no
-- external decompressor.

package = {
    spec = "2",

    name = "dasel",
    description = "Unified querying, transformation, and modification of JSON, TOML, YAML, XML, INI, HCL, KDL and CSV",
    homepage = "https://daseldocs.tomwright.me",
    authors = {"Tom Wright"},
    maintainers = {"TomWright"},
    licenses = {"MIT"},
    repo = "https://github.com/TomWright/dasel",
    docs = "https://daseldocs.tomwright.me",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "data", "json", "yaml", "toml", "tools"},
    keywords = {"dasel", "json", "yaml", "toml", "xml", "csv", "cli", "query", "go"},

    programs = {"dasel"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/TomWright/dasel/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/TomWright/dasel/releases/download/${tag}/dasel_linux_amd64.gz",
                            aarch64 = "https://github.com/TomWright/dasel/releases/download/${tag}/dasel_linux_arm64.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/TomWright/dasel/releases/download/${tag}/dasel_darwin_amd64.gz",
                            aarch64 = "https://github.com/TomWright/dasel/releases/download/${tag}/dasel_darwin_arm64.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/TomWright/dasel/releases/download/${tag}/dasel_windows_amd64.exe",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/TomWright/dasel/releases/download/v${version}/dasel_linux_${arch_alias}.gz",
            ["latest"] = { ref = "3.11.2" },
            ["3.11.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "1af4fc41087c91dd59ab10aa13dc66a87d291e26b24bdec51480fe96cfd3ccf1",
                    aarch64 = "6f783edc1ff8e41c6bab901227740209506eecb6d67a87b3b7dda9e762c860a2",
                },
            },
        },
        macosx = {
            source = "https://github.com/TomWright/dasel/releases/download/v${version}/dasel_darwin_${arch_alias}.gz",
            ["latest"] = { ref = "3.11.2" },
            ["3.11.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "68c73f534d969599fbe1412cbcb220438c544ca6bef29fa6f6037361556f21b4",
                    aarch64 = "df63be20fd7707a770ca8a3a0ccc871ab71a48c79324cbd27e36bd3d708fc155",
                },
            },
        },
        windows = {
            source = "https://github.com/TomWright/dasel/releases/download/v${version}/dasel_windows_${arch_alias}.exe",
            ["latest"] = { ref = "3.11.2" },
            ["3.11.2"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "7f37a5aba88c702884edca3bcf2ad0a67b3f2533cbfbf1f6bc414e25e2fe1d24",
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
    return payload.present({ "dasel" }) or payload.present({ "dasel.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("dasel: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:lower():match("%.exe$") ~= nil
    local exe = is_win and "dasel.exe" or "dasel"
    local target = dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        if not os.isfile(archive) then
            error("dasel: executable not found: " .. archive)
        end
        os.mv(archive, target)
    else
        local unpacked = normalized:gsub("%.gz$", "")
        if unpacked ~= normalized and os.isfile(unpacked) then
            os.mv(unpacked, target)
        elseif normalized:match("%.gz$") and os.isfile(archive) then
            system.exec(string.format([[sh -c 'gzip -dc "$1" > "$2"' _ "%s" "%s"]], normalized, target))
        elseif os.isfile(archive) then
            os.mv(archive, target)
        else
            error("dasel: archive not found: " .. archive)
        end
        if os.isfile(target) then
            system.exec(string.format([[chmod +x "%s"]], target))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("dasel", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("dasel")
    return true
end
