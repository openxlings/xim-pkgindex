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
--   <install_dir>/bin/adb-run
--       a program THIS RECIPE writes, not upstream's -- see "adb-run" below.
--
-- ═══════════════════════════════════════════════════════════════════════
-- adb-run -- an mcpp `runner`, added 2026-09-12 (design record mcpp
-- .agents/docs/2026-09-12-622-a-ui-framework-on-android-ios-and-web.md,
-- section 4.2)
-- ═══════════════════════════════════════════════════════════════════════
--
-- Registered beside `adb`/`fastboot`, the way `simctl-run` is registered
-- beside nothing in `apple-simulator-tools.lua` -- a program, not a manifest
-- flag, for the identical "A SESSION IS NOT A FLAG" reason that header
-- states: installing, waiting for a pid, and streaming a log until the
-- process exits is a session with a beginning and an end.
--
-- TWO OPERAND SHAPES, DECIDED BY THE FILE:
--
--   *.apk           `adb install -r`, then a PLAIN `am start -n <id>/
--                   <activity>` -- NOT `-W`. MEASURED 2026-09-12: `-W`
--                   blocks until ActivityManager reports the launch idle,
--                   and an activity that calls `finish()` from `onCreate`
--                   (exactly what `mcpp run` launches for a "run to
--                   completion" native activity, `tests/apk-consumer`'s own
--                   fixture among them) is torn down before that report
--                   ever fires -- `am start -W` hung indefinitely (two
--                   independent invocations still alive at 691s and 354s,
--                   confirmed by hand, `kill`ed rather than waited out).
--                   `-W`'s own output was never read here (the whole
--                   invocation is redirected to `>&2`), so dropping it costs
--                   nothing in the ordinary case either.
--                   The id/activity pair is read with `aapt2 dump badging`
--                   when `aapt2` is reachable (on PATH, or beside this
--                   script -- the same `xim:android-build-tools` payload's
--                   `bin/`), otherwise from the sidecar
--                   `assets/mcpp-run.json` the APK carries
--                   (`{"package": ..., "activity": ...}`, read with
--                   `unzip -p` because the id is needed before the app is
--                   known to be queryable). `log.redirect-stdio` is set
--                   first, so the application's own stdout/stderr reach
--                   Android's log and this program's `adb logcat --pid=`
--                   -- without it, only what the app explicitly logs through
--                   the Java/NDK log APIs is visible. The pid is read with a
--                   short `pidof` retry loop (the process record lags a
--                   plain `am start`'s own return slightly). The log is
--                   streamed to stdout until EITHER `pidof` no longer finds
--                   the process OR the activity record disappears from
--                   `dumpsys activity activities` -- MEASURED 2026-09-12:
--                   `finish()` ends the activity, not the process (`dumpsys
--                   activity processes` names it `cch-empty`, kept
--                   indefinitely by ActivityManager for reuse), so `pidof`
--                   alone never goes empty for that case; the activity
--                   record disappearing is the signal `finish()` actually
--                   produces, checked in addition to `pidof` so a genuine
--                   crash (which ends both at once) is unaffected. Either
--                   way this script then force-stops the app, so a clean
--                   `finish()` leaves no cached process behind for the next
--                   `adb-run` of the same package to silently reuse. The
--                   exit status is 0 on a clean exit, non-zero when a
--                   `FATAL EXCEPTION` line appears in that pid's own log or
--                   an unfiltered `adb logcat -d` names a tombstone for that
--                   pid (a native crash is reported by `tombstoned`, a
--                   different process, so `--pid` alone does not carry it).
--   anything else   `adb push` to `/data/local/tmp/<name>`, `chmod 755`,
--                   one `adb shell` invocation of it with the remaining
--                   arguments and a trailing `; echo __rc=$?` this script
--                   parses back out, its output printed, the temporary file
--                   removed, its exit status returned.
--
-- DEVICE SELECTION IS adb's OWN. This program passes no `-s`; `ANDROID_
-- SERIAL`, or adb's single-device default, is the caller's configuration,
-- exactly as `SIMCTL_RUN_UDID` is an override rather than a decision in
-- `apple-simulator-tools.lua`'s own runner.
--
-- HOST COVERAGE: this is a POSIX shell script, written into every host's
-- `bin/` alike, but it only RUNS where a POSIX shell is on PATH -- linux and
-- macosx directly, and Windows only under an environment that provides one
-- (Git Bash, WSL, MSYS2), the same coverage boundary `simctl-run`'s own
-- `bash -n` install-time check exists to assert without requiring a device.
--
-- WHAT IS UNMEASURED: the tombstone-detection path (no crashing test binary
-- was run against a real device or emulator while writing this script --
-- see tests/a/test_android_platform_tools.py and the PR report for what was
-- actually exercised, which is the bare-executable path against
-- `adb devices`' first attached target).
package = {
    spec = "2",
    homepage = "https://developer.android.com/tools/releases/platform-tools",

    name = "android-platform-tools",
    description = "Android SDK Platform Tools: adb, fastboot and adb-run, Google's own prebuilt binaries plus an mcpp runner",

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
    -- VERSION BUMPED TO "37.0.1-2" FOR adb-run, WITH THE IDENTICAL ARCHIVE.
    --
    -- Google's own upstream revision is still 37.0.1 (re-checked against
    -- repository2-3.xml on 2026-09-12; no newer platform-tools has shipped),
    -- so there is no new upstream byte to pin. `adb-run` (see the header
    -- section above) is a program this recipe writes at install time, not
    -- part of the downloaded archive, and a bare recipe edit under an
    -- unchanged version key would leave an already-installed 37.0.1 without
    -- it until a manual reinstall. The "-N" revision suffix is the shape
    -- `pkgs/q/qemu-arm.lua` (and its riscv/x86 siblings) already use for the
    -- identical situation -- a recipe-side revision layered on one upstream
    -- release -- so `latest` now resolves to "37.0.1-2", url/sha256
    -- unchanged from "37.0.1" (the bytes are the same archive), and the bare
    -- "37.0.1" entries stay in the table so a manifest already pinned to
    -- them keeps resolving exactly as before.
    --
    -- VERSION BUMPED AGAIN TO "37.0.1-3" FOR THE SAME REASON, ONE SCRIPT
    -- FIX LATER (2026-09-12): `adb-run`'s own `am start -W` hangs
    -- indefinitely for an activity that finishes from `onCreate`, and its
    -- pid-detection loop never returns for one that finishes cleanly
    -- (`finish()` ends the activity, not the process -- see the header
    -- section's "TWO OPERAND SHAPES" for what was measured). Same shape as
    -- the "-2" bump: no new upstream byte, `latest` moves to "37.0.1-3",
    -- and "37.0.1-2"/"37.0.1" both stay resolvable.
    xpm = {
        linux = {
            ["latest"] = { ref = "37.0.1-3" },
            ["37.0.1-3"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-linux.zip",
                },
                sha256 = "d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1",
            },
            ["37.0.1-2"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-linux.zip",
                },
                sha256 = "d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1",
            },
            ["37.0.1"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-linux.zip",
                },
                sha256 = "d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1",
            },
        },
        macosx = {
            -- One archive for both Apple arches: a universal binary.
            ["latest"] = { ref = "37.0.1-3" },
            ["37.0.1-3"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-darwin.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-darwin.zip",
                },
                sha256 = "ee39ad5967e95c2a07f04dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d",
            },
            ["37.0.1-2"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-darwin.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-darwin.zip",
                },
                sha256 = "ee39ad5967e95c2a07f04dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d",
            },
            ["37.0.1"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-darwin.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-darwin.zip",
                },
                sha256 = "ee39ad5967e95c2a07f04dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d",
            },
        },
        windows = {
            ["latest"] = { ref = "37.0.1-3" },
            ["37.0.1-3"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-win.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-win.zip",
                },
                sha256 = "45f4d63113e895ebde0c90f194099a4676b6ac653bd28d54314a9e022bbc1a99",
            },
            ["37.0.1-2"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-win.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-win.zip",
                },
                sha256 = "45f4d63113e895ebde0c90f194099a4676b6ac653bd28d54314a9e022bbc1a99",
            },
            ["37.0.1"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/platform-tools_r37.0.1-win.zip",
                    CN     = "https://gitcode.com/xlings-res/android-platform-tools/releases/download/37.0.1/platform-tools_r37.0.1-win.zip",
                },
                sha256 = "45f4d63113e895ebde0c90f194099a4676b6ac653bd28d54314a9e022bbc1a99",
            },
        },
    },
}

-- WHICH CLAUSE GOVERNS A MIRROR, AND THE ONE THIS INDEX HAD MISSED.
--
-- Every Android package here declares `licenses = {"Android Software
-- Development Kit License Agreement"}`, and that agreement's section 3.4 says:
--
--   "Except to the extent required by applicable third party licenses, you may
--    not copy (except for backup purposes), modify, adapt, redistribute,
--    decompile, reverse engineer, disassemble, or create derivative works of
--    the SDK or any part of the SDK."
--
-- Read alone, that forbids a mirror, and these recipes were written that way --
-- "fetch dl.google.com directly, no CN mirror, no re-host". The next clause is
-- the one that decides:
--
--   3.5 "Use, reproduction and distribution of components of the SDK licensed
--        under an open source software license are governed SOLELY by the terms
--        of that open source software license and NOT the License Agreement."
--
-- So the question is not what the SDK Agreement says, it is what each
-- COMPONENT's own licence says. Checked inside the archives themselves rather
-- than asserted (2026-09-11):
--
--   emulator-linux_x64-*.zip   emulator/LICENSE       the Apache-2.0 grant, verbatim
--   platform-tools_r*.zip      NOTICE.txt             Apache License
--   android-ndk-r*.zip         NOTICE                 "Licensed under the Apache
--                                                      License, Version 2.0"
--   <abi>-24_r*.zip            NOTICE.txt             AOSP `default` build; OSS
--                                                      notices throughout
--
-- All four are open-source-licensed components, so 3.5 applies and 3.4 does
-- not. The mirrors are legitimate.
--
-- THE DISTINCTION THIS SHARPENS RATHER THAN WEAKENS: pkgs/i/iphoneos-sdk.lua
-- still carries no CN entry, and now for a reason that is specific instead of
-- shared. Apple's SDK has no equivalent of 3.5 and its components are not
-- open-source licensed, so holding a copy really is redistribution. "The
-- licence decides" was the right rule; applying it to these four without
-- reading past 3.4 was the error.

-- WHAT A REGIONAL `url` MAP ACTUALLY DOES, MEASURED (2026-09-11).
--
-- The measurement first, because it is worth keeping wherever a regional map
-- IS used. The two-entry map is REDUNDANCY, not selection. Measured by
-- breaking each host in turn, clearing both the store entry and the download
-- cache between runs:
--
--   mirror   GLOBAL   CN     result
--   CN       dead     live   downloaded
--   CN       live     dead   downloaded
--   GLOBAL   dead     live   downloaded
--   GLOBAL   live     dead   downloaded
--   CN       dead     dead   no download
--
-- So `--mirror` is at most an ordering preference: xlings reaches the other
-- host when the preferred one fails, and only an unreachable PAIR fails the
-- install. The last row is why the other four mean anything -- without it,
-- "downloaded" is also what a probe that cannot detect failure prints. A CN
-- entry therefore buys a second source for every user, not a different source
-- for CN users.
--
-- Also mirrored in this ecosystem: `xim:emsdk` (MIT / NCSA) and `xim:python`
-- (PSF).

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- adb-run -- see the header section above for the full design reading.
-- Measured 2026-09-12 against this package's own installed `adb` (37.0.1),
-- `bash -n`, and one real bare-executable round trip when a device was
-- attached (see tests/a/test_android_platform_tools.py); the tombstone path
-- is unmeasured (no crashing binary was run).
local __adb_run_sh = [==[
#!/usr/bin/env bash
# adb-run --- install and run an Android application, or push and run a bare
# executable, on whichever device/emulator `adb` currently sees.
#
# Usage:
#   adb-run <path-to.apk>
#   adb-run <path-to-executable> [arguments...]
#
# Used as an mcpp `runner`:
#
#   [target.x86_64-linux-android]
#   runner = ["adb-run"]
#
# DEVICE SELECTION IS adb's OWN. This program passes no `-s`; `ANDROID_
# SERIAL`, or adb's single-device default, is the caller's configuration --
# the identical boundary `apple-simulator-tools.lua`'s `simctl-run` keeps
# with `SIMCTL_RUN_UDID` (an override, never a decision this program makes
# for the caller).
#
# THE EXIT STATUS IS THE PROGRAM'S. For a bare executable that is Linux's own
# exit(2) status, forwarded verbatim; for an installed application, which the
# platform hands nothing back for directly, it is 0 on a clean exit and
# non-zero when that pid's own log carries a `FATAL EXCEPTION` or an
# unfiltered log names a tombstone for that pid.
set -uo pipefail

if [ "$#" -lt 1 ]; then
    echo "adb-run: usage: adb-run <apk-or-executable> [arguments...]" >&2
    exit 2
fi

operand="$1"; shift

if ! command -v adb > /dev/null 2>&1; then
    echo "adb-run: no adb on PATH. xim:android-platform-tools provides it;" >&2
    echo "         declare it as a dependency of whatever resolves this" >&2
    echo "         runner." >&2
    exit 2
fi

if [ ! -f "$operand" ]; then
    echo "adb-run: $operand does not exist" >&2
    exit 2
fi

# Portable POSIX single-quoting, for the ONE command line `adb shell` sends
# to the device's remote shell when given more than one argv element: adb
# joins them with a plain space itself before handing the result to
# `sh -c`, so an argument carrying whitespace or a shell metacharacter has
# to be quoted here, not by adb.
__quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

case "$operand" in
    *.apk)
        # ═══════════════════ AN APPLICATION ═══════════════════
        if ! adb install -r "$operand" >&2; then
            echo "adb-run: adb install -r failed for $operand" >&2
            exit 2
        fi

        # THE APPLICATION ID AND LAUNCHABLE ACTIVITY. aapt2 reads the
        # manifest the way the platform itself does, so it is authoritative
        # when reachable -- on PATH, or beside this script (the same
        # xim:android-build-tools payload's bin/, since a project that packs
        # an APK also declares that dependency). Otherwise the APK is
        # expected to carry the sidecar `mcpp:plugins`' dist-apk member
        # writes, `assets/mcpp-run.json`, read with `unzip -p` because the
        # id is needed before the package is known to be queryable on the
        # device.
        aapt2=""
        if command -v aapt2 > /dev/null 2>&1; then
            aapt2="aapt2"
        else
            here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            for candidate in "$here/aapt2" "$here/../aapt2"; do
                if [ -x "$candidate" ]; then
                    aapt2="$candidate"
                    break
                fi
            done
        fi

        app_id=""
        activity=""
        if [ -n "$aapt2" ]; then
            badging="$("$aapt2" dump badging "$operand" 2>/dev/null)"
            app_id="$(printf '%s\n' "$badging" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1)"
            activity="$(printf '%s\n' "$badging" | sed -n "s/^launchable-activity: name='\([^']*\)'.*/\1/p" | head -1)"
        fi

        if [ -z "$app_id" ] || [ -z "$activity" ]; then
            sidecar="$(unzip -p "$operand" assets/mcpp-run.json 2>/dev/null)"
            if [ -z "$sidecar" ]; then
                echo "adb-run: could not determine the application id and" >&2
                echo "         activity: aapt2 was not found on PATH or" >&2
                echo "         beside this script, and $operand carries no" >&2
                echo "         assets/mcpp-run.json sidecar." >&2
                exit 2
            fi
            app_id="$(printf '%s' "$sidecar" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("package",""))' 2>/dev/null)"
            activity="$(printf '%s' "$sidecar" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("activity",""))' 2>/dev/null)"
        fi

        if [ -z "$app_id" ] || [ -z "$activity" ]; then
            echo "adb-run: package/activity could not be determined for $operand" >&2
            exit 2
        fi

        # REDIRECT THE APPLICATION'S OWN stdio INTO LOGCAT. Without this, an
        # installed application's `printf`/`std::cout` never reach this
        # program -- only what it explicitly logs through the Java/NDK log
        # APIs would. Bionic honours this documented system property in the
        # zygote-forked process's own stdio setup.
        adb shell setprop log.redirect-stdio true >&2

        # PLAIN `am start`, NOT `-W`. `-W` blocks until ActivityManager
        # reports the launch complete/idle, and MEASURED 2026-09-12: for an
        # activity that calls `finish()` from `onCreate` (this fixture's
        # own row, and any other "run to completion" native activity), that
        # report never arrives -- the activity is torn down before it is
        # ever reported idle, and `adb shell am start -W` hangs forever
        # (confirmed: two independent invocations still alive at 691s and
        # 354s, killed by hand, `am start` -- no `-W` -- returns
        # immediately in the same situation). `-W`'s own "Status/WaitTime/
        # TotalTime" block was never read by this script (its whole
        # invocation is redirected to `>&2`), so it bought nothing here;
        # the retry loop directly below already tolerates the ordinary
        # case where the process record lags a plain `am start`'s return.
        if ! adb shell am start -n "$app_id/$activity" >&2; then
            echo "adb-run: am start failed for $app_id/$activity" >&2
            exit 2
        fi

        # THE PID, RETRIED BRIEFLY: the process record `pidof` reads is
        # populated at zygote-fork time, slightly after `am start` itself
        # returns -- so failing once before finding it is ordinary.
        pid=""
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            pid="$(adb shell pidof "$app_id" 2>/dev/null | tr -d '\r\n ')"
            [ -n "$pid" ] && break
            sleep 1
        done

        if [ -z "$pid" ]; then
            echo "adb-run: $app_id started but no pid was found (pidof)" >&2
            exit 2
        fi

        # STREAM THE PROCESS'S OWN LOG TO STDOUT until it exits. `mcpp run`/
        # `mcpp test` read this program's stdout as the application's
        # output, so the log has to reach the caller and not only a file.
        logfile="$(mktemp)"
        adb logcat --pid="$pid" > "$logfile" 2>/dev/null &
        logcat_pid=$!

        # WAIT FOR THE RUN TO END -- TWO DISTINCT ENDINGS, NEITHER COVERING
        # THE OTHER. A crash kills the process outright (`pidof` goes
        # empty). A well-behaved activity that calls `finish()` (this
        # fixture's own `ANativeActivity_finish`) only ends the ACTIVITY --
        # MEASURED 2026-09-12: the process itself is kept by
        # ActivityManager as a cached, reusable process (`dumpsys activity
        # processes` names it `cch-empty` indefinitely afterward), so a
        # loop keyed on `pidof` alone never returns for that case, which is
        # every activity this fixture, or anything shaped like it, launches
        # through `mcpp run`. The activity record disappearing from
        # `dumpsys activity activities` is the signal `finish()` actually
        # produces (confirmed absent within the same second the activity
        # finishes), checked in addition to, not instead of, `pidof`, so a
        # crash still ends the loop exactly as before.
        while adb shell dumpsys activity activities 2>/dev/null \
                | grep -q "$app_id/" \
              && adb shell pidof "$app_id" 2>/dev/null | grep -q .; do
            sleep 1
        done

        # A moment for the last lines to arrive before the pipe is cut.
        sleep 1
        kill "$logcat_pid" 2>/dev/null
        wait "$logcat_pid" 2>/dev/null

        cat "$logfile"

        status=0
        if grep -q "FATAL EXCEPTION" "$logfile"; then
            status=1
        fi
        # A NATIVE CRASH IS REPORTED BY A DIFFERENT PROCESS (tombstoned), so
        # `--pid` above does not carry it; a separate unfiltered dump is read
        # for a tombstone naming this pid. UNMEASURED -- see the header
        # comment at the top of this file.
        if adb logcat -d 2>/dev/null \
                | grep -qE "pid: $pid[,)].*[Tt]ombstone|[Tt]ombstone.*pid: $pid[,)]"; then
            status=1
        fi
        rm -f "$logfile"

        # A CLEAN `finish()` LEAVES THE PROCESS CACHED, NOT DEAD (see
        # above); force-stopping it here is what actually reclaims it, so
        # the NEXT `adb-run` of the same package starts from a fresh
        # process rather than silently reusing this one's.
        adb shell am force-stop "$app_id" >&2 2>/dev/null || true

        exit "$status"
        ;;

    *)
        # ═══════════════════ A BARE EXECUTABLE ═══════════════════
        name="$(basename "$operand")"
        remote="/data/local/tmp/$name"

        if ! adb push "$operand" "$remote" >&2; then
            echo "adb-run: adb push failed for $operand" >&2
            exit 2
        fi
        adb shell chmod 755 "$remote" >&2

        remote_cmd="$(__quote "$remote")"
        for a in "$@"; do
            remote_cmd="$remote_cmd $(__quote "$a")"
        done

        out="$(adb shell "$remote_cmd; echo __rc=\$?" | tr -d '\r')"
        rc="$(printf '%s\n' "$out" | tail -1 | sed -n 's/^__rc=\([0-9-]*\)$/\1/p')"
        printf '%s\n' "$out" | sed '$d'

        adb shell rm -f "$remote" >&2

        if [ -z "$rc" ]; then
            echo "adb-run: could not read the remote exit status for $operand" >&2
            exit 2
        fi
        exit "$rc"
        ;;
