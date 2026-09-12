-- Android SDK Build-Tools -- aapt2, zipalign, apksigner and d8 (r8), Google's
-- own prebuilt binaries for turning compiled resources and dex classes into
-- an installable, signed APK.
--
-- WHY THIS PACKAGE EXISTS. `mcpp:plugins`' `dist-apk` member (design record
-- mcpp .agents/docs/2026-09-12-622-a-ui-framework-on-android-ios-and-web.md,
-- section 3.2) links a NativeActivity or Java-hosted Android application by
-- running, in order: `aapt2 compile`/`aapt2 link` (resources and the
-- manifest into `base.apk`), `zipalign` (page-aligning the archive), and,
-- when the project carries Java sources, `d8` (dexing) before `apksigner`
-- (signing). None of the four exists anywhere else in this index --
-- `pkgs/a/android-platform-tools.lua` carries `adb`/`fastboot` only, and
-- `pkgs/a/android-ndk.lua` carries the NDK's native cross-toolchain, not the
-- SDK's packaging tools.
--
-- ═══════════════════════════════════════════════════════════════════════
-- WHAT WAS MEASURED (2026-09-12), AND WHERE THE NUMBERS BELOW COME FROM
-- ═══════════════════════════════════════════════════════════════════════
--
-- Same manifest `pkgs/a/android-ndk.lua` and `pkgs/a/android-platform-tools
-- .lua` both read, https://dl.google.com/android/repository/repository2-3
-- .xml, fetched 2026-09-12. It lists `build-tools;37.0.0` through
-- `build-tools;17.0.0`; the CURRENT stable one (`channelRef` = `channel-0`,
-- which the manifest's own `<channel id="channel-0">stable</channel>` names;
-- `37.0.0-rc2`/`-rc1` are `channel-1`/beta and were skipped) is:
--
--   build-tools;37.0.0   Pkg.Revision 37.0.0   display-name "Android SDK
--                        Build-Tools 37"
--
-- Its three `<archive>` entries, one per `host-os`:
--
--   host-os   url                              size       sha1 (manifest)
--   linux     build-tools_r37_linux.zip         66135704   70954e99f4c3d9d
--                                                           46ee70fa32624672
--                                                           fe7cd6ebe
--   windows   build-tools_r37_windows.zip       61077164   e9c97e26b5b5678
--                                                           002e9d3fed632c84
--                                                           1ae62d99f
--   macosx    build-tools_r37_macosx.zip        81933386   eb080751b2b2028
--                                                           eb3604f571027d6
--                                                           f7b3c46321
--
-- Note the file name is `build-tools_r37_<host>.zip` -- an underscore before
-- the host and `r37` with no minor/micro segment, NOT the
-- `build-tools_r<v>-<host>.zip` template a version string alone would
-- suggest. All three were fetched directly from `dl.google.com` with curl;
-- each download's size and sha1 matched the manifest exactly, and the
-- sha256 values below were computed from those verified downloads (the
-- manifest publishes no sha256, matching every other Google SDK component
-- this index carries).
--
-- HOST ARCH SCOPE, and it is the identical shape `android-ndk.lua` and
-- `android-platform-tools.lua` both measured for their own archives:
--
--   linux     ELF 64-bit x86-64 (`file` on the extracted `aapt2`/`zipalign`)
--             -- no separate aarch64 Linux build exists in the manifest.
--   macosx    Mach-O UNIVERSAL binary, 2 architectures (x86_64 and arm64) --
--             one archive serves both Apple arches.
--   windows   PE, x86_64 only.
--
-- Hence `archs = {"x86_64", "aarch64"}` at the package level, with aarch64
-- meaning "macOS only", exactly as `android-platform-tools.lua`'s own
-- comment states for the identical reason.
--
-- EXTRACTION LAYOUT. All three archives share one internal top-level
-- directory name regardless of host, `android-37.0/` (measured with
-- `unzip -l` against all three downloads) -- unlike the NDK's per-host
-- `android-ndk-r30-<host>/`. `aapt2`, `zipalign`, `apksigner`, `d8` and
-- `NOTICE.txt` sit directly under it on Linux and macOS;
-- `aapt2.exe`/`zipalign.exe`/`apksigner.bat`/`d8.bat` on Windows. This
-- recipe renames that one directory to `install_dir()`, unmodified beyond
-- the rename, exactly as `android-platform-tools.lua` does for its own flat
-- archive.
--
-- ═══════════════════════════════════════════════════════════════════════
-- LICENCE -- READ FROM THE ARCHIVE'S OWN NOTICE.txt, NOT ASSUMED
-- ═══════════════════════════════════════════════════════════════════════
--
-- Same posture as `android-ndk.lua` (see its licence section for the SDK
-- Agreement's ss3.4/ss3.5 argument in full, not repeated here): the SDK
-- Agreement's ss3.4 forbids redistribution and ss3.5 carves bundled
-- open-source components back out, governed solely by their own licence.
-- The question this recipe answers is what `NOTICE.txt` inside the
-- archive actually says, read rather than assumed.
--
-- Opening lines of `android-37.0/NOTICE.txt` (identical structure in all
-- three archives, only the referenced file name differing per host):
--
--   ==============================================================================
--   Android used by:
--     sdk-repo-linux-build-tools.zip
--
--
--                                    Apache License
--                              Version 2.0, January 2004
--   ...
--
-- (`sdk-repo-darwin-build-tools.zip` / `sdk-repo-windows-build-tools.zip` on
-- the other two hosts.) The full Apache-2.0 grant follows verbatim. Below
-- that umbrella statement the file carries 41 "Notices for file(s):"
-- sub-sections (measured: `grep -c "Notices for file"`) attributing bundled
-- third-party components -- `d8.jar`, `libclang.so`, `junit.jar`,
-- `guavalib.jar` and so on -- each under its own open-source licence
-- (BSD/MIT/Apache-family throughout; none proprietary). Every file this
-- archive carries is therefore an open-source-licensed component within the
-- meaning of ss3.5, the same reading `android-ndk.lua` and
-- `android-platform-tools.lua` reached for their own archives under the
-- same Agreement.
--
-- TIER: 1 (redistribute, mirror through xlings-res), by that reading --
-- but NOT YET MIRRORED by this change. Unlike `android-ndk.lua` and
-- `android-platform-tools.lua`, whose `url` tables already carry a working
-- `gitcode.com/xlings-res/...` entry, this recipe declares `GLOBAL` only:
-- writing a `CN` address that has not actually been published would be a
-- URL invented rather than measured, which is the one thing this index's
-- own hard gate (README.md, "资源发布硬门禁") exists to catch. `ci = {
-- mirror = true }` is deliberately NOT set either: mirroring a Google
-- archive whose per-major-version file name and internal extraction
-- directory both changed shape across the versions this recipe's siblings
-- measured (r27 to r30 renamed the NDK's module surface story entirely) is
-- the same "not safe to automate" case `android-ndk.lua` states for
-- `ci.update`, and mirroring an unreviewed byte stream is no safer than
-- auto-bumping one. A follow-up change publishing the GitHub RES/GitCode RES
-- release for this version and adding the `CN` entry is the correct next
-- step, verified byte-for-byte as README.md's asset gate requires.
--
-- ═══════════════════════════════════════════════════════════════════════
-- JAVA: apksigner AND d8 SHELL OUT TO `java`, aapt2 AND zipalign DO NOT
-- ═══════════════════════════════════════════════════════════════════════
--
-- Read directly from the archive's own launchers (2026-09-12) rather than
-- assumed from Gradle's documentation:
--
--   android-37.0/aapt2, zipalign        native ELF/Mach-O/PE binaries. No
--                                        Java anywhere in their closure.
--   android-37.0/apksigner (POSIX)      a `#!/bin/bash` launcher whose last
--   android-37.0/d8        (POSIX)      line is `exec java $javaOpts -jar
--                                        "$jarpath" "$@"` (apksigner) /
--                                        `exec java "${javaOpts[@]}" -cp
--                                        "$jarpath" "$mainClass" "$@"` (d8).
--                                        BOTH call a BARE `java`, found on
--                                        PATH. Neither script reads
--                                        `$JAVA_HOME` anywhere -- exporting
--                                        it changes nothing for these two.
--   android-37.0/apksigner.bat (Win)    THE OPPOSITE: `if defined JAVA_HOME
--   android-37.0/d8.bat        (Win)    goto findJavaFromJavaHome`, then
--                                        `%JAVA_HOME%/bin/java.exe`; only
--                                        falls back to a bare `java.exe` on
--                                        PATH when JAVA_HOME is unset.
--
-- So the fix differs by host, and is chosen accordingly below:
--
--   POSIX (linux, macosx)   a thin wrapper this recipe writes into
--                           `install_dir()/bin/`, which exports BOTH
--                           `JAVA_HOME` (for anything downstream that reads
--                           it) and prepends `$JAVA_HOME/bin` to `PATH`
--                           (because that is the one variable apksigner/d8
--                           actually consult) before `exec`-ing the
--                           archive's own script by absolute path. The same
--                           shape `pkgs/e/emsdk.lua` uses for `NODE_JS`,
--                           adapted because the mechanism here is PATH, not
--                           a config file emcc reads.
--   windows                 `xvm.add(..., envs = { JAVA_HOME = <path> })`
--                           directly on the archive's own `apksigner.bat`/
--                           `d8.bat` -- no wrapper needed, because the shim
--                           mechanism CAN set `JAVA_HOME` (`envs`,
--                           `pkgs/j/jdk-temurin.lua`'s own `config()` uses
--                           the identical option) and the batch file already
--                           honours it.
--
-- THE JDK IS A DECLARED RUNTIME DEPENDENCY, RESOLVED THE WAY emsdk.lua
-- RESOLVES `xim:node` -- `pkginfo.dep_install_dir("xim:jdk-temurin")`, never
-- a subos shim or a bare `java` on PATH, so this package does not depend on
-- the consumer's active `xlings use java` selection. `jdk-temurin.lua`'s own
-- `install_dir()` IS `JAVA_HOME` on every platform (its `payload_dir()`
-- normalises macOS's `Contents/Home` into the same shape), so no further
-- host branching is needed to find `bin/java`. Version floor `>=11`:
-- `lib/d8.jar`'s own `com/android/tools/r8/D8.class` carries class file
-- major version 55 (measured: the class file's bytes 6-8), which is Java
-- 11's format.
--
-- ═══════════════════════════════════════════════════════════════════════
-- INSTALLED LAYOUT
-- ═══════════════════════════════════════════════════════════════════════
--
--   <install_dir>/aapt2[.exe], zipalign[.exe]
--       native binaries, upstream's own, unmodified beyond the executable
--       bit (POSIX) restored after extraction (the zip stores no unix
--       modes, same as every other flat Google archive this index carries).
--   <install_dir>/apksigner[.bat], d8[.bat]
--       upstream's own Java launchers, left in place and NOT the xvm
--       target on POSIX (see above); still present and directly runnable
--       by a caller that provides its own `JAVA_HOME`/PATH.
--   <install_dir>/lib/apksigner.jar, lib/d8.jar
--       the Java implementations the two launchers load.
--   <install_dir>/bin/apksigner, bin/d8            (linux, macosx only)
--       the JAVA_HOME/PATH wrapper scripts this recipe writes; the xvm
--       target on these two hosts.
--   <install_dir>/NOTICE.txt
--       upstream's own, unmodified.
package = {
    spec = "2",
    homepage = "https://developer.android.com/tools/releases/build-tools",

    name = "android-build-tools",
    description = "Android SDK Build-Tools 37: aapt2, zipalign, apksigner and d8, Google's own prebuilt packaging tools",

    maintainers = {"Google", "The Android Open Source Project"},
    licenses = {"Android Software Development Kit License Agreement"},
    repo = "https://android.googlesource.com/platform/tools/base",
    docs = "https://developer.android.com/tools/releases/build-tools",

    type = "package",
    -- aarch64 IS FOR macOS ONLY -- see "HOST ARCH SCOPE" above. Matches
    -- android-ndk.lua and android-platform-tools.lua's identical finding
    -- for the same manifest.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "android", "build-tools"},
    keywords = {"android", "aapt2", "zipalign", "apksigner", "d8", "r8",
                "build-tools", "apk"},

    programs = {"aapt2", "zipalign", "apksigner", "d8"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- apksigner/d8 shell out to `java` unconditionally at link time
            -- for this payload's own packaging step (see the JAVA section
            -- above); it is not an ELF dependency of anything under this
            -- payload (`aapt2`/`zipalign`'s own NEEDED set is core glibc
            -- only -- libc, libm, libpthread, librt, libdl, libgcc_s,
            -- measured with `readelf -d` -- so no glibc/gcc-runtime
            -- declaration belongs here, matching android-ndk.lua's and
            -- emsdk.lua's identical "only core glibc crosses the boundary"
            -- reasoning).
            deps = { runtime = { "xim:jdk-temurin@>=11" } },
            ["latest"] = { ref = "37.0.0" },
            ["37.0.0"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/build-tools_r37_linux.zip",
                },
                sha256 = "01af179347cbcd9c208b7f8171f7b21f6dd1d2f85bcd15e88caa51d5d7b86060",
            },
        },
        macosx = {
            -- One archive for both Apple arches: a universal binary (see
            -- HOST ARCH SCOPE above).
            deps = { runtime = { "xim:jdk-temurin@>=11" } },
            ["latest"] = { ref = "37.0.0" },
            ["37.0.0"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/build-tools_r37_macosx.zip",
                },
                sha256 = "b5b1ac529028a49f11b596b89d9b34252e0f39388ee7dbd16ae3110f1c9c5722",
            },
        },
        windows = {
            deps = { runtime = { "xim:jdk-temurin@>=11" } },
            ["latest"] = { ref = "37.0.0" },
            ["37.0.0"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/build-tools_r37_windows.zip",
                },
                sha256 = "68075aa319ed8a01cf1a565ed1e61a3c1a801dd49191c35851248dc293c33b1a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- The one internal directory name every host's archive shares (measured
-- above). A future revision bump changes this string along with the
-- version table -- deliberately not templated from `pkginfo.version()`,
-- because `source.properties`' `Pkg.Revision` (major.minor.micro) and this
-- directory name (major.minor only, "android-37.0") already disagree within
-- this one revision, matching the same major/short-name mismatch
-- `android-ndk.lua` records for its own release-name-vs-Pkg.Revision case.
local EXTRACT_DIR = "android-37.0"

-- POSIX-only wrapper: exports JAVA_HOME (for anything downstream that reads
-- it) and prepends the resolved JDK's bin/ to PATH (for apksigner/d8
-- themselves, which read PATH and nothing else -- see the JAVA section in
-- the header). `%s` placeholders are the resolved JDK home and the absolute
-- path of the archive's own launcher, both filled in at install time so
-- nothing here depends on the consumer's PATH or active `xlings use`
-- selection.
local WRAPPER_TEMPLATE = [==[
#!/usr/bin/env bash
# %s (xim:android-build-tools wrapper).
#
# The archive's own launcher execs a bare `java` unconditionally and reads
# no JAVA_HOME (measured 2026-09-12; see pkgs/a/android-build-tools.lua's
# header). JAVA_HOME is exported anyway for anything downstream that reads
# it; PATH is what actually makes `java` resolve here.
set -euo pipefail
export JAVA_HOME="%s"
export PATH="$JAVA_HOME/bin:$PATH"
exec "%s" "$@"
]==]

