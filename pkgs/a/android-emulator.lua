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
-- android execution is NOT reachable through this package on an x86_64
-- host at any time budget -- it needs an aarch64 HOST (a Linux/aarch64 CI
-- runner, or Apple Silicon under a macOS build of this same emulator,
-- neither available to verify here). Static aarch64-linux-android already
-- runs under plain `qemu-aarch64` (a separate, already-`verified` path);
-- this package does not change that row's tier on an x86_64 CI runner.
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
--   ALSO crosses it   libX11.so.6, and transitively libxcb.so.1,
--                     libXau.so.6, libXdmcp.so.6, libbsd.so.0, libmd.so.0
--
-- The libX11 chain is the one host requirement beyond KVM, and it is
-- unconditional: DT_NEEDED entries load at exec time regardless of
-- `-no-window` -- verified, the same binary refuses to start at all
-- without it, headless or not. This is not declared as a hard `deps`
-- entry. pkgs/g/godot.lua establishes the exact precedent for a prebuilt
-- GUI-stack binary in this index: probe with `hostlib.dirs_of` and
-- `log.warn` if absent, rather than forcing every consumer through an
-- xim-managed X11 stack a desktop or CI-with-Xvfb host already has. `xim:
-- libX11` exists in this index (pkgs/l/libX11.lua) for a host that
-- genuinely has none; this package points there rather than depending on
-- it, for the same reason godot.lua does.
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
-- Same EULA posture as pkgs/a/android-ndk.lua and pkgs/a/android-platform-
-- tools.lua: fetch dl.google.com directly, no CN mirror, no re-host.
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
    archs = {"x86_64"},
    status = "stable",
    categories = {"tool", "android", "emulator"},
    keywords = {"android", "emulator", "avd", "qemu", "kvm"},

    xpm = {
        linux = {
            ["latest"] = { ref = "37.1.11" },
            ["37.1.11"] = {
                -- Measured 2026-09-11: fetched with curl, size and sha1
                -- both matched repository2-3.xml exactly (see header).
                url = "https://dl.google.com/android/repository/emulator-linux_x64-15917651.zip",
                sha256 = "95771e0ae431897b2a4bd2d97fa095f29a8b0624a7b216baf529f9306161c266",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.hostlib")

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
    if #hostlib.dirs_of("libX11.so.6") == 0 then
        log.warn("android-emulator: no 64-bit libX11.so.6 on this host -- "
                 .. "the emulator binary will not start at all, even with "
                 .. "-no-window, because libX11 is an unconditional link-time "
                 .. "dependency rather than a conditional one. Install it "
                 .. "from the host distribution, or `xlings install libX11`.")
    end

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