esac
]==]

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
                  .. os.host())
        end
        -- The zip stores no unix modes at all, so the executable bit has to
        -- be restored rather than merely preserved (same pattern as
        -- pkgs/a/aria2-next.lua). Windows has no mode to restore and no
        -- chmod to run.
        if not is_host("windows") then
            os.exec("chmod 755 \"" .. bin .. "\"")
        end
    end

    -- adb-run: written into bin/ regardless of host (see "HOST COVERAGE" in
    -- the header section), the same directory convention
    -- apple-simulator-tools.lua uses for the identical reason -- a consumer
    -- can rely on `<payload>/bin` being searched.
    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)
    local runner = path.join(bindir, "adb-run")
    local f = io.open(runner, "w")
    if not f then
        raise("android-platform-tools: cannot write " .. runner)
    end
    f:write(__adb_run_sh)
    f:close()

    if not os.isfile(runner) then
        raise("android-platform-tools: " .. runner .. " was not written")
    end

    -- POSIX ONLY, matching the identical chmod guard above: Windows has no
    -- chmod and, on a plain install with no Git Bash/WSL, no bash either.
    -- The file is still written there (see "HOST COVERAGE" in the header
    -- section) -- this is the "cannot verify, do not claim" gap that leaves,
    -- stated rather than silently skipped.
    if not is_host("windows") then
        os.iorun('chmod +x "' .. runner .. '"')
        local ok = try { function() return os.iorun('bash -n "' .. runner .. '"') end }
        if ok == nil then
            raise("android-platform-tools: " .. runner .. " is not valid shell")
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
    -- adb-run lives one level down, in the bin/ this recipe writes (see
    -- install()), the same split apple-simulator-tools.lua has between its
    -- payload root and its own program.
    xvm.add("adb-run", { bindir = path.join(bindir, "bin") })
    return true
end

function uninstall()
    xvm.remove("adb-run")
    xvm.remove("fastboot")
    xvm.remove("adb")
    xvm.remove(package.name)
    return true
end
