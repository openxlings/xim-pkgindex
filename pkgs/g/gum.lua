-- gum - A tool for glamorous shell scripts (charmbracelet/gum).
--
-- Verified 2026-11-26 against upstream GitHub release `charmbracelet/gum` v2.0.2:
--   * linux/x86_64    : gum_2.0.2_Linux_x86_64.tar.gz
--                       Statically linked Go ELF64 x86-64 (`readelf -d`: no
--                       dynamic section; `ldd`: not a dynamic executable).
--   * linux/aarch64   : gum_2.0.2_Linux_arm64.tar.gz
--                       Statically linked Go ELF64 ARM aarch64 (`readelf -d`:
--                       no dynamic section).
--   * macosx/x86_64   : gum_2.0.2_Darwin_x86_64.tar.gz (Mach-O 64-bit x86_64)
--   * macosx/aarch64  : gum_2.0.2_Darwin_arm64.tar.gz (Mach-O 64-bit arm64)
--   * windows/x86_64  : gum_2.0.2_Windows_x86_64.zip
--                       PE32+ console x86-64 executable importing `kernel32.dll`
--                       only (no external MSVC runtime DLL dependency).
--   * windows/aarch64 : omitted — upstream v2.0.2 publishes no Windows ARM64 asset.
--
-- All five archives pack a single top-level directory `gum_<ver>_<OS>_<arch>/`
-- containing `gum` (or `gum.exe`), `LICENSE`, `README.md`, `completions/`, and
-- `manpages/`. Every SHA-256 digest below matches upstream `checksums.txt`,
-- GitHub Release asset digests, and locally downloaded archives.

package = {
    spec = "2",

    name = "gum",
    description = "A tool for glamorous shell scripts",
    homepage = "https://github.com/charmbracelet/gum",
    authors = {"Charmbracelet"},
    maintainers = {"https://github.com/charmbracelet/gum/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/charmbracelet/gum",
    docs = "https://github.com/charmbracelet/gum#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "shell", "tui", "tools"},
    keywords = {"gum", "charm", "cli", "tui", "shell", "prompt", "go"},

    programs = {"gum"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/charmbracelet/gum/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/charmbracelet/gum/releases/download/${tag}/gum_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/gum/releases/download/${tag}/gum_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/charmbracelet/gum/releases/download/${tag}/gum_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/gum/releases/download/${tag}/gum_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/charmbracelet/gum/releases/download/${tag}/gum_${version}_Windows_x86_64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/charmbracelet/gum/releases/download/v${version}/gum_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.0.2" },
            ["2.0.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d842e06d93dbed90af48cb8dd10698db6f22e331fc40346bb37bbc753109edc2",
                    aarch64 = "8ebf8b54ec1e8c81f2bb58b59ff9b70998186a4d11375f0cf357b80e0ccfa1d5",
                },
            },
        },
        macosx = {
            source = "https://github.com/charmbracelet/gum/releases/download/v${version}/gum_${version}_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.0.2" },
            ["2.0.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5374966c7c7199ea879fcaa525ddc6d447a098d3d35496e430a9a1ef38d30485",
                    aarch64 = "4777a69b1170b8db23c95d5889fb32186cfda1a3ac950d339aa17e3513633890",
                },
            },
        },
        windows = {
            source = "https://github.com/charmbracelet/gum/releases/download/v${version}/gum_${version}_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.0.2" },
            ["2.0.2"] = {
                arch_alias = { x86_64 = "x86_64" },
                sha256 = {
                    x86_64 = "0397091dec9b4e8f00e02b90fd3eb07bf45acabbdb61d67437950f18e03a8b79",
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

local function _unpack_fallback(archive, normalized, parent, stem, dir, is_win)
    os.tryrm(dir)
    local src = parent .. "/" .. stem
    if os.isdir(src) then
        local dst_parent = dir:match("^(.*)/[^/]+$")
        if dst_parent then fs.mkdir_p(dst_parent) end
        os.mv(src, dir)
    elseif is_win and os.isfile(archive) then
        fs.mkdir_p(dir)
        local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("/", "\\"):gsub("\\+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s" --strip-components=1 -C "%s"',
                                  systar, archive:gsub("/", "\\"), dir:gsub("/", "\\")))
    elseif (not is_win) and os.isfile(archive) then
        fs.mkdir_p(dir)
        system.exec(string.format([[tar -xzf "%s" --strip-components=1 -C "%s"]], normalized, dir))
    else
        error("gum: neither extracted directory (" .. src .. ") nor archive (" .. archive .. ") exists")
    end
end

function installed()
    if type(payload.present) == "function" then
        return payload.present({ "gum", "LICENSE" })
            or payload.present({ "gum.exe", "LICENSE" })
    end
    local dir = pkginfo.install_dir()
    return (os.isfile(dir .. "/gum") or os.isfile(dir .. "/gum.exe"))
        and os.isfile(dir .. "/LICENSE")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("gum: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "gum.exe" or "gum"
    local src = parent .. "/" .. stem

    if not os.isdir(src) and not os.isfile(archive) then
        error("gum: neither extracted directory (" .. src .. ") nor archive (" .. archive .. ") exists")
    end

    if type(payload.unpack) == "function" and (is_win or os.isdir(src)) then
        payload.unpack{ extracted = stem, strip = 1 }
        if not is_win then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/gum"))
        end
        payload.require({ exe, "LICENSE" })
    else
        _unpack_fallback(archive, normalized, parent, stem, dir, is_win)
        if not is_win and os.isfile(dir .. "/gum") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/gum"))
        end
        if not (os.isfile(dir .. "/" .. exe) and os.isfile(dir .. "/LICENSE")) then
            error("gum: required payload files missing in " .. dir)
        end
    end

    return true
end

function config()
    xvm.add("gum", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("gum")
    return true
end
