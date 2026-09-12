-- Android SDK Platform -- android.jar and framework.aidl, the API surface an
-- Android application compiles and links its Java/Kotlin sources against.
-- One package, versioned by API level rather than by Google's own package
-- revision, because the API level is the number a consumer actually pins
-- (`targetSdkVersion`, `compileSdkVersion`, `minSdkVersion`).
--
-- WHY THIS PACKAGE EXISTS. `mcpp:plugins`' `dist-apk` member's level-1 path
-- (design record mcpp .agents/docs/2026-09-12-622-a-ui-framework-on-android
-- -ios-and-web.md, section 3.2) compiles a consumer's Java host sources with
-- `javac -cp android.jar` and reads `targetSdkVersion` from "the platform
-- payload's level" -- i.e. from this package's own version. Level 0 (a pure
-- NativeActivity application, no Java) also needs `android.jar` as
-- `aapt2 link`'s `-I` argument, so the dependency is not level-1-only.
--
-- ═══════════════════════════════════════════════════════════════════════
-- WHAT WAS MEASURED (2026-09-12), READING THE SAME MANIFEST
-- pkgs/a/android-build-tools.lua DOES
-- ═══════════════════════════════════════════════════════════════════════
--
-- https://dl.google.com/android/repository/repository2-3.xml,
-- `<remotePackage path="platforms;android-36">`, `platforms;android-35">`
-- and `platforms;android-34">`, all `channelRef` = `channel-0` (stable):
--
--   api   Pkg.Revision   url                        size       sha1
--   36    2              platform-36_r02.zip        65878410   2c1a80dd4d
--                                                               9f7d0e6dd3
--                                                               36ec603d9b
--                                                               5c55a6f576
--   35    2              platform-35_r02.zip        64273788   0bb560a90a
--                                                               7a2cbd0dd8
--                                                               348224d518
--                                                               b638fe7949
--   34    3              platform-34-ext7_r03.zip   63180081   1f2e9478d6
--                                                               a7601425ce
--                                                               aa553311dc
--                                                               43191f103d
--
-- (API 34's own package carries an `extension-level` of 7, which is why its
-- file name is `platform-34-ext7_r03.zip` rather than `platform-34_r03.zip`
-- -- read from the manifest, not guessed from API 35's pattern; templating
-- one file name from the other would have produced a 404. API 36's own
-- package is the plain `platform-36_r02.zip`; the `-ext18`/`-ext19`
-- packages beside it are extension SDKs, not this level.) All three fetched
-- directly with curl; size and sha1 matched the manifest exactly for each,
-- and the sha256 values below were computed from those verified downloads
-- (the manifest itself carries no sha256, as for every Google SDK component
-- this index reads this way).
--
-- HOST INDEPENDENT, and this is a property of the archive rather than a
-- narrowing this recipe applies: `<remotePackage>` for a platform carries no
-- `host-os` attribute on its `<archive>` at all (unlike build-tools/NDK/
-- platform-tools, all of which publish one archive PER host). `android.jar`
-- is a pure JVM class-file archive and `framework.aidl` is text, so one
-- download serves linux, macosx and windows alike -- declared for all three
-- below with the identical url and sha256, the same shape
-- `pkgs/p/picolibc-riscv.lua` uses for its own host-independent target
-- sysroot (docs/contributing.md ss5.2: "载荷与宿主无关 => 一个 sha256 服务全
-- 平台").
--
-- EXTRACTION LAYOUT. All three archives share the pattern `android-<api>/`
-- (`android-36/`, `android-35/`, `android-34/`) as their sole internal
-- top-level directory, with `android.jar` and `framework.aidl` directly
-- under it (measured with `unzip -l` against each download) -- this recipe installs
-- that directory's contents at `install_dir()`'s own root, unmodified
-- beyond the rename, so a consumer's `-I <install_dir>/android.jar` and
-- `-I <install_dir>/framework.aidl` (aapt2's and aidl's own flag spelling)
-- need no per-package subdirectory.
--
-- ═══════════════════════════════════════════════════════════════════════
-- LICENCE -- READ FROM EACH ARCHIVE'S OWN NOTICE.txt
-- ═══════════════════════════════════════════════════════════════════════
--
-- Same SDK Agreement, same ss3.4/ss3.5 argument `android-ndk.lua` and
-- `android-build-tools.lua` both make in full (not repeated here). This
-- archive's own `data/NOTICE.txt` (766444 bytes, identical size in the
-- API 34 and API 35 downloads -- measured, so the underlying attribution
-- set did not change between those two levels; 766391 bytes in API 36's,
-- a 53-byte difference that is a revised notice, not a new component)
-- opens differently from build-tools' NOTICE:
--
--   Notices for files contained in the tools directory:
--   ============================================================
--   Notices for file(s):
--   /bin/mksdcard
--   ------------------------------------------------------------
--   Copyright 2007, The Android Open Source Project
--
--   Redistribution and use in source and binary forms, with or without
--   modification, are permitted provided that the following conditions are
--   met: ...
--
-- A BSD-3-Clause-shaped AOSP notice, not Apache-2.0's umbrella grant --
-- read rather than assumed to match build-tools' NOTICE, because it does
-- not. It is an attribution file listing per-component open-source notices
-- throughout (the file also ships duplicated, byte-identical, at
-- `skins/NOTICE.txt` and `templates/NOTICE.txt`), with no proprietary
-- component named anywhere in it. `android.jar` itself is Apache-2.0 (the
-- AOSP frameworks/base licence, which this NOTICE's own umbrella covers as
-- the archive's Android-authored content). Every component under this
-- NOTICE is open-source, so ss3.5 applies for the identical reason it does
-- for `android-ndk.lua` and `android-build-tools.lua`.
--
-- TIER: 1 (redistribute, mirror through xlings-res) by that reading, and
-- NOT YET MIRRORED, for the identical reason and with the identical
-- `ci = { mirror = true }` omission `android-build-tools.lua`'s header
-- states -- a follow-up publishing the xlings-res release is the correct
-- next step, not a fabricated `CN` url.
--
-- ═══════════════════════════════════════════════════════════════════════
-- INSTALLED LAYOUT
-- ═══════════════════════════════════════════════════════════════════════
--
--   <install_dir>/android.jar          the API surface aapt2/javac compile
--                                       and link against.
--   <install_dir>/framework.aidl       AIDL's own framework interface
--                                       definitions.
--   <install_dir>/build.prop, source.properties, sdk.properties, data/, ...
--       upstream's own tree, unmodified, present for a consumer that needs
--       more than the two files above (e.g. `data/api-versions.xml` for a
--       lint-shaped tool).
package = {
    spec = "2",
    homepage = "https://developer.android.com/tools/releases/platforms",

    name = "android-platform",
    description = "Android SDK Platform: android.jar and framework.aidl, versioned by API level",

    maintainers = {"Google", "The Android Open Source Project"},
    licenses = {"Android Software Development Kit License Agreement"},
    repo = "https://android.googlesource.com/platform/frameworks/base",
    docs = "https://developer.android.com/tools/releases/platforms",

    type = "package",
    -- Host-independent payload -- see EXTRACTION LAYOUT above -- so every
    -- arch this index otherwise serves resolves to the one download.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "android", "sdk"},
    keywords = {"android", "android.jar", "framework.aidl", "platform",
                "api-level", "sdk"},

    xvm_enable = true,

    xpm = {
        -- ONE TABLE, NOT THREE: the archive itself carries no per-host
        -- variant (see HOST INDEPENDENT above), so `linux`/`macosx`/
        -- `windows` below are three identical url/sha256 pairs rather than
        -- three measurements. `ubuntu = { ref = "linux" }`-style platform
        -- inheritance is not used here because xlings resolves the
        -- top-level host keys directly and a fourth key would only add
        -- indirection for no narrower answer.
        linux = {
            ["36"] = { ref = "36-r2" },
            ["36-r2"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-36_r02.zip" },
                sha256 = "37607369a28c5b640b3a7998868d45898ebcb777565a0e85f9acf36f29631d2e",
            },
            ["35"] = { ref = "35-r2" },
            ["35-r2"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-35_r02.zip" },
                sha256 = "0988cacad01b38a18a47bac14a0695f246bc76c1b06c0eeb8eb0dc825ab0c8e0",
            },
            ["34"] = { ref = "34-r3" },
            ["34-r3"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-34-ext7_r03.zip" },
                sha256 = "16fdb74c55e59ae3ef52def135aec713508467bd56d7dabcd8c9be31fa8b20f3",
            },
            -- No API level is "latest": a consumer pins the level its
            -- own `compileSdkVersion`/`min_api_level` names (design record
            -- section 3.2), so there is no single most-recent answer the way
            -- there is for a toolchain. `xlings install android-platform@36`,
            -- `@35` and `@34` are all first-class, permanent entries.
        },
        macosx = {
            ["36"] = { ref = "36-r2" },
            ["36-r2"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-36_r02.zip" },
                sha256 = "37607369a28c5b640b3a7998868d45898ebcb777565a0e85f9acf36f29631d2e",
            },
            ["35"] = { ref = "35-r2" },
            ["35-r2"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-35_r02.zip" },
                sha256 = "0988cacad01b38a18a47bac14a0695f246bc76c1b06c0eeb8eb0dc825ab0c8e0",
            },
            ["34"] = { ref = "34-r3" },
            ["34-r3"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-34-ext7_r03.zip" },
                sha256 = "16fdb74c55e59ae3ef52def135aec713508467bd56d7dabcd8c9be31fa8b20f3",
            },
        },
        windows = {
            ["36"] = { ref = "36-r2" },
            ["36-r2"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-36_r02.zip" },
                sha256 = "37607369a28c5b640b3a7998868d45898ebcb777565a0e85f9acf36f29631d2e",
            },
            ["35"] = { ref = "35-r2" },
            ["35-r2"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-35_r02.zip" },
                sha256 = "0988cacad01b38a18a47bac14a0695f246bc76c1b06c0eeb8eb0dc825ab0c8e0",
            },
            ["34"] = { ref = "34-r3" },
            ["34-r3"] = {
                url = { GLOBAL = "https://dl.google.com/android/repository/platform-34-ext7_r03.zip" },
                sha256 = "16fdb74c55e59ae3ef52def135aec713508467bd56d7dabcd8c9be31fa8b20f3",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- The extracted directory name is "android-<api>", read from the resolved
-- version's own numeral -- "35-r2" and "34-r3" both start with the API
-- level, so the level is recovered by splitting at "-" rather than storing
-- it a second time. A future third API level follows the same "<api>-r<n>"
-- shape.
local function extract_dir()
    local api = pkginfo.version():match("^(%d+)")
    if not api then
        raise("android-platform: cannot recover an API level from version '"
              .. pkginfo.version() .. "'")
    end
    return "android-" .. api
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    local src = extract_dir()
    if not os.isdir(src) then
        raise("android-platform: expected extracted directory '" .. src
              .. "' not found beside the downloaded archive")
    end
    os.mv(src, dir)

    for _, f in ipairs({"android.jar", "framework.aidl"}) do
        local p = path.join(dir, f)
        if not os.isfile(p) then
            raise("android-platform: no " .. f .. " at " .. p
                  .. " -- payload does not look like an Android platform "
                  .. "archive")
        end
    end

    return true
end

function config()
    -- Umbrella only: this package provides two files, not a program. A
    -- consumer reaches them with `pkginfo.dep_install_dir("xim:android-
    -- platform", "<api>-r<n>")` (mcpp:plugins' dist-apk member resolves an
    -- exact level, never "whichever is active"), the same
    -- `type = "group"` idiom `android-ndk.lua` and `jdk-temurin.lua`'s own
    -- binding root use for a payload with no `bin/<name>` to shim.
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
