-- goose - Database migration tool supporting SQL migrations and Go functions (pressly/goose).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/goose` (or `goose.exe` on Windows).
--
-- Verified against pressly/goose release v3.30.2 (SHA-256 matched
-- checksums.txt, GitHub release digests, and downloaded bytes):
--   linux/x86_64    goose_linux_x86_64        (ELF64 static Go binary, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   goose_linux_arm64         (ELF64 static Go binary, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   goose_darwin_x86_64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  goose_darwin_arm64        (Mach-O 64-bit arm64)
--   windows/x86_64  goose_windows_x86_64.exe  (PE32+ console, imports kernel32.dll only)
--   windows/aarch64 goose_windows_arm64.exe   (PE32+ console, imports kernel32.dll only)

package = {
    spec = "2",

    name = "goose",
    description = "Database migration tool supporting SQL migrations and Go functions",
    homepage = "https://pressly.github.io/goose/",
    maintainers = {"https://github.com/pressly/goose/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/pressly/goose",
    docs = "https://pressly.github.io/goose/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "migration", "sql", "cli", "devops", "tools"},
    keywords = {"goose", "database", "migration", "sql", "postgres", "mysql", "sqlite", "cli"},

    programs = {"goose"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/pressly/goose/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/pressly/goose/releases/download/${tag}/goose_linux_x86_64",
                            aarch64 = "https://github.com/pressly/goose/releases/download/${tag}/goose_linux_arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/pressly/goose/releases/download/${tag}/goose_darwin_x86_64",
                            aarch64 = "https://github.com/pressly/goose/releases/download/${tag}/goose_darwin_arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/pressly/goose/releases/download/${tag}/goose_windows_x86_64.exe",
                            aarch64 = "https://github.com/pressly/goose/releases/download/${tag}/goose_windows_arm64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/pressly/goose/releases/download/v${version}/goose_linux_${arch_alias}",
            ["latest"] = { ref = "3.30.2" },
            ["3.30.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "82d5818c1f33a28396822ce6bbaa18d05ee1c4591ed4b2257a2395743f2d12b5",
                    aarch64 = "405956e6af9cfc4d585423eadccdce74c337b51d632986c83bbeeb763d235730",
                },
            },
        },
        macosx = {
            source = "https://github.com/pressly/goose/releases/download/v${version}/goose_darwin_${arch_alias}",
            ["latest"] = { ref = "3.30.2" },
            ["3.30.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "28340a6e48349b6178d23c3f6b7e7a53bb3fa4442741b9c5b0bd73c5e5d22b9e",
                    aarch64 = "3254eac36eb103683f097594974af043033fc2e63553c745678b327fbf26e892",
                },
            },
        },
        windows = {
            source = "https://github.com/pressly/goose/releases/download/v${version}/goose_windows_${arch_alias}.exe",
            ["latest"] = { ref = "3.30.2" },
            ["3.30.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "15b48a6018045bc88049c7806230306a1154fa143152cfa2b553ca08798682e7",
                    aarch64 = "e067d7da7c7f76abeb1217c786bafdc80c8348419ae4d74a9d7cc247e3a18c69",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/goose") or os.isfile(dir .. "/goose.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/goose.exe" or "/goose")

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("goose: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("goose", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("goose")
    return true
end
