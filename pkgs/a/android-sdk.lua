-- Android SDK -- one standard ANDROID_HOME, assembled from the independent
-- Android component packages this index already carries.
--
-- WHY THIS PACKAGE EXISTS. Every Android component here is its own package
-- with its own store directory: `android-platform-tools` (adb),
-- `android-build-tools` (aapt2/apksigner/zipalign/d8), `android-platform`
-- (android.jar), `android-ndk`, `android-emulator`, `android-system-image`.
-- That is the right shape for mcpp, which hands each tool its own path
-- (`aapt2 -I <android-platform>/android.jar`). It is the wrong shape for the
-- rest of the Android world, which locates every component through ONE
-- directory laid out the way Android Studio's SDK Manager (sdkmanager) lays
-- it out:
--
--   $ANDROID_HOME/platform-tools/adb
--   $ANDROID_HOME/build-tools/<Pkg.Revision>/apksigner
--   $ANDROID_HOME/platforms/android-<api>/android.jar
--   $ANDROID_HOME/ndk/<Pkg.Revision>/
--   $ANDROID_HOME/emulator/emulator
--   $ANDROID_HOME/system-images/android-<api>/<tag>/<abi>/
--
-- The Android Gradle plugin (AGP), Godot's Android export, Flutter, React
-- Native and Android Studio itself all read that tree and nothing else.
-- This package builds it: `<install_dir>/sdk/` is a directory of symlinks
-- into the component packages' own store directories, so nothing is
-- downloaded or copied twice.
--
-- `android-emulator.lua` already proved the shape for one consumer: the
-- emulator SIGSEGVs unless `platform-tools/` sits beside `emulator/`, and
-- that recipe fixes it with an `sdk-root/` of two symlinks. This is the
-- same construction, generalised to the whole tree.
--
-- ═══════════════════════════════════════════════════════════════════════
-- WHAT IS IN THE TREE
-- ═══════════════════════════════════════════════════════════════════════
--
-- DECLARED DEPENDENCIES -- always present, the minimum a Gradle/Godot build
-- needs:
--
--   platform-tools          xim:android-platform-tools@37.0.1-4
--   build-tools/36.1.0      xim:android-build-tools@36.1.0
--   platforms/android-36    xim:android-platform@36-r2
--
-- build-tools 36.1.0 and platform 36 are not arbitrary: they are the exact
-- `buildTools` and `compileSdk` Godot 4.7's Gradle build template pins in
-- its `config.gradle` (beside AGP 8.6.1), and the target SDK Godot's
-- non-Gradle export signs for. Pins are exact store keys, never ranges or
-- alias keys, for the reason `android-build-tools.lua` records:
-- `dep_install_dir` does not dereference `ref`, so a constraint that can
-- land on an alias key (`36` -> `36-r2`) returns a path that does not exist.
--
-- EVERY OTHER INSTALLED COMPONENT -- linked too, found by scanning the
-- payload store beside the declared dependencies. That is what makes this
-- the xlings equivalent of Android Studio's SDK Manager instead of a fixed
-- bundle:
--
--   xlings install android-platform@35-r2 android-ndk android-emulator
--   xlings install android-sdk --reconfig
--
-- (The exact key `35-r2`, not `35`: measured, `xlings install
-- android-platform@35` with 36-r2 already installed answered "36-r2 is
-- already installed" and installed nothing.)
--
-- puts `platforms/android-35`, `ndk/<rev>` and `emulator/` into the same
-- ANDROID_HOME. The scan covers android-build-tools, android-platform,
-- android-ndk, android-emulator and android-system-image, under any index
-- namespace (`xim-x-<name>`, `local-x-<name>`, ...). The store root is
-- derived from a declared dependency's own `dep_install_dir` (two levels
-- up), never hard-coded. Each candidate's directory name in the tree comes
-- from the component's own `source.properties` -- the same file sdkmanager
-- and AGP read -- not from the xlings version key:
--
--   build-tools, ndk     Pkg.Revision            (36.1.0, 30.0.16248370)
--   platforms            AndroidVersion.ApiLevel (36 -> android-36)
--   system-images        AndroidVersion.ApiLevel + SystemImage.TagId +
--                        SystemImage.Abi        (android-24/default/x86_64)
--   emulator             the single `emulator/` slot
--
-- A directory without a readable `source.properties` (a half-finished
-- install) is skipped, not linked. Declared dependencies win over scanned
-- duplicates of the same revision.
--
-- ═══════════════════════════════════════════════════════════════════════
-- MEASURED AGAINST THE REAL CONSUMERS (2026-10-07, macOS 26 arm64)
-- ═══════════════════════════════════════════════════════════════════════
--
-- Godot 4.7.2, project exported headless with `--export-debug "Android"`,
-- run with JAVA_HOME unset and PATH reduced to /usr/bin:/bin:/usr/sbin:/sbin
-- (what a GUI-launched editor sees), editor settings pointing
-- `export/android/android_sdk_path` at this tree:
--
--   template export (gradle_build/use_gradle_build=false)
--       signs and aligns with build-tools/<newest>/apksigner+zipalign -> APK
--   Gradle export (use_gradle_build=true, AGP 8.6.1, Gradle 8.11.1, JDK 17)
--       without build-tools 36.1.0 in the tree: "Failed to install the
--       following Android SDK packages as some licences have not been
--       accepted. build-tools;36.1.0" -- AGP builds only against the exact
--       revision a project names.
--       with it: BUILD SUCCESSFUL -> APK.
--
-- Two findings the design rests on:
--
--   * AGP accepts symlinked component directories identified by
--     `source.properties` alone (none of these payloads carries sdkmanager's
--     `package.xml`), and wrote nothing into the linked component
--     directories (checked with `find -newer` after the build).
--   * NO LICENCE FILES ARE NEEDED, so none is written. AGP consults
--     `$ANDROID_HOME/licenses/` only when it has to DOWNLOAD a missing
--     component. Writing `android-sdk-license` hashes would be this recipe
--     accepting the Android SDK License Agreement on the user's behalf and
--     would let AGP download into the store behind xlings' back; leaving it
--     out keeps every component an xlings install. A project that needs a
--     revision the tree lacks fails with AGP's own message naming it, and
--     `xlings install android-build-tools@<rev>` + `--reconfig` supplies it.
--
-- ═══════════════════════════════════════════════════════════════════════
-- ANDROID_HOME, AND WHO CAN SEE IT
-- ═══════════════════════════════════════════════════════════════════════
--
-- The variable is read by the consumer's BUILD system (gradle, a Godot
-- editor, a Flutter CLI), never through a shim this package owns, so a
-- per-shim `envs` cannot reach it -- the same reasoning `huxerui.lua` gives
-- for HUXERUI_HOME and `msvc.lua` for VSINSTALLDIR. Two routes, both
-- declared:
--
--   subos.env            ANDROID_HOME and ANDROID_SDK_ROOT = ${pkgdir}/sdk,
--                        exported inside `xlings subos use` shells. A value
--                        the user already exported wins (spec), so an
--                        existing Android Studio SDK is never overridden.
--   android-sdk-root     a one-line program printing the tree's path, for
--                        an ordinary shell's profile:
--                            export ANDROID_HOME="$(android-sdk-root)"
--                        It resolves through xvm like any other program, so
--                        it follows `xlings use android-sdk <version>`.
--
-- GUI applications read neither (Godot, Android Studio): point their SDK
-- path setting at `android-sdk-root`'s output. config() prints it.
--
-- NO JDK IS DECLARED OR EXPORTED. Gradle needs one, but the right one is the
-- project's choice, not this tree's: Godot 4.7's template runs Gradle
-- 8.11.1, which refuses JDK 25 (the only JDK `android-build-tools` itself
-- depends on); AGP 8.x wants 17+. `xlings install jdk-corretto@17.0.20` or
-- `@21.0.12` and point JAVA_HOME (or Godot's Java SDK Path) at it.
--
-- ═══════════════════════════════════════════════════════════════════════
-- HOSTS
-- ═══════════════════════════════════════════════════════════════════════
--
-- linux and macosx. aarch64 means macOS only, the scope every declared
-- dependency shares (no linux-aarch64 platform-tools/build-tools exist in
-- Google's manifest). WINDOWS IS NOT OFFERED, deliberately: the tree is
-- made of symlinks, and creating one on Windows needs Developer Mode or an
-- elevated process, neither of which an install hook can assume -- the gap
-- `android-emulator.lua` declares for its own sdk-root. A directory-junction
-- variant is the obvious follow-up, once measured on a Windows host.
--
-- ═══════════════════════════════════════════════════════════════════════
-- INSTALLED LAYOUT
-- ═══════════════════════════════════════════════════════════════════════
--
--   <install_dir>/sdk/                    ANDROID_HOME; symlinks only,
--                                         rebuilt by every config()
--   <install_dir>/bin/android-sdk-root    the path printer (POSIX shell)
package = {
    spec = "2",
    homepage = "https://developer.android.com/tools",

    name = "android-sdk",
    description = "Android SDK root (ANDROID_HOME) assembled from xlings' Android components, laid out like Android Studio's SDK Manager",

    authors = {"xlings contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",
    docs = "https://developer.android.com/tools/variables#android_home",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "android", "sdk", "meta"},
    keywords = {"android", "sdk", "android_home", "android-studio", "gradle",
                "godot", "platform-tools", "build-tools"},

    programs = {"android-sdk-root"},
    xvm_enable = true,

    -- The version names this recipe's assembly, not any one component: the
    -- components carry their own versions in the tree.
    xpm = {
        linux = {
            deps = { runtime = {
                "xim:android-platform-tools@37.0.1-4",
                "xim:android-build-tools@36.1.0",
                "xim:android-platform@36-r2",
            } },
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = { },
        },
        macosx = {
            deps = { runtime = {
                "xim:android-platform-tools@37.0.1-4",
                "xim:android-build-tools@36.1.0",
                "xim:android-platform@36-r2",
            } },
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = { },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.system")
import("xim.libxpkg.subos")

local ROOT_PRINTER_TEMPLATE = [==[
#!/usr/bin/env bash
# android-sdk-root (xim:android-sdk). Prints the assembled Android SDK root:
#     export ANDROID_HOME="$(android-sdk-root)"
set -euo pipefail
echo "%s"
]==]

-- Packages whose installed versions are scanned into the tree, beyond the
-- declared dependencies.
local SCANNED = {
    "android-build-tools",
    "android-platform",
    "android-ndk",
    "android-emulator",
    "android-system-image",
}

local function sdk_dir()
    return path.join(pkginfo.install_dir(), "sdk")
end

local function read_props(dir)
    local file = path.join(dir, "source.properties")
    if not os.isfile(file) then return nil end
    local props = {}
    for line in (io.readfile(file) or ""):gmatch("[^\r\n]+") do
        local k, v = line:match("^%s*([%w%._]+)%s*=%s*(.-)%s*$")
        if k then props[k] = v end
    end
    return props
end

-- Where a component belongs in the tree, from its own source.properties.
-- nil means "not a component of this kind" (or not finished installing).
local function slot_for(name, dir)
    local p = read_props(dir)
    if not p then return nil end
    if name == "android-platform-tools" then
        return "platform-tools"
    elseif name == "android-build-tools" and p["Pkg.Revision"] then
        return path.join("build-tools", p["Pkg.Revision"])
    elseif name == "android-platform" and p["AndroidVersion.ApiLevel"] then
        return path.join("platforms", "android-" .. p["AndroidVersion.ApiLevel"])
    elseif name == "android-ndk" and p["Pkg.Revision"] then
        return path.join("ndk", p["Pkg.Revision"])
    elseif name == "android-emulator" then
        return "emulator"
    elseif name == "android-system-image" and p["AndroidVersion.ApiLevel"]
           and p["SystemImage.TagId"] and p["SystemImage.Abi"] then
        return path.join("system-images", "android-" .. p["AndroidVersion.ApiLevel"],
                         p["SystemImage.TagId"], p["SystemImage.Abi"])
    end
    return nil
end

-- `rm -rf` THROUGH THE SHELL, NOT `os.tryrm`: the tree is symlinks to other
-- packages' payloads, and `rm -rf` removes a symlink without following it.
local function remove_tree(dir)
    if os.isdir(dir) or os.isfile(dir) then
        system.exec(string.format([[rm -rf "%s"]], dir))
    end
end

local function link(target, slot, linked)
    local dst = path.join(sdk_dir(), slot)
    if linked[slot] then return end
    os.mkdir(path.directory(dst))
    -- `ln -sfn` through the shell: xmake's lua has no `os.ln` (see
    -- android-emulator.lua and nvidia-video-host-link.lua).
    system.exec(string.format([[ln -sfn "%s" "%s"]], target, dst))
    linked[slot] = target
end

local function assemble()
    local root = sdk_dir()
    remove_tree(root)
    os.mkdir(root)

    local linked = {}

    -- Declared dependencies first: they are the guaranteed minimum, and win
    -- over a scanned duplicate of the same revision.
    local declared = {
        { "android-platform-tools", pkginfo.dep_install_dir("xim:android-platform-tools") },
        { "android-build-tools",    pkginfo.dep_install_dir("xim:android-build-tools") },
        { "android-platform",       pkginfo.dep_install_dir("xim:android-platform") },
    }
    for _, d in ipairs(declared) do
        local name, dir = d[1], d[2]
        if not dir or not os.isdir(dir) then
            raise("android-sdk: " .. name .. " payload not found (this "
                  .. "package's deps declare it); refusing to assemble an "
                  .. "SDK root without it")
        end
        local slot = slot_for(name, dir)
        if not slot then
            raise("android-sdk: " .. dir .. " has no usable source.properties; "
                  .. "cannot place " .. name .. " in the SDK root")
        end
        link(dir, slot, linked)
    end

    -- Everything else installed beside them. <store>/<ns>-x-<name>/<version>
    -- is the store layout; the store root is two levels above any payload.
    -- Two plain one-level listings rather than one `*-x-<name>/*` pattern:
    -- the hook runtime's os.dirs matched nothing for a wildcard in a middle
    -- path segment (measured), only in the last one.
    local store_root = path.directory(path.directory(declared[1][2]))
    local namespaces = os.dirs(path.join(store_root, "*")) or {}
    table.sort(namespaces)
    for _, name in ipairs(SCANNED) do
        local suffix = "-x-" .. name
        for _, nsdir in ipairs(namespaces) do
            local base = path.filename(nsdir)
            if base:sub(-#suffix) == suffix then
                local candidates = os.dirs(path.join(nsdir, "*")) or {}
                table.sort(candidates)
                for _, dir in ipairs(candidates) do
                    local slot = slot_for(name, dir)
                    if slot then link(dir, slot, linked) end
                end
            end
        end
    end

    local adb = path.join(root, "platform-tools", "adb")
    if not os.isfile(adb) then
        raise("android-sdk: " .. adb .. " does not resolve through the "
              .. "symlink just created")
    end
    return linked
end

function install()
    local dir = pkginfo.install_dir()
    remove_tree(path.join(dir, "sdk"))
    os.tryrm(dir)
    os.mkdir(dir)

    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)
    local printer = path.join(bindir, "android-sdk-root")
    local f = io.open(printer, "w")
    if not f then
        raise("android-sdk: cannot write " .. printer)
    end
    f:write(string.format(ROOT_PRINTER_TEMPLATE, sdk_dir()))
    f:close()
    os.iorun('chmod +x "' .. printer .. '"')
    local ok = try { function() return os.iorun('bash -n "' .. printer .. '"') end }
    if ok == nil then
        raise("android-sdk: " .. printer .. " is not valid shell")
    end
    return true
end

-- The tree is built here rather than in install() so that
-- `xlings install android-sdk --reconfig` picks up components installed
-- after this package.
function config()
    local linked = assemble()

    xvm.add(package.name, { type = "group" })
    xvm.add("android-sdk-root", {
        bindir = path.join(pkginfo.install_dir(), "bin"),
        binding = package.name .. "@" .. pkginfo.version(),
    })

    -- Not a loader variable, though xlings' install-time report lists it: no
    -- dynamic loader or library reads ANDROID_HOME/ANDROID_SDK_ROOT. Build
    -- systems (AGP, Godot, Flutter) read it to LOCATE the SDK tree, the
    -- XDG_DATA_DIRS kind of declaration the spec calls ordinary; RPATH has
    -- nothing to offer a variable no loader consults. The tool binaries it
    -- leads to are run by those build systems by absolute path, the same
    -- decision PATH makes, and a value the user exported wins.
    if type(subos.env) == "function" then
        local binding = package.name .. "@" .. pkginfo.version()
        subos.env{ var = "ANDROID_HOME", op = "set",
                   value = "${pkgdir}/sdk", binding = binding }
        subos.env{ var = "ANDROID_SDK_ROOT", op = "set",
                   value = "${pkgdir}/sdk", binding = binding }
    end

    local slots = {}
    for slot, _ in pairs(linked) do table.insert(slots, slot) end
    table.sort(slots)
    log.info("android-sdk: ANDROID_HOME = %s", sdk_dir())
    for _, slot in ipairs(slots) do
        log.info("android-sdk:   %s", slot)
    end
    log.info("android-sdk: in a shell profile: export ANDROID_HOME=\"$(android-sdk-root)\"")
    log.info("android-sdk: more components: xlings install android-platform@35-r2 "
             .. "android-ndk android-emulator, then xlings install android-sdk --reconfig")
    return true
end

function uninstall()
    -- subos.env declarations are provider-scoped; xlings drops them with
    -- the package.
    local version = pkginfo.version()
    xvm.remove("android-sdk-root", version)
    xvm.remove(package.name, version)
    remove_tree(sdk_dir())
    return true
end
