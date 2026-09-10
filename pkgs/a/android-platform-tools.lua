-- Android Platform Tools -- adb and fastboot, Google's own prebuilt binaries.
--
-- WHY THIS PACKAGE EXISTS ON ITS OWN, RATHER THAN INSIDE android-emulator OR
-- android-ndk. Three payloads came out of one investigation (mcpp .agents/
-- docs/2026-09-11-distribution-plugins-and-platform-decomposition.md,
-- section 3.1, and the task report that measured dynamic Android execution
-- against a real system image) and the question was asked explicitly: one
-- package, or several?
--
--   platform-tools  9 MB,   useful alone (talks to ANY device, real or
--                           emulated; a project that only pushes to a
--                           physical phone over USB needs nothing else here)
--   emulator      334 MB,   one version lineage, needs SOME system image to
--                           do anything, but not a SPECIFIC one
--   a system image  ~300-450 MB EACH, and upstream publishes dozens of
--                           (api-level, tag, abi) combinations
--
-- Folding all three into one package would mean every emulator point
-- release forces re-fetching multi-gigabyte image data nobody asked to
-- change, and every consumer who only wants `adb` to talk to a physical
-- device would pull the emulator and a system image regardless. Splitting
-- them lets each be installed, cached and removed independently -- this is
-- the smallest and most standalone-useful of the three, hence first.
--
-- ═══════════════════════════════════════════════════════════════════════
-- LICENCE
-- ═══════════════════════════════════════════════════════════════════════
--
-- Same posture as pkgs/a/android-ndk.lua: this download is gated behind
-- Google's "Android Software Development Kit License Agreement", section
-- 3.4 of which forbids redistribution. Fetch dl.google.com directly; no
-- GitCode mirror, no `ci = { mirror = true }`.
--
-- ═══════════════════════════════════════════════════════════════════════
-- WHAT WAS MEASURED (2026-09-11), AND WHERE THE NUMBERS BELOW COME FROM
-- ═══════════════════════════════════════════════════════════════════════
--
-- Google publishes every SDK component's URL and a SHA1 checksum in a
-- machine-readable manifest it also reads itself:
--
--   https://dl.google.com/android/repository/repository2-3.xml
--
-- The <remotePackage path="platform-tools"> entry for host-os "linux" (the
-- ONLY Linux entry -- see "HOST ARCH SCOPE" below) named:
--
--   url      platform-tools_r37.0.1-linux.zip
--   size     9054187
--   sha1     477254aa5f903c15cf51001717bdf347fb6b53e0
--
-- Fetched directly with curl (not through sdkmanager -- seeVERIFICATION
-- below for why that distinction matters), and verified byte-for-byte:
-- downloaded size and sha1sum both matched the manifest exactly. This
-- index pins sha256, which the manifest does not publish, so it was
-- computed locally on the verified download.
--
-- ═══════════════════════════════════════════════════════════════════════
-- VERIFICATION: sdkmanager WAS TRIED FIRST AND REJECTED, AND WHY
-- ═══════════════════════════════════════════════════════════════════════
--
-- The current "cmdline-tools" ships a Kotlin rewrite ("Android CLI",
-- `sdkmanager --version` reports "1.0.16261425 (Android CLI)" with a
-- deprecation warning) whose first `sdkmanager` invocation self-installs a
-- content-addressed store and an analytics/crash-report tree under
-- `$ANDROID_USER_HOME`, INCLUDING WHEN THAT VARIABLE IS UNSET, in which
-- case it defaults to `$HOME/.android` regardless of `--sdk_root`. That
-- behaviour is what destroyed a real user's adb keypair and debug keystore
-- in a prior run of the task this recipe was written for. Routing package
-- management through it also means xlings pins and hashes nothing: the
-- actual bytes on disk are whatever that tool's own downloader fetched.
--
-- The fix is not a more careful sdkmanager invocation. It is not using
-- sdkmanager at all: fetch the manifest, read the URL and checksum out of
-- it exactly as sdkmanager does, and verify independently. No JDK is
-- reachable from, or needed by, this recipe as a result (`sdkmanager` is a
-- Java program; a curl fetch and a zip extraction are not).
--
-- ═══════════════════════════════════════════════════════════════════════
-- HOST ARCH SCOPE
-- ═══════════════════════════════════════════════════════════════════════
--
-- `archs = {"x86_64"}`: repository2-3.xml lists exactly three host-os
-- values for `platform-tools` (linux, macosx, windows) and only one per
-- value -- there is no separate linux-aarch64 build, matching
-- android-ndk.lua's identical finding for the NDK itself. This package is
-- therefore unusable, not merely unverified, on a Linux/aarch64 host.
--
-- ═══════════════════════════════════════════════════════════════════════
-- INSTALLED LAYOUT
-- ═══════════════════════════════════════════════════════════════════════
--
--   <install_dir>/adb, fastboot, etc1tool, hprof-conv, mke2fs, ...
--       upstream's own flat layout, unmodified beyond the top-level
--       rename from "platform-tools" (the zip's own internal directory
--       name) to this package's install directory.
package = {
    spec = "2",
    homepage = "https://developer.android.com/tools/releases/platform-tools",

    name = "android-platform-tools",
    description = "Android SDK Platform Tools: adb and fastboot, Google's own prebuilt binaries",

    maintainers = {"Google", "The Android Open Source Project"},
    licenses = {"Android Software Development Kit License Agreement"},
    repo = "https://android.googlesource.com/platform/packages/modules/adb",
    docs = "https://developer.android.com/tools/adb",

    type = "package",
    -- aarch64 IS FOR macOS ONLY, and that is upstream's answer rather than a
    -- choice here: the manifest publishes no aarch64 LINUX platform-tools
    -- archive at all (searched, zero hits), while the single `darwin` archive
    -- serves both Apple arches because it is a universal binary -- measured:
    -- `Mach-O universal binary with 2 architectures`.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "android"},
    keywords = {"android", "adb", "fastboot", "platform-tools"},

    -- WHAT WAS VERIFIED PER PLATFORM, STATED RATHER THAN IMPLIED.
    --
    -- All three archives were fetched with curl on 2026-09-11 and each one's
    -- SIZE and sha1 matched `repository2-3.xml` byte for byte; the sha256
    -- values below were computed from those downloads. Only the LINUX payload
    -- was unpacked and executed (`adb --version` reporting
    -- `1.0.41, Version 37.0.1-15733141`), because that is the host this was
    -- done on.
    --
    -- So macOS and Windows are declared on the strength of an integrity check
    -- and not of a run. That is a weaker claim than Linux's and is the reason
    -- it is written down: `android-ndk.lua` scopes itself to Linux alone on
    -- the same principle, and the difference here is that these two archives
    -- were actually hashed rather than merely believed to exist.
    xpm = {
        linux = {
            ["latest"] = { ref = "37.0.1" },
            ["37.0.1"] = {
                url = "https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip",
                sha256 = "d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1",
            },
        },
        macosx = {
            -- One archive for both Apple arches: a universal binary.
            ["latest"] = { ref = "37.0.1" },
            ["37.0.1"] = {
                url = "https://dl.google.com/android/repository/platform-tools_r37.0.1-darwin.zip",
                sha256 = "ee39ad5967e95c2a07f04dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d",
            },
        },
        windows = {
            ["latest"] = { ref = "37.0.1" },
            ["37.0.1"] = {
                url = "https://dl.google.com/android/repository/platform-tools_r37.0.1-win.zip",
                sha256 = "45f4d63113e895ebde0c90f194099a4676b6ac653bd28d54314a9e022bbc1a99",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- The zip's own top-level directory is literally "platform-tools" --
    -- no release-name-vs-Pkg.Revision mismatch of the kind android-ndk.lua
    -- has to work around (verified with `unzip -l` against the actual
    -- downloaded archive).
    if not os.isdir("platform-tools") then
        raise("android-platform-tools: expected extracted directory "
              .. "'platform-tools' not found beside the downloaded archive")
    end
    os.mv("platform-tools", dir)

    -- The executable name carries the host's suffix, and so must the
    -- assertion: the archives are per-platform, and a check written for one
    -- of them reports "the payload is wrong" on every other host. Naming the
    -- host in the message rather than a fixed platform string is the point --
    -- the failure has to say which payload was actually inspected.
    local exe = is_host("windows") and ".exe" or ""
    for _, prog in ipairs({"adb", "fastboot"}) do
        local bin = path.join(dir, prog .. exe)
        if not os.isfile(bin) then
            raise("android-platform-tools: no " .. prog .. exe .. " at " .. bin
                  .. " -- payload does not look like platform-tools for "
                  .. os.host() .. "-" .. os.arch())
        end
        -- The zip stores no unix modes at all, so the executable bit has to
        -- be restored rather than merely preserved (same pattern as
        -- pkgs/a/aria2-next.lua). Windows has no mode to restore and no
        -- chmod to run.
        if not is_host("windows") then
            os.exec("chmod 755 \"" .. bin .. "\"")
        end
    end

    return true
end

function config()
    -- Bare shims for both binaries (bindir pattern, matching
    -- pkgs/q/qemu-arm.lua's identical flat-layout case). Unlike
    -- android-ndk's clang++ (which would collide with xim:llvm's own
    -- registration), "adb" and "fastboot" are not claimed by anything else
    -- in this index, and a project's own runner script is the intended
    -- consumer of the bare name (docs/04-mcpp-toml.md SS2.7.3: "A bare name
    -- on PATH resolves to an xvm shim, which answers for the current
    -- SubOS").
    local bindir = pkginfo.install_dir()
    xvm.add(package.name)
    xvm.add("adb", { bindir = bindir })
    xvm.add("fastboot", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("fastboot")
    xvm.remove("adb")
    xvm.remove(package.name)
    return true
end