local JAVA_PROGRAMS = {"apksigner", "d8"}
local NATIVE_PROGRAMS = {"aapt2", "zipalign"}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    if not os.isdir(EXTRACT_DIR) then
        raise("android-build-tools: expected extracted directory '"
              .. EXTRACT_DIR .. "' not found beside the downloaded archive")
    end
    os.mv(EXTRACT_DIR, dir)

    local exe = is_host("windows") and ".exe" or ""
    local bat = is_host("windows") and ".bat" or ""

    for _, prog in ipairs(NATIVE_PROGRAMS) do
        local bin = path.join(dir, prog .. exe)
        if not os.isfile(bin) then
            raise("android-build-tools: no " .. prog .. exe .. " at " .. bin
                  .. " -- payload does not look like build-tools for "
                  .. os.host())
        end
        if not is_host("windows") then
            os.exec("chmod 755 \"" .. bin .. "\"")
        end
    end

    for _, prog in ipairs(JAVA_PROGRAMS) do
        local launcher = path.join(dir, prog .. bat)
        if not os.isfile(launcher) then
            raise("android-build-tools: no " .. prog .. bat .. " at "
                  .. launcher .. " -- payload does not look like "
                  .. "build-tools for " .. os.host())
        end
        if not is_host("windows") then
            os.exec("chmod 755 \"" .. launcher .. "\"")
        end
    end

    -- WRAPPERS ARE POSIX ONLY. On Windows, apksigner.bat/d8.bat already
    -- honour JAVA_HOME (see the JAVA section above); config() sets it
    -- through `envs` directly on the archive's own launchers, and no
    -- wrapper file is written.
    if not is_host("windows") then
        local jdk_home = pkginfo.dep_install_dir("xim:jdk-temurin")
        if not jdk_home then
            raise("android-build-tools: xim:jdk-temurin payload not found "
                  .. "(this package's deps declare xim:jdk-temurin); "
                  .. "refusing to write apksigner/d8 wrappers that cannot "
                  .. "find java")
        end

        local bindir = path.join(dir, "bin")
        os.mkdir(bindir)

        for _, prog in ipairs(JAVA_PROGRAMS) do
            local real = path.join(dir, prog)
            local wrapper = path.join(bindir, prog)
            local text = string.format(WRAPPER_TEMPLATE, prog, jdk_home, real)
            local f = io.open(wrapper, "w")
            if not f then
                raise("android-build-tools: cannot write " .. wrapper)
            end
            f:write(text)
            f:close()
            os.iorun('chmod +x "' .. wrapper .. '"')

            if not os.isfile(wrapper) then
                raise("android-build-tools: " .. wrapper .. " was not written")
            end
            local ok = try { function() return os.iorun('bash -n "' .. wrapper .. '"') end }
            if ok == nil then
                raise("android-build-tools: " .. wrapper .. " is not valid shell")
            end
        end
    end

    return true
