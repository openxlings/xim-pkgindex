-- Godot Engine editor — official upstream prebuilt binaries.
--
-- Only the *standard* (non-Mono) builds are packaged. They are the
-- portable ones: the Mono/C# flavour additionally needs a matching .NET
-- SDK on the host, while the standard editor is a single self-contained
-- executable. Upstream ships no arch-suffixed variants of a given
-- platform beyond the ones mapped below.
--
-- URL shapes are irregular across platforms and arches
-- (`linux.x86_64` / `linux.arm64` / `win64` / `windows_arm64` /
-- `macos.universal`), so this recipe uses the V2 per-arch resource map
-- (Shape B) with an explicit `{GLOBAL, CN}` mirror table per asset
-- rather than a `${arch_alias}` template. The helper builders below keep
-- that from turning into 30 copy-pasted URLs.
--
-- GLOBAL = the authoritative upstream GitHub release.
-- CN     = gitcode.com/xlings-res/godot, a byte-identical copy of those
--          same assets (same filenames; tag drops the `-stable` suffix),
--          published so mainland-China installs don't go through
--          github.com. Both sides were verified against upstream
--          `SHA512-SUMS.txt` before the sha256 values here were recorded.
--
-- No `package.ci`: `version-check.py`'s `normalize_version()` only strips
-- a leading `v`, so godot's `4.7.1-stable` tags would be proposed as a
-- literal `4.7.1-stable` version key and never match the `4.7.1` keys
-- used here. The CN mirror is therefore refreshed by hand per release.

local _GODOT_GH = "https://github.com/godotengine/godot/releases/download"
local _GODOT_CN = "https://gitcode.com/xlings-res/godot/releases/download"

-- One asset -> its GLOBAL/CN mirror pair. Upstream tags are
-- `<ver>-stable`; the CN mirror tags are plain `<ver>`.
local function _res(ver, asset, sha256)
    return {
        url = {
            GLOBAL = string.format("%s/%s-stable/%s", _GODOT_GH, ver, asset),
            CN = string.format("%s/%s/%s", _GODOT_CN, ver, asset),
        },
        sha256 = sha256,
    }
end

local function _linux(ver, sha_x86_64, sha_aarch64)
    return {
        x86_64 = _res(ver, string.format("Godot_v%s-stable_linux.x86_64.zip", ver), sha_x86_64),
        aarch64 = _res(ver, string.format("Godot_v%s-stable_linux.arm64.zip", ver), sha_aarch64),
    }
end

local function _windows(ver, sha_x86_64, sha_aarch64)
    return {
        x86_64 = _res(ver, string.format("Godot_v%s-stable_win64.exe.zip", ver), sha_x86_64),
        aarch64 = _res(ver, string.format("Godot_v%s-stable_windows_arm64.exe.zip", ver), sha_aarch64),
    }
end

-- macOS ships a single universal (x86_64 + arm64) bundle, so both arch
-- keys intentionally resolve to the same asset and the same sha256.
local function _macosx(ver, sha)
    local asset = string.format("Godot_v%s-stable_macos.universal.zip", ver)
    return {
        x86_64 = _res(ver, asset, sha),
        aarch64 = _res(ver, asset, sha),
    }
end

