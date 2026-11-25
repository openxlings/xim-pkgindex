-- Zig is a general-purpose programming language and toolchain for maintaining
-- robust, optimal, and reusable software.
--
-- Verified against official https://ziglang.org/download/index.json and
-- official community mirrors (https://ziglang.org/download/community-mirrors.txt):
--   * 0.17.1 is the latest stable release (2026-11-02).
--   * Official archive naming is `zig-<arch>-<os>-<ver>.<ext>`:
--       linux:   zig-{x86_64,aarch64}-linux-0.17.1.tar.xz
--       macosx:  zig-{x86_64,aarch64}-macos-0.17.1.tar.xz
--       windows: zig-{x86_64,aarch64}-windows-0.17.1.zip
--   * Uses official Zig community mirror https://zig.vortan.dev/zig/ (listed in
--     https://ziglang.org/download/community-mirrors.txt) instead of direct
--     https://ziglang.org/download/, because ziglang.org heavily throttles
--     direct downloads (causing Windows CI 1200s download timeouts). All 6
--     0.17.1 archives on zig.vortan.dev/zig/ were downloaded and verified
--     byte-identical against the official SHA256 sums in index.json.
--   * Measured on Linux x86_64 with `file`, `readelf -d`, and `ldd`: `zig` is a
--     statically linked ELF64 executable with no dynamic section (zero
--     DT_NEEDED entries), so no glibc or runtime deps are declared.
--   * Every archive extracts into `zig-<arch>-<os>-<ver>/` containing `zig`
--     (or `zig.exe`), `lib/` (Zig standard library, C headers, compiler-rt,
--     libc++, etc.), `doc/`, `LICENSE`, and `README.md`. The full tree is
--     kept in `pkginfo.install_dir()` because `zig` resolves `lib/` beside
--     the executable.
--
-- Manual maintenance (no extensions.autoupdate):
--   Official releases and SHA256 hashes are published at
--   https://ziglang.org/download/index.json (Zig moved away from GitHub after
--   0.15.1 to Codeberg, and xpkgindex-update currently supports only GitHub
--   releases/tags and Sparkle XML appcasts). `ci = { mirror = true }` mirrors
--   the declared upstream archives to xlings-res.

package = {
    spec = "2",

    name = "zig",
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software",

    homepage = "https://ziglang.org",
    authors = {"Andrew Kelley", "Zig Software Foundation"},
    maintainers = {"Zig Software Foundation"},
    licenses = {"MIT"},
    repo = "https://codeberg.org/ziglang/zig",
    docs = "https://ziglang.org/documentation/0.17.1/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "compiler", "toolchain"},
    keywords = {"zig", "compiler", "toolchain", "c", "cpp", "cross-compile"},

    programs = {"zig"},
    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://zig.vortan.dev/zig/zig-${arch}-linux-${version}.tar.xz",
            ["latest"] = { ref = "0.17.1" },
            ["0.17.1"] = {
                sha256 = {
                    x86_64  = "3581863e3cbcfd0fce0efc682ce7e9e93da96668a977791d356a26d2a7e9b17a",
                    aarch64 = "a1546d5646eb184437918d6635ca6b762a0e889eac09cef720ee7a1ed3fe7795",
                },
            },
        },
        macosx = {
            source = "https://zig.vortan.dev/zig/zig-${arch}-macos-${version}.tar.xz",
            ["latest"] = { ref = "0.17.1" },
            ["0.17.1"] = {
                sha256 = {
                    x86_64  = "9af07b20319fbd0c92ee46ad23e81d6a782b1aaea2cfb8dcbff35f1d2c7ddbb7",
                    aarch64 = "75f1bc7a1e9852f17ec9a0c1895f767c4ec56d46bc8a834920eece1d0359dd8d",
                },
            },
        },
        windows = {
            source = "https://zig.vortan.dev/zig/zig-${arch}-windows-${version}.zip",
            ["latest"] = { ref = "0.17.1" },
            ["0.17.1"] = {
                sha256 = {
                    x86_64  = "b03f477a1943673e02aca0f570e8030dffd536ce1f45cbc4d3326ec31159562e",
                    aarch64 = "4789895bdb1e312a2ea73b2a7c0a0cc8d2ab62ba6976e834a7c54cf443377c15",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function has_zig_binary(dir)
    return os.isfile(dir .. "/zig") or os.isfile(dir .. "/zig.exe")
end

local function stdlib_files(dir)
    return {
        dir .. "/lib/std/std.zig",
        dir .. "/lib/zig.h",
    }
end

function installed()
    local dir = tostring(pkginfo.install_dir()):gsub("\\", "/")
    if not has_zig_binary(dir) then
        return false
    end
    for _, file in ipairs(stdlib_files(dir)) do
        if not os.isfile(file) then
            return false
        end
    end
    return true
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local dir = tostring(pkginfo.install_dir()):gsub("\\", "/")
    local stem = normalized:match("([^/]+)$"):gsub("%.tar%.xz$", ""):gsub("%.zip$", "")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local extracted = parent .. "/" .. stem

    os.tryrm(dir)

    if stem ~= normalized:match("([^/]+)$") and os.isdir(extracted) then
        local dst_parent = dir:match("^(.*)/[^/]+$")
        if dst_parent then
            fs.mkdir_p(dst_parent)
        end
        os.mv(extracted, dir)
    elseif normalized:match("%.zip$") then
        fs.mkdir_p(dir)
        local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("[\\/]+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        -- exec-quoting-ok: systar is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s" --strip-components=1 -C "%s"',
            systar, archive:gsub("/", "\\"), dir:gsub("/", "\\")))
    elseif normalized:match("%.tar%.xz$") then
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xf "%s" --strip-components=1 -C "%s"', normalized, dir))
    else
        error("zig: extracted payload directory not found: " .. extracted)
    end

    local expected_exe = normalized:match("%.zip$") and (dir .. "/zig.exe") or (dir .. "/zig")
    local required = { expected_exe }
    for _, file in ipairs(stdlib_files(dir)) do
        table.insert(required, file)
    end

    local missing = {}
    for _, file in ipairs(required) do
        if not os.isfile(file) then
            table.insert(missing, file)
        end
    end
    if #missing > 0 then
        error("zig: required payload files missing after install:\n    " .. table.concat(missing, "\n    "))
    end
    return true
end

function config()
    xvm.add("zig", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("zig")
    return true
end