end

function config()
    local dir = pkginfo.install_dir()

    xvm.add(package.name, { type = "group" })

    for _, prog in ipairs(NATIVE_PROGRAMS) do
        xvm.add(prog, { bindir = dir })
    end

    if is_host("windows") then
        -- envs CAN set JAVA_HOME here, and apksigner.bat/d8.bat honour it --
        -- no wrapper needed. filename is explicit because these launchers
        -- are `.bat`, not `.exe`, and xvm's default target file name equals
        -- the entry's own name (see pkgs/l/llvm-tools.lua's identical
        -- `.exe` override for the same underlying reason, a suffix that is
        -- not the entry's bare name).
        local jdk_home = pkginfo.dep_install_dir("xim:jdk-temurin")
        for _, prog in ipairs(JAVA_PROGRAMS) do
            xvm.add(prog, {
                bindir = dir,
                filename = prog .. ".bat",
                envs = jdk_home and { JAVA_HOME = jdk_home } or nil,
            })
        end
    else
        local bindir = path.join(dir, "bin")
        for _, prog in ipairs(JAVA_PROGRAMS) do
            xvm.add(prog, { bindir = bindir })
        end
    end

    return true
end

function uninstall()
    for _, prog in ipairs(JAVA_PROGRAMS) do
        xvm.remove(prog)
    end
    for _, prog in ipairs(NATIVE_PROGRAMS) do
        xvm.remove(prog)
    end
    xvm.remove(package.name)
    return true
end