package = {
    spec = "2",

    name = "godot",
    description = "Godot Engine - multi-platform 2D and 3D game engine (editor + headless export runner)",

    homepage = "https://godotengine.org",
    maintainers = {"Godot Engine contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/godotengine/godot",
    docs = "https://docs.godotengine.org",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"gamedev", "engine", "editor"},
    keywords = {"godot", "game-engine", "gdscript", "gdextension", "2d", "3d", "gamedev"},

    programs = {"godot"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- Runtime deps. The official editor binary is dynamically
            -- linked (INTERP=/lib64/ld-linux-x86-64.so.2) against glibc
            -- only: NEEDED librt/libpthread/libdl/libm/libc, highest
            -- referenced symbol version GLIBC_2.28. Godot statically
            -- links its C++ runtime, so libstdc++/libgcc_s are NOT in
            -- NEEDED (same as griddycode.lua, itself a Godot build).
            --
            -- libfreetype.so.6 is dlopen'd unconditionally at startup
            -- for the editor's text rendering (fires before even
            -- `--version` prints), and freetype's font enumeration
            -- pulls in libexpat.so.1 via fontconfig -- both must be
            -- resolvable or the shim's very first line is a loader
            -- error. Neither is in DT_NEEDED (readelf -d), so the
            -- resolution rides on the RPATH xlings' predicate-driven
            -- elfpatch appends from each dep's exports.runtime.libdirs
            -- (see freetype.lua / expat.lua).
            --
            -- The remaining GUI libraries (libGL, libX11, libwayland,
            -- libXi) are also dlopen'd but only after a real display
            -- server is required; `godot --headless` works without
            -- them and they're left to the host so we don't ship an
            -- entire X11/mesa stack.
            deps = {
                runtime = {
                    "xim:glibc@2.39",
                    "xim:freetype@2.13.2",
                    "xim:expat@2.6.2",
                },
            },
            ["latest"] = { ref = "4.7.1" },
            ["4.7.1"] = _linux("4.7.1",
                "c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba",
                "8f527179cd4ae58b402fa265fe817dc505e5b6b14574f309efe57113be562ac1"),
            -- 4.6.x is kept alongside latest because Godot project files
            -- record a `config_version` and a 4.6 project opened by a 4.7
            -- editor is silently migrated. GDExtension consumers that
            -- pin a 4.6 API (e.g. github.com/FarnaHerry/mcpp-kaki) need
            -- `xvm use godot@4.6.3` to stay on the matching editor.
            ["4.6.3"] = _linux("4.6.3",
                "d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3",
                "90c70382eee1542904bf507b9bdc6e62a230ac73fd214bf3887a9e0a4d85aeed"),
        },
        windows = {
            ["latest"] = { ref = "4.7.1" },
            ["4.7.1"] = _windows("4.7.1",
                "c7a289051eaefb460b0106b60e9cd5bee0ef55fd102dcb2bed1eb356cf3d90a1",
                "d9cdf49102092a2b6db4c5929002628d16eca3d7226afca2b1d03431a0a1e64b"),
            ["4.6.3"] = _windows("4.6.3",
                "e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90",
                "d53b5b4c1d1e4f242d490a98a0da1b3579628e4d6f98a052542599862a96b10f"),
        },
        macosx = {
            ["latest"] = { ref = "4.7.1" },
            ["4.7.1"] = _macosx("4.7.1",
                "897cb7f9799796c717ae75f31446aed883dc92b1d6c3b33d893cc7843fff2fa9"),
            ["4.6.3"] = _macosx("4.6.3",
                "30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8"),
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

-- Every asset is a .zip that expands into the hook cwd (the download
-- dir) with no wrapper directory:
--   linux   -> one ELF named exactly like the archive minus `.zip`,
--              e.g. `Godot_v4.7.1-stable_linux.x86_64`
--   windows -> `Godot_v4.7.1-stable_win64.exe` plus a `_console.exe`
--              sibling (the console subsystem build, the one that can
--              print to a terminal)
--   macosx  -> a signed `Godot.app/` bundle whose name carries neither
--              version nor arch
--
-- The linux/windows payload name embeds the arch token, and the hook
-- cannot ask for the host arch: `os.arch` is not bound in the xim hook
-- runtime and `_RUNTIME.arch` is empty for install hooks. Deriving the
-- name from `pkginfo.install_file()` (the archive we actually
-- downloaded) keeps the hook arch-agnostic.
local function _payload_stem()
    local file = pkginfo.install_file() or ""
    local base = file:match("[^/\\]+$") or ""
    return (base:gsub("%.zip$", ""))
end

local function _installed_exe()
    return path.join(pkginfo.install_dir(), os.host() == "windows" and "godot.exe" or "godot")
end

function install()
    -- Idempotent across xim engines: some stage the extracted payload
    -- into install_dir() before the hook runs, others leave it in the
    -- hook cwd. Never wipe install_dir before a replacement payload is
    -- confirmed, and never report success unless the binary landed --
    -- a bare `return true` gets stamped as installed and leaves
    -- dangling xvm shims over an empty directory.
    local exe = _installed_exe()
    if os.isfile(exe) then
        return true
    end

    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    if os.host() == "macosx" then
        -- Keep the bundle intact: Contents/Resources holds the editor
        -- icons/localisation and Contents/Info.plist drives the code
        -- signature. Expose the Mach-O through a symlink so xvm's
        -- bindir model finds a lowercase `godot`; macOS resolves the
        -- symlink before deriving the bundle path, so resources still
        -- load. (`symlink = true` on os.cp is the same idiom
        -- cc-switch.lua uses for its .app bundle.)
        os.mv("Godot.app", path.join(pkginfo.install_dir(), "Godot.app"))
        os.cp(path.join(pkginfo.install_dir(), "Godot.app", "Contents", "MacOS", "Godot"),
              exe, { force = true, symlink = true })
        return os.isfile(exe)
    end

    local stem = _payload_stem()

    if os.host() == "windows" then
        os.mv(stem, exe)
        local console = stem:gsub("%.exe$", "_console.exe")
        if os.isfile(console) then
            os.mv(console, path.join(pkginfo.install_dir(), "godot_console.exe"))
        end
        return os.isfile(exe)
    end

    os.mv(stem, exe)
    -- The zip stores the executable bit, but restoring it explicitly
    -- keeps the recipe correct on extractors that drop unix modes.
    system.exec("chmod +x " .. exe)
    return os.isfile(exe)
end

function config()
    -- xlings' predicate-driven elfpatch has already stamped the deps'
    -- libdirs onto godot's DT_RUNPATH by the time we get here.  Per
    -- ld.so(8), DT_RUNPATH is consulted only for DT_NEEDED entries --
    -- glibc's dlopen(3) implementation deliberately ignores it -- so
    -- godot's runtime dlopen of libfreetype.so.6 and libexpat.so.1
    -- would fall through to the system search path and fail (verified
    -- with LD_DEBUG=libs: the DT_NEEDED lookups honour the patched
    -- path, the dlopen ones do not).  DT_RPATH *is* searched for
    -- dlopen, so force-convert the entry.  --set-rpath preserves the
    -- exact path list; --force-rpath is what flips the tag from
    -- DT_RUNPATH to DT_RPATH.
    if os.host() == "linux" then
        local exe = _installed_exe()
        -- One sh -c: read the existing rpath, and if non-empty, write
        -- it back with --force-rpath (which flips DT_RUNPATH -> DT_RPATH).
        -- Iorunv / stdout capture aren't exposed to the xim hook runtime,
        -- so we can't compose this in Lua directly.
        system.exec(string.format(
            "sh -c 'r=$(patchelf --print-rpath %q); "
                .. "[ -n \"$r\" ] && patchelf --force-rpath --set-rpath \"$r\" %q'",
            exe, exe
        ))
    end
    xvm.add("godot", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("godot")
    return true
end
