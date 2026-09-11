-- Android Emulator -- Google's own prebuilt QEMU2-based engine.
--
-- WHY THIS PACKAGE EXISTS. mcpp's toolchain model carries `aarch64-linux-
-- android` and `x86_64-linux-android` as `preview`, not `verified`, and the
-- gap is specifically about the DEFAULT (dynamic) configuration: every
-- dynamic Android artifact carries `interpreter /system/bin/linker64`,
-- which exists nowhere in the NDK (xim:android-ndk's bionic is a header-
-- and-stub sysroot, not a bootable OS), and the NDK's own libc.so is an
-- inert stub -- 1147 exported functions in 9176 bytes of `.text`, each
-- disassembling to `bti c; ret`. Closing that gap needs the one thing that
-- supplies both a real loader and a real bionic: an actual system image,
-- booted by an actual emulator. This package is the engine half of that;
-- pkgs/a/android-system-image.lua is the image half.
--
-- WHAT WAS MEASURED END TO END (2026-09-11), on an x86_64 Linux host with
-- /dev/kvm usable by the installing user:
--
--   push hello_x86_64-linux-android_dynamic (interpreter /system/bin/
--   linker64, NEEDED libc++_shared.so/libm.so/libdl.so/libc.so) to a
--   booted android-24 default x86_64 AVD's /data/local/tmp, chmod 755,
--   run under `adb shell` with libc++_shared.so (from xim:android-ndk's
--   own sysroot -- NOT part of any system image) staged beside it via
--   LD_LIBRARY_PATH:
--
--     without libc++_shared.so staged:
--       CANNOT LINK EXECUTABLE "...": library "libc++_shared.so" not found
--       (exit 134 / SIGABRT -- confirmed on the device's REAL linker64,
--       not inferred from readelf)
--     with it staged:
--       android-exec-ok                                    (exit 0)
--
--   The `import std` artifact (the one that matters, since `import std`
--   availability is a build-fingerprint input) with the same treatment:
--       1-2-3                                               (exit 0)
--
--   Boot time, process launch to `sys.boot_completed=1`: 10 seconds,
--   KVM-accelerated, android-24 default x86_64, `-no-window -no-audio
--   -no-boot-anim -no-snapshot -gpu swiftshader_indirect`.
--
-- So the honest claim this package makes possible is narrower than "Android
-- execution works": it is "a DYNAMIC x86_64-linux-android artifact executes
-- against a real system image, given the NDK's own libc++_shared.so staged
-- alongside it" -- which is exactly the mcpp row's default configuration,
-- on the one host arch this was actually run on.
--
-- ═══════════════════════════════════════════════════════════════════════
-- arm64-v8a WAS ATTEMPTED AND REFUSED -- NOT SLOW, BLOCKED
-- ═══════════════════════════════════════════════════════════════════════
--
-- The task this recipe was written against expected "full TCG on an x86_64
-- host, so expect a slow boot". That is not what happened. Booting an
-- android-24 default arm64-v8a AVD on this same x86_64 host failed
-- immediately:
--
--   FATAL | QEMU2 emulator does not support arm64 CPU architecture
--
-- and the emulator binary's own string table names the exact policy
-- (`strings emulator | grep -i "does not support"`):
--
--   "Avd's CPU Architecture '%s' is not supported by the QEMU2 emulator on
--    x86_64 host. System image must match the host architecture."
--
-- This is a hard, unconditional gate, not a slow path: a `qemu-system-
-- aarch64` (and `-headless`) binary IS physically present in this exact
-- package (verified with `find`), so the refusal is a launcher-level
-- policy decision, not a missing backend. There is no undocumented
-- override flag in the binary's own strings. So dynamic aarch64-linux-
-- android execution is NOT reachable through THIS PACKAGE'S ENGINE on an
-- x86_64 host at any time budget -- it needs an aarch64 HOST (a Linux/
-- aarch64 CI runner, or Apple Silicon under a macOS build of this same
-- emulator, neither available to verify here). Static aarch64-linux-
-- android already runs under plain `qemu-aarch64` (a separate, already-
-- `verified` path); this package does not change that row's tier on an
-- x86_64 CI runner. (A materially different, non-emulator mechanism DOES
-- reach the default/dynamic configuration on an x86_64 host -- see
-- android-system-image.lua's "A SECOND, INDEPENDENT PATH" section, which
-- is where that finding actually lives, not here.)
--
-- ALL FOUR CURRENTLY-SERVED LINUX EMULATOR BUILDS WERE CHECKED, NOT ONE.
--
-- The natural follow-up -- "is 15917651 just the one this index happened
-- to pick, and does some OTHER served build skip the gate" -- was tested
-- directly rather than left as a plausible guess (2026-09-11). Parsing
-- repository2-3.xml for every linux-host remotePackage archive entry
-- under path "emulator" currently served finds exactly four:
--
--   37.1.1   (build 16013376)   emulator_linux_x64-16013376.zip
--   37.1.2   (build 16173978)   emulator_linux_x64-16173978.zip
--   37.1.11  (build 15917651)   emulator-linux_x64-15917651.zip  <- pinned here
--   37.2.8   (build 16259959)   emulator-linux_x64-16259959.zip
--
-- All four were fetched (sha1 verified against the manifest) and booted
-- against the same hand-written arm64-v8a AVD this file's header used.
-- They split into two groups, and NEITHER group boots this image:
--
--   37.1.11 and 37.2.8 -- the two hyphen-named, emulator/qemu/linux-
--   x86_64/...-layout builds -- carry the identical gate string in their
--   `emulator` binary and fail identically. Independently re-run for
--   37.2.8, not inferred from the shared string alone:
--     Android emulator version 37.2.8.0 (build_id 16259959)
--     Found AVD target architecture: arm64
--     FATAL | QEMU2 emulator does not support arm64 CPU architecture
--
--   37.1.1 and 37.1.2 -- underscore-named, carrying an emulator/fishtank/
--   subtree and emulator/bin/qemu-system-aarch64 (a different path than
--   the other two), an "[ALPHA]" / "Copyright 2026" / "Welcome to
--   goldfish" banner -- do NOT contain the gate string at all (`strings
--   emulator | grep -i "does not support"` finds nothing architecture-
--   related), which first looked like a real candidate for "an older
--   build without the gate". Booting either against this same API 24
--   image reaches a DIFFERENT, earlier failure instead (both
--   independently run):
--     ERROR main.cc:443 | Unknown AVD name [mcpp_arm64_api24], use
--       -list-avds to see valid list.
--     ERROR main.cc:446 | System image file not found:
--       VerifiedBootParams.textproto
--   i.e. this channel's launcher validates the system image against a
--   newer (Android-Verified-Boot-era) manifest shape before it ever
--   reaches a CPU-architecture check, and a 2016-era API 24 image has no
--   VerifiedBootParams.textproto. This is not a version-ordering
--   coincidence: "37.1.1" build 16013376 is not chronologically OLDER
--   than "37.1.11" build 15917651 despite the smaller middle digit -- the
--   fishtank banner reads "Copyright 2026", same as the other two. The
--   four manifest entries are four release channels of the CURRENT
--   generation, not a spread reaching back to the pre-ranchu/QEMU2
--   (goldfish/QEMU1) engine that predates this gate -- that engine, if it
--   still exists anywhere, is not in the manifest Google currently serves.
--
-- So Hypothesis B -- "an older emulator release without the arm64 gate,
-- the way ARM AVDs worked before x86 images existed" -- is refuted for
-- every build this manifest currently serves, not only the one this
-- package pins. No new version key is added here for that reason: there
-- is no build to add that both lacks the gate AND boots this image.
--
-- Documentation aside, not measured here: a GitHub-hosted arm64 Linux
-- runner (ubuntu-24.04-arm / ubuntu-22.04-arm, generally available for
-- public repositories since a 2025-01-16 changelog and extended to
-- private repositories 2026-01-29) would sidestep this specific
-- x86_64-host gate by making host and guest architecture match, but as of
-- an open upstream issue (actions/runner-images#14062) that runner class
-- does not expose /dev/kvm, so this same engine would still only reach
-- the slow software-virtualization path there, not the ~10s KVM path this
-- header measured for x86_64. Neither claim in this paragraph was
-- re-verified on such a runner -- it is read from current documentation
-- and a tracked upstream issue, stated as that and no more.
--
-- ═══════════════════════════════════════════════════════════════════════
-- avdmanager IS NOT NEEDED, AND DELIBERATELY NOT USED
-- ═══════════════════════════════════════════════════════════════════════
--
-- `avdmanager` (bundled in the separate `cmdline-tools` download this index
-- does not package -- see the sdkmanager section of pkgs/a/android-
-- platform-tools.lua for why) is a Java program, and pulling in a JDK
-- dependency to create a directory and two INI files is disproportionate.
-- Measured working instead: writing `<AvdHome>/<name>.ini` (an
-- `avd.ini.encoding` / `path=` / `target=` pointer) and `<name>.avd/
-- config.ini` (`abi.type`, `hw.cpu.arch`, `image.sysdir.1` relative to the
-- SDK root, and a conventional `hw.*` set) by hand, then copying the
-- chosen system image's own `userdata.img` into the AVD directory --
-- exactly what avdmanager itself does at creation time, reproduced without
-- it. The x86_64 AVD built this way reached `sys.boot_completed=1` in 10
-- seconds; nothing about the failure mode above changed for arm64-v8a
-- (the FATAL predates any first-boot state). No JDK is declared as a
-- dependency of this package, or of android-system-image, as a result.
--
-- ═══════════════════════════════════════════════════════════════════════
-- HOST DEPENDENCIES BEYOND KVM -- MEASURED, NOT INFERRED
-- ═══════════════════════════════════════════════════════════════════════
--
-- `readelf -d emulator` and a direct trace via the host's own loader
-- (`LD_TRACE_LOADED_OBJECTS=1 /lib64/ld-linux-x86-64.so.2 emulator` -- the
-- bare `ldd` command is itself an xvm shim answering for a different
-- payload on this ecosystem's own hosts, so the direct form is what a
-- recipe author must reach for) show:
--
--   INTERP           the HOST's own /lib64/ld-linux-x86-64.so.2, unmodified
--   RPATH            $ORIGIN/lib64:$ORIGIN -- self-contained for its OWN
--                    libandroid-emu-*.so, libc++.so, libglib2, libprotobuf,
--                    libabseil_dll.so (all resolve from the bundled lib64/)
--   crosses the host  libc/libm/libdl/libpthread/librt/libgcc_s (core
--   boundary anyway   glibc -- always present, matching xim:android-ndk's
--                     own "empty deps" reasoning, contributing.md SS5.1)
--   FROM THE ECOSYSTEM libX11.so.6, and transitively libxcb.so.1,
--                     libXau.so.6, libXdmcp.so.6, libbsd.so.0, libmd.so.0
--                     -- declared as `deps` (see the xpm block)
--
-- The libX11 chain is unconditional: DT_NEEDED entries load at exec time
-- regardless of `-no-window`, and the same binary refuses to start at all
-- without them, headless or not (verified). So the chain is a dependency
-- of this package and is declared as one. Every link already exists in
-- this index, so closing the loop required declaring rather than adding.
--
-- It was a `hostlib.dirs_of` probe with a warning pointing at the host
-- distribution, on the precedent of pkgs/g/godot.lua. That precedent does
-- not hold here: xlings is a user-space distribution, and a payload that
-- needs a library says so rather than telling the user to find it. A
-- warning is the right shape only for something no package can supply --
-- which, in this recipe, is KVM and nothing else.
--
-- KVM ITSELF is not something this package can supply or verify at
-- install time in general (`/dev/kvm` group membership is a host
-- configuration decision) -- confirmed openable by this installing user
-- with `os.open(O_RDWR)` while writing this recipe, and left as a runtime
-- fact the emulator itself reports (it falls back to software
-- virtualization, much slower, rather than refusing outright, if KVM is
-- absent).
--
-- ═══════════════════════════════════════════════════════════════════════
-- LICENCE, VERIFICATION, AND HOST ARCH SCOPE
-- ═══════════════════════════════════════════════════════════════════════
--
-- MIRRORED FOR CN. `emulator/LICENSE` inside the archive carries the
-- Apache-2.0 grant verbatim, so SDK Agreement 3.5 governs it and 3.4 does not
-- -- see the clause note in pkgs/a/android-platform-tools.lua. The archive on
-- GitCode is byte-identical, verified by downloading it back and hashing it.
-- repository2-3.xml's <remotePackage path="emulator"> for host-os "linux"
-- (again the only Linux entry -- see android-platform-tools.lua's
-- identical "HOST ARCH SCOPE" note) named:
--
--   url      emulator-linux_x64-15917651.zip
--   size     334378080
--   sha1     1b1f78891abf8ec268264356e1365c25519e8379
--
-- (A newer emulator-linux_x64-16259959.zip is also listed, on a different
-- release channel; 15917651 is what this index's own default-channel
-- resolution selected, and is the exact build this recipe's header
-- measured against.) Fetched with curl, verified byte-for-byte against
-- both fields, sha256 computed locally on the verified download.
--
-- ═══════════════════════════════════════════════════════════════════════
-- INSTALLED LAYOUT
-- ═══════════════════════════════════════════════════════════════════════
--
--   <install_dir>/emulator            the launcher binary
--   <install_dir>/qemu/linux-x86_64/  qemu-system-{x86_64,i386,aarch64,
--                                     armel}[-headless] -- the launcher
--                                     picks one per AVD's abi.type; arm64
--                                     is present but gated off on this host
--                                     class (see above)
--   <install_dir>/lib64/              bundled libandroid-emu-*, libc++,
--                                     libglib2, libprotobuf, libabseil_dll
package = {
    spec = "2",
    homepage = "https://developer.android.com/studio/run/emulator",

    name = "android-emulator",
    description = "Android Emulator: Google's own prebuilt QEMU2-based engine for booting Android system images",

    maintainers = {"Google", "The Android Open Source Project"},
    licenses = {"Android Software Development Kit License Agreement"},
    repo = "https://android.googlesource.com/platform/external/qemu",
    docs = "https://developer.android.com/studio/run/emulator-command-line",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "android", "emulator"},
    keywords = {"android", "emulator", "avd", "qemu", "kvm"},

    xpm = {
        linux = {
            -- EVERY LIBRARY THIS BINARY NEEDS COMES FROM THE ECOSYSTEM.
            --
            -- `emulator` links libX11 UNCONDITIONALLY: the DT_NEEDED entries
            -- load at exec time regardless of `-no-window`, and the same
            -- binary refuses to start at all without them, headless or not
            -- (verified). So this is a dependency of the package, not a
            -- suggestion to the user.
            --
            -- It was a `hostlib.dirs_of` probe with a `log.warn` pointing at
            -- "the host distribution", on the precedent of pkgs/g/godot.lua.
            -- That precedent is wrong for this index: xlings is a user-space
            -- distribution, so a payload that needs a library declares it and
            -- the ecosystem supplies it. Every link in the chain already
            -- exists here -- libX11, libxcb, libXau, libXdmcp, libbsd, libmd
            -- -- so nothing had to be added to close it, only declared.
            --
            -- The transitive links are named rather than left to libX11's own
            -- deps because a DT_NEEDED chain is not a resolution order: if any
            -- one of them is missing the loader fails at exec with a message
            -- naming that library and not this package.
            deps = {
                "xim:libX11@>=1.8",
                "xim:libxcb@>=1.17",
                "xim:libXau@>=1.0",
                "xim:libXdmcp@>=1.1",
                "xim:libbsd@>=0.12",
                "xim:libmd@>=1.1",
            },
            ["latest"] = { ref = "37.1.11" },
            ["37.1.11"] = {
                -- Measured 2026-09-11: fetched with curl, size and sha1
                -- both matched repository2-3.xml exactly (see header).
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/emulator-linux_x64-15917651.zip",
                    CN     = "https://gitcode.com/xlings-res/android-emulator/releases/download/37.1.11/emulator-linux_x64-15917651.zip",
                },
                sha256 = "95771e0ae431897b2a4bd2d97fa095f29a8b0624a7b216baf529f9306161c266",
            },
        },
        -- macOS AND WINDOWS. `repository2-3.xml` publishes an archive per host
        -- for the SAME pinned revision, and this index serves all three hosts,
        -- so declaring only linux was an incomplete addition rather than a
        -- conclusion. Read out of that manifest on 2026-09-11:
        --
        --   macosx   emulator-darwin_x64-15917651.zip       444 MB
        --            sha1 7df8b0acbe915217dcbb576222bddfcc23e81230
        --   macosx   emulator-darwin_aarch64-15917651.zip   376 MB
        --            sha1 f22f44948a2b7f0a0103645b9a639290eef92426
        --   windows  emulator-windows_x64-15917651.zip      421 MB
        --            sha1 54fa750822ff462d57e04fc8e98e60f08df2bb61
        --
        -- TWO ARCHIVES FOR macOS, so this table needs an `arch_alias` where
        -- the others do not -- Apple silicon gets its own build rather than a
        -- universal one, unlike the NDK.
        --
        -- AND ONE CLAIM THIS DOES NOT MAKE. The header's arm64 gate is
        -- measured on an x86_64 HOST: `QEMU2 emulator does not support arm64
        -- CPU architecture`. An Apple-silicon host runs arm64 guests natively
        -- through HVF and there is every reason to expect the gate is absent
        -- there -- which is exactly why it is not asserted here. Nothing in
        -- this index has run that, and a row claiming it would be a guess
        -- wearing a measurement's clothes.
        macosx = {
            ["latest"] = { ref = "37.1.11" },
            ["37.1.11"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/emulator-darwin_${arch_alias}-15917651.zip",
                    CN     = "https://gitcode.com/xlings-res/android-emulator/releases/download/37.1.11/emulator-darwin_${arch_alias}-15917651.zip",
                },
                arch_alias = { x86_64 = "x64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64  = "c1a3890f95b8868198918fad05ffca16fa20404d93547ba545ff5a5867ee7005",
                    aarch64 = "22530de9363f34ea945ecb5cad74523abd4b615f27f3c1a9899efb183ea9e144",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "37.1.11" },
            ["37.1.11"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/emulator-windows_x64-15917651.zip",
                    CN     = "https://gitcode.com/xlings-res/android-emulator/releases/download/37.1.11/emulator-windows_x64-15917651.zip",
                },
                sha256 = "5ff441f3b12ace9b13e9cf96fb0007d233967718652a8110705e995ac47bfeb7",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- The zip's own top-level directory is literally "emulator" (verified
    -- with `unzip -l` against the actual downloaded archive) -- no
    -- release-name-vs-Pkg.Revision mismatch to work around here.
    if not os.isdir("emulator") then
        raise("android-emulator: expected extracted directory 'emulator' "
              .. "not found beside the downloaded archive")
    end
    os.mv("emulator", dir)

    local emu = path.join(dir, "emulator")
    if not os.isfile(emu) then
        raise("android-emulator: no emulator binary at " .. emu
              .. " -- payload does not look like the linux_x64 emulator build")
    end
    os.exec("chmod 755 \"" .. emu .. "\"")

    -- The one host-arch gate worth asserting at install time rather than
    -- leaving to a confusing first boot: this exact package cannot run an
    -- arm64-v8a AVD on this host, ever, regardless of patience (see the
    -- header). Assert the aarch64 qemu-system binaries are at least
    -- PRESENT (a truncated archive would be a different, install-time
    -- failure), without claiming they are usable here.
    local qemu_dir = path.join(dir, "qemu", "linux-x86_64")
    if not os.isfile(path.join(qemu_dir, "qemu-system-x86_64")) then
        raise("android-emulator: no qemu-system-x86_64 under " .. qemu_dir
              .. " -- this host's own architecture backend is missing, "
              .. "which is a stronger failure than the documented arm64 gate")
    end

    return true
end

function config()
    xvm.add(package.name)
    xvm.add("emulator", { bindir = pkginfo.install_dir() })

    -- Matching pkgs/g/godot.lua's exact precedent for a prebuilt GUI-stack
    -- binary: probe, warn, do not fail the install. The emulator's own
    -- libX11.so.6 dependency is DT_NEEDED, not dlopen'd, so it is required
    -- even for a fully headless `-no-window -no-audio` boot -- said loudly
    -- here because "headless" is exactly the case where a consumer would
    -- otherwise assume no GUI library is needed.

    -- KVM is a runtime concern the emulator itself reports (falling back to
    -- slow software virtualization rather than refusing), not something
    -- install-time can fix by installing a package -- /dev/kvm access is a
    -- host group-membership decision. Said here so a consumer reads it
    -- once rather than discovering it from a slow first boot.
    if not os.isfile("/dev/kvm") then
        log.warn("android-emulator: /dev/kvm not present on this host -- "
                 .. "AVDs will boot under software virtualization, measured "
                 .. "far slower than the ~10s KVM-accelerated boot this "
                 .. "recipe's header records for an x86_64 image")
    end

    return true
end

function uninstall()
    xvm.remove("emulator")
    xvm.remove(package.name)
    return true
end
