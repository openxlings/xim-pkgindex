-- TruffleHog - find, verify, and analyze leaked credentials (trufflesecurity/trufflehog).
--
-- Verified 2026-11-26 against upstream GitHub release v3.100.1 and
-- `trufflehog_3.100.1_checksums.txt`: every SHA256 below matched both the
-- upstream checksums file and the downloaded release archive bytes:
--   linux/x86_64    trufflehog_3.100.1_linux_amd64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   trufflehog_3.100.1_linux_arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64   trufflehog_3.100.1_darwin_amd64.tar.gz
--   macosx/aarch64  trufflehog_3.100.1_darwin_arm64.tar.gz
--   windows/x86_64  trufflehog_3.100.1_windows_amd64.tar.gz  (PE32+ x86-64, imports kernel32.dll only)
--   windows/aarch64 trufflehog_3.100.1_windows_arm64.tar.gz  (PE32+ ARM64, imports kernel32.dll only)
--
-- All six archives are flat `.tar.gz` at root (`trufflehog`/`trufflehog.exe`,
-- `LICENSE`, `README.md`, `docs/man/trufflehog.1` with no top-level wrapper
-- directory). `install()` extracts directly from `pkginfo.install_file()` into
-- a clean `install_dir()` (using `%SystemRoot%\System32\tar.exe` on Windows
-- because `libs/payload.lua` only handles `.zip`, and system `tar` on POSIX) so
-- shared `runtimedir` contents from other flat archives cannot leak into
-- trufflehog's payload.

package = {
    spec = "2",

    name = "trufflehog",
    description = "Find, verify, and analyze leaked credentials",
    homepage = "https://trufflesecurity.com",
    authors = {"Truffle Security"},
    maintainers = {"https://github.com/trufflesecurity/trufflehog/graphs/contributors"},
    licenses = {"AGPL-3.0"},
    repo = "https://github.com/trufflesecurity/trufflehog",
    docs = "https://github.com/trufflesecurity/trufflehog#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "scanner", "git", "devops", "cli"},
    keywords = {"trufflehog", "secrets", "credentials", "security", "scanner", "git"},

    programs = {"trufflehog"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/trufflesecurity/trufflehog/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/trufflesecurity/trufflehog/releases/download/${tag}/trufflehog_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/trufflesecurity/trufflehog/releases/download/${tag}/trufflehog_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/trufflesecurity/trufflehog/releases/download/${tag}/trufflehog_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/trufflesecurity/trufflehog/releases/download/${tag}/trufflehog_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/trufflesecurity/trufflehog/releases/download/${tag}/trufflehog_${version}_windows_amd64.tar.gz",
                            aarch64 = "https://github.com/trufflesecurity/trufflehog/releases/download/${tag}/trufflehog_${version}_windows_arm64.tar.gz",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/trufflesecurity/trufflehog/releases/download/v${version}/trufflehog_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.100.1" },
            ["3.100.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b2460688116f29ce33f1afe16d14fef3fa3db928e74ba55a6c9fed392c60ad69",
                    aarch64 = "017b4f2124199c164579caff85c07839be1c79f6e5908b0f1dd3bccc775c6452",
                },
            },
        },
        macosx = {
            source = "https://github.com/trufflesecurity/trufflehog/releases/download/v${version}/trufflehog_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.100.1" },
            ["3.100.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "928cb350c72861077e1e05cca1570513418c54ad22a4fd61141f9fc97634c62f",
                    aarch64 = "baf7600403c029adcaabbc7efd262c5e26b7c654fb88d7334eb56682aaa2f000",
                },
            },
        },
        windows = {
            source = "https://github.com/trufflesecurity/trufflehog/releases/download/v${version}/trufflehog_${version}_windows_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.100.1" },
            ["3.100.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c09bf4660d3d38adb270932bb5cd58ee572867b315cf70dccfe3d217654016ea",
                    aarch64 = "cc7014d631b900836db8fc0892aa4dd4dc5a8674240ecc50185d740948935ed4",
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
import("xim.pkgindex.winpath")

local function required_files(exe)
    return { exe, "LICENSE", "README.md", "docs/man/trufflehog.1" }
end

function installed()
    return payload.present(required_files("trufflehog"))
        or payload.present(required_files("trufflehog.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("trufflehog: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("_windows_") ~= nil
        or normalized:match("windows") ~= nil
        or normalized:match("^[A-Za-z]:/") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "trufflehog.exe" or "trufflehog"

    if not os.isfile(archive) then
        error("trufflehog: archive not found: " .. archive)
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s" -C "%s"',
                                  systar, winpath.native(archive), winpath.native(dir)))
    else
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/trufflehog") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/trufflehog"))
        end
    end

    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("trufflehog", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("trufflehog")
    return true
end
