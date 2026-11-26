-- croc - Easily and securely send things from one computer to another (schollz/croc).
--
-- Verified 2026-11-26 against upstream GitHub release `schollz/croc` v11.6.6:
--   * linux/x86_64    : croc_v11.6.6_Linux-64bit.tar.gz
--                       Statically linked Go ELF64 x86-64 (`readelf -d`: no
--                       dynamic section; `ldd`: not a dynamic executable).
--   * linux/aarch64   : croc_v11.6.6_Linux-ARM64.tar.gz
--                       Statically linked Go ELF64 ARM aarch64 (`readelf -d`:
--                       no dynamic section).
--   * macosx/x86_64   : croc_v11.6.6_macOS-64bit.tar.gz
--   * macosx/aarch64  : croc_v11.6.6_macOS-ARM64.tar.gz
--   * windows/x86_64  : croc_v11.6.6_Windows-64bit.zip
--                       PE32+ x86-64 (0x8664) importing `kernel32.dll` only
--                       (no VCRUNTIME140.dll / MSVCP140.dll, no `xim:vcruntime` dep).
--   * windows/aarch64 : croc_v11.6.6_Windows-ARM64.zip
--                       PE32+ ARM64 (0xaa64) importing `kernel32.dll` only
--                       (no VCRUNTIME140.dll / MSVCP140.dll, no `xim:vcruntime` dep).
--
-- Upstream also publishes 32-bit, ARMv5/ARMv7, RISCV64, BSD, deb/rpm, and croc-web
-- assets, which are outside xlings' `{x86_64, aarch64}` matrix.
-- All six archives are flat at root (no top-level wrapper directory) containing
-- `croc` (or `croc.exe`), `croc-update` (or `croc-update.exe`), `LICENSE`,
-- `THIRD_PARTY_NOTICES.md`, and `src/codephrase/wordlists/LICENSE.txt`. Every
-- SHA-256 digest below matches upstream `croc_v11.6.6_checksums.txt`, GitHub
-- Release asset digests, and locally downloaded archives.

package = {
    spec = "2",

    name = "croc",
    description = "Easily and securely send things from one computer to another",
    homepage = "https://getcroc.com",
    authors = {"Zack Scholl"},
    maintainers = {"schollz"},
    licenses = {"MIT"},
    repo = "https://github.com/schollz/croc",
    docs = "https://github.com/schollz/croc#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "file-transfer", "security", "cli", "tools"},
    keywords = {"croc", "file-transfer", "p2p", "encrypted", "cli", "relay", "go"},

    programs = {"croc"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/schollz/croc/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/schollz/croc/releases/download/${tag}/croc_v${version}_Linux-64bit.tar.gz",
                            aarch64 = "https://github.com/schollz/croc/releases/download/${tag}/croc_v${version}_Linux-ARM64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/schollz/croc/releases/download/${tag}/croc_v${version}_macOS-64bit.tar.gz",
                            aarch64 = "https://github.com/schollz/croc/releases/download/${tag}/croc_v${version}_macOS-ARM64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/schollz/croc/releases/download/${tag}/croc_v${version}_Windows-64bit.zip",
                            aarch64 = "https://github.com/schollz/croc/releases/download/${tag}/croc_v${version}_Windows-ARM64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/schollz/croc/releases/download/v${version}/croc_v${version}_Linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "11.6.6" },
            ["11.6.6"] = {
                arch_alias = { x86_64 = "64bit", aarch64 = "ARM64" },
                sha256 = {
                    x86_64 = "da2299acafe76f6e5aff76965bc5456eeaa77da9e5b8c0bdbb188249ad047d2a",
                    aarch64 = "95bc9aa25c80a2394d5448311fb1af8adb28b86bccb9d9193989ce0af9a6bb4c",
                },
            },
        },
        macosx = {
            source = "https://github.com/schollz/croc/releases/download/v${version}/croc_v${version}_macOS-${arch_alias}.tar.gz",
            ["latest"] = { ref = "11.6.6" },
            ["11.6.6"] = {
                arch_alias = { x86_64 = "64bit", aarch64 = "ARM64" },
                sha256 = {
                    x86_64 = "fd9c570d52441abbe49e040d7230f81e4880959364e663ba15937ad20dd82d73",
                    aarch64 = "8740e6f35a2ecf886f8674951505f2d844ed431f70581ed0c1741d1221ac9f34",
                },
            },
        },
        windows = {
            source = "https://github.com/schollz/croc/releases/download/v${version}/croc_v${version}_Windows-${arch_alias}.zip",
            ["latest"] = { ref = "11.6.6" },
            ["11.6.6"] = {
                arch_alias = { x86_64 = "64bit", aarch64 = "ARM64" },
                sha256 = {
                    x86_64 = "e84910ec971b81f34c9722dc20128d23f3b962cbdbe16437b5c289f757f88016",
                    aarch64 = "a88819bfe5fa9ec86a5e25925cc813894d5f6471467b30d2f3fc459d97f5767c",
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

local function _payload_files(exe)
    return { exe, "LICENSE" }
end

local function _move_preextracted(parent, dir, exe)
    local names = { exe, "LICENSE", "THIRD_PARTY_NOTICES.md" }
    for _, f in ipairs(names) do
        if os.isfile(parent .. "/" .. f) then
            os.mv(parent .. "/" .. f, dir .. "/" .. f)
        end
    end
end

function installed()
    if type(payload) == "table" and type(payload.present) == "function" then
        return payload.present(_payload_files("croc"))
            or payload.present(_payload_files("croc.exe"))
    end
    local dir = pkginfo.install_dir()
    return (os.isfile(dir .. "/croc") or os.isfile(dir .. "/croc.exe"))
        and os.isfile(dir .. "/LICENSE")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("croc: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
        or os.getenv("OS") == "Windows_NT"
        or tostring(dir):match("^[A-Za-z]:") ~= nil
    local exe = is_win and "croc.exe" or "croc"

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly into install_dir so files from unrelated flat packages in the
    -- shared download directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            if type(payload) == "table" and type(payload.unpack) == "function" then
                payload.unpack{}
            else
                os.tryrm(dir)
                fs.mkdir_p(dir)
                local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
                local systar = sysroot .. "\\System32\\tar.exe"
                -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
                system.exec(string.format('%s -xf "%s" -C "%s"',
                                          systar, winpath.native(archive), winpath.native(dir)))
            end
        elseif os.isfile(parent .. "/" .. exe) then
            os.tryrm(dir)
            fs.mkdir_p(dir)
            _move_preextracted(parent, dir, exe)
        else
            error("croc: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            _move_preextracted(parent, dir, exe)
        else
            error("croc: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    if type(payload) == "table" and type(payload.require) == "function" then
        payload.require(_payload_files(exe))
    else
        local missing = {}
        for _, rel in ipairs(_payload_files(exe)) do
            if not os.isfile(dir .. "/" .. rel) then
                missing[#missing + 1] = rel
            end
        end
        if #missing > 0 then
            error("croc: files missing from " .. dir .. ": " .. table.concat(missing, ", "))
        end
    end

    return true
end

function config()
    xvm.add("croc", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("croc")
    return true
end
