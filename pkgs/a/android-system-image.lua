-- Android system image -- Google's own prebuilt AOSP ("default" tag) guest
-- disk images: kernel, ramdisk, system.img, and a userdata.img template.
--
-- WHY THIS IS ITS OWN PACKAGE, SEPARATE FROM android-emulator. The engine
-- (pkgs/a/android-emulator.lua) has one version lineage and is useless on
-- its own; a system image is the OTHER half booting needs, and upstream
-- publishes dozens of (api-level, tag, abi) combinations that update on
-- independent schedules and have nothing to do with engine releases. A
-- consumer who wants to test against API 24 should not be forced to
-- re-fetch a newer API 36 image, or vice versa, and an emulator update
-- should not force re-fetching multi-gigabyte image data that did not
-- change. Splitting them lets each be installed, cached and removed on its
-- own -- this is the reasoning pkgs/a/android-platform-tools.lua's header
-- gives for the three-way split as a whole; this file is the "a consumer
-- picks one" half of it.
--
-- ═══════════════════════════════════════════════════════════════════════
-- ONE PACKAGE, MANY VERSIONS -- NOT ONE PACKAGE PER IMAGE, AND NOT A
-- PER-ARCH RESOURCE TABLE. THE REASONING, SINCE THIS WAS ASKED FOR
-- EXPLICITLY RATHER THAN A LIST.
-- ═══════════════════════════════════════════════════════════════════════
--
-- Three shapes were considered:
--
--   (a) One package per (api, tag, abi) triple
--       (android-system-image-24-default-x86_64, ...-24-default-arm64-v8a,
--       ...). Rejected: upstream's own sys-img2-3.xml lists 22 API levels
--       for `default` alone, each in up to two ABIs -- this index would
--       gain dozens of near-identical files for one conceptual thing, and
--       "a consumer picks one" argues for one place to look, not several
--       dozen.
--
--   (b) One package, ABI folded into a per-arch resource map the way
--       pkgs/l/libX11.lua folds HOST arch into `sha256 = {x86_64=...,
--       aarch64=...}`. Rejected, and for a reason specific to this
--       payload rather than a stylistic preference: that shape means "the
--       same release, built once per HOST architecture" -- interchangeable
--       artifacts of one thing. An x86_64 system image and an arm64-v8a
--       system image are not that: they are different GUEST products
--       (verified directly -- android-emulator.lua's own header measured
--       that the arm64-v8a image cannot even BOOT on the host class this
--       was tested on, which an interchangeable-build model would not
--       predict). Folding them into one hash table would make "install the
--       x86_64 one" inexpressible as its own choice.
--
--   (c) One package, each (api, tag, abi) triple as its own version key
--       ("24-default-x86_64", "24-default-arm64-v8a", ...). Chosen. This
--       matches xim:android-ndk's own precedent of using a version key
--       that is not the vendor's release name when the release name does
--       not carry the information a consumer pins on (there, Pkg.Revision
--       over "r30"; here, the full (api,tag,abi) identity over a bare
--       API number, because the tag and abi are exactly as load-bearing
--       to "which bytes do I get" as the API level is).
--
-- THE COST OF (c), STATED RATHER THAN HIDDEN: these version keys are NOT
-- totally ordered. `>=` as a version constraint (docs/V2/xpackage-spec.md;
-- this index's own "one package, one version" convention) presumes a
-- linear order, and "24-default-x86_64" vs "24-default-arm64-v8a" have
-- none -- API level orders, tag and abi do not. So this package's versions
-- are usable only as EXACT pins (`xim:android-system-image@24-default-
-- x86_64`), never as a range. That is a real limitation of shape (c), and
-- it is still the smaller cost: shape (a) pays it in file count instead,
-- and shape (b) cannot express "pick x86_64" at all. No `latest` key is
-- declared for the same reason `>=` does not work here -- there is no
-- single newest image across two orthogonal axes, and a `latest` alias
-- across them would silently pick one arbitrarily.
--
-- Only the `default` tag (AOSP, no Google Play, no Google APIs) is
-- packaged here -- it is the smallest image at a given API level (verified
-- by parsing sys-img2-3.xml for every tag at api level 24: `default`
-- x86_64 is 419 MB against 500+ MB for `google_apis` at the same level)
-- and needs no separate Play-Services licence question. `google_apis` /
-- `google_atd` tags are a straightforward future version-key extension
-- (e.g. "24-google_apis-x86_64") if a consumer needs Play Services, not a
-- reason to redesign this file.
--
-- ═══════════════════════════════════════════════════════════════════════
-- WHAT WAS MEASURED (2026-09-11)
-- ═══════════════════════════════════════════════════════════════════════
--
-- API level 24 (Android 7.0 "NYC") was chosen as the FIRST version pinned
-- here not for size alone but because it is the FLOOR the artifacts under
-- test actually need: `readelf -n` on the measured hello/hello_std
-- dynamic binaries decodes `.note.android.ident`'s first 4 bytes
-- (`18 00 00 00`, little-endian) to 24 -- these binaries declare
-- minSdkVersion 24, built by NDK r30. A system image below that floor
-- risks a linker-level API mismatch this recipe has no way to test for
-- every artifact that might use it; 24 is the smallest available API level
-- at or above that floor for both ABIs (sys-img2-3.xml offers 21, 22, 23
-- below it, all excluded for this reason rather than for size).
--
-- Both entries below were fetched with curl directly from
-- https://dl.google.com/android/repository/sys-img/android/sys-img2-3.xml
-- (Google's OWN manifest for this exact tag family), verified byte-for-
-- byte against its <size> and <checksum> (sha1) fields, with sha256
-- computed locally on the verified download (the manifest does not
-- publish sha256, matching every other recipe in this index that pins
-- Google SDK artifacts).
--
-- BOOT: the x86_64 entry was booted end to end -- `sys.boot_completed=1`
-- ten seconds after process launch, KVM-accelerated, using an AVD whose
-- `config.ini` and pointer `.ini` were written BY HAND rather than through
-- `avdmanager` (see "avdmanager IS NOT NEEDED" in android-emulator.lua's
-- header; the same finding applies here since it is this package's
-- `userdata.img` that gets copied into the AVD directory). The arm64-v8a
-- entry downloads and extracts identically -- verified -- but does not
-- boot on this x86_64 host: android-emulator.lua's header records the
-- emulator's own unconditional host-arch gate, which is a property of the
-- ENGINE, not of this image. On a genuine arm64 host running a macOS or
-- Linux/aarch64 build of the same emulator (neither available to verify
-- here), this same image is the expected correct input.
--
-- ═══════════════════════════════════════════════════════════════════════
-- WIRING THIS PACKAGE TO A SEPARATELY-INSTALLED android-emulator
-- ═══════════════════════════════════════════════════════════════════════
--
-- Two xim packages get two independent install directories -- there is no
-- merged "SDK root" tree the way a single sdkmanager-managed install
-- produces one. `emulator -help` documents exactly the flag for this
-- (confirmed present in the actual `-help` output while writing this
-- recipe, though a boot using it specifically -- as opposed to the
-- SDK-root-relative `image.sysdir.1` this recipe's own boot measurement
-- used -- was not itself re-run):
--
--   -sysdir <dir>     search for system disk images in <dir>
--
-- A runner wiring these two packages together therefore invokes:
--
--   emulator -avd <name> -sysdir <xpkg_dir of this package>
--            -no-window -no-audio -no-boot-anim -no-snapshot
--            -gpu swiftshader_indirect
--
-- with the AVD's own `config.ini` needing no `image.sysdir.1` line at all
-- in that mode (the flag overrides it). This is the shape "declare the
-- tool where it will be looked up" (mcpp .agents/docs/2026-09-11-
-- distribution-plugins-and-platform-decomposition.md SS6) takes for a
-- runner that consumes two independently-versioned payloads.
--
-- ═══════════════════════════════════════════════════════════════════════
-- A SECOND, INDEPENDENT PATH: qemu-user AGAINST THIS IMAGE'S RAW
-- system.img -- NO EMULATOR, NO BOOT, NO KVM -- MEASURED END TO END
-- (2026-09-11)
-- ═══════════════════════════════════════════════════════════════════════
--
-- android-emulator.lua's header documents that the emulator ENGINE
-- refuses arm64-v8a on an x86_64 host, unconditionally, across all four
-- currently-served builds. That is a property of the engine. This section
-- measures a completely different mechanism reaching the same goal -- the
-- DEFAULT (dynamic) aarch64-linux-android configuration actually
-- executing -- using only this package's own downloaded bytes, a
-- qemu-user binary, and xim:android-ndk. No boot, no AVD, no KVM, no
-- device.
--
-- system.img IS A RAW ext4 IMAGE, NOT ANDROID'S SPARSE CONTAINER FORMAT --
-- MEASURED, NOT ASSUMED. `simg2img` IS NOT NEEDED FOR THIS ARTIFACT.
--
-- The first 32 bytes of the downloaded arm64-v8a system.img are zero,
-- which is not the Android sparse format's own magic (0xED26FF3A, always
-- at offset 0) -- it is the ordinary ext4 boot-sector reserve before the
-- superblock at byte 1024. `debugfs -R "show_super_stats -h" system.img`
-- confirms it directly, no conversion tool involved:
--
--   Filesystem volume name:   system
--   Filesystem magic number:  0xEF53
--   Block size:               4096
--   Block count:              655360   (4096 * 655360 == the exact
--                                        2684354560-byte file size)
--
-- i.e. this file is not compressed, chunked, or sparse in the Android
-- transport sense at all -- it is a complete raw ext4 filesystem, openable
-- by any ext4 tool with zero preprocessing. `simg2img` (from the separate
-- `android-sdk-libsparse-utils` package, NOT installed on the host this
-- was measured on, and NOT bundled by android-emulator.lua's package
-- either -- checked, it ships img2simg but not the reverse tool) was
-- never actually needed, and is not declared as a dependency here. This
-- is a property of THIS artifact, measured directly, not a general claim
-- about every image Google serves -- an image that genuinely ships in the
-- sparse container format would need it, and this recipe would need to
-- grow that step if a future version key turns out to be one.
--
-- THE PARTITION'S OWN ROOT IS WHAT `/system` NEEDS TO BE, DIRECTLY.
--
-- `debugfs -R "ls -l /" system.img` lists `bin/`, `lib64/`, `framework/`,
-- etc. AT THE PARTITION ROOT -- API 24's pre-Treble, non-"system-as-root"
-- layout (that reorganization came later), so this partition's root is
-- byte-for-byte what a device mounts at `/system`. That is exactly what
-- `qemu-aarch64 -L <prefix>` needs: an artifact's PT_INTERP of
-- `/system/bin/linker64` resolves as `<prefix>/system/bin/linker64`, so
-- presenting this partition's root AS `<prefix>/system/` is sufficient --
-- no `/etc/ld.config.txt` linker-namespace file exists in this image
-- either (checked, absent, as expected -- that bionic feature postdates
-- API 24, so its absence is not a gap here).
--
-- FOUR FILES, MEASURED SUFFICIENT -- NOT A FULL PARTITION DUMP.
--
-- The two test artifacts (hello_aarch64-linux-android_{,std_}dynamic, NDK
-- r30) both declare `interpreter /system/bin/linker64` and
-- `NEEDED libc++_shared.so/libm.so/libdl.so/libc.so` (`readelf -d`).
-- One `7zz x` (no mount, no loop device, no root privilege) pulls exactly
-- what those four NEEDED entries plus the interpreter require:
--
--   7zz x system.img -o<root>/system -y \
--     bin/linker64 lib64/libc.so lib64/libdl.so lib64/libm.so
--   chmod +x <root>/system/bin/linker64
--
-- Measured 2026-09-11 with `xim:7zip` 26.02 against this image: `Everything
-- is Ok / Files: 4`, and the in-image directories are preserved, so the
-- extraction writes the `<root>/system/{bin,lib64}` tree qemu-user needs
-- directly rather than composing four destinations. The entry names carry no
-- leading slash -- that is how 7-Zip names ext4 entries, also measured.
--
-- THE TOOL IS `xim:7zip` AND NOT THE OBVIOUS `debugfs`, for a reason
-- recorded below and in pkgs/e/e2fsprogs.lua: the ecosystem's debugfs is a
-- broken static build. The extracted `linker64` is a genuine `ELF ... ARM
-- aarch64 ... static-pie linked`, and `libc.so` a genuine `ELF ... ARM
-- aarch64 ... dynamically linked` -- the real bionic runtime this image
-- ships, not stubs.
--
-- MEASURED, NOT ASSUMED: `libc++_shared.so` IS ABSENT FROM THIS IMAGE.
--
-- `debugfs -R "ls -l /lib64" system.img` lists `libc++.so`, `libc.so`,
-- `libdl.so`, `libm.so`, `libstdc++.so` -- no `libc++_shared.so`. Same gap
-- android-emulator.lua's header measured for the x86_64/device path: this
-- is the NDK's OWN C++ runtime, never part of any system image, arm64 or
-- x86_64. It has to come from xim:android-ndk, and this was checked
-- rather than assumed to be the same answer as the x86_64 case.
--
-- THE WORKING INVOCATION -- BOTH ARTIFACTS, REPEATED RUNS, TWO
-- INDEPENDENT qemu-aarch64 BUILDS.
--
-- AND THE EXTRACTION THAT FEEDS IT WAS BLOCKED FOR ONE RELEASE, which this
-- record keeps because the reason generalises. The four files were extracted
-- with `debugfs`, and `xim:e2fsprogs@1.47.3`'s debugfs is a broken static
-- build -- SIGFPE on every filesystem-opening command, while
-- dumpe2fs/e2fsck/tune2fs from the same payload work (see the KNOWN DEFECT
-- note in pkgs/e/e2fsprogs.lua for the measurements). The runs recorded below
-- were first performed with the HOST's debugfs 1.47.0, which the bare name
-- falls through to from a directory with no xlings project config; that is
-- what made the measurement look reproducible when the ecosystem could not
-- reproduce it.
--
-- THE ROUTE AROUND IT IS A DIFFERENT TOOL, NOT A REPIN. `xim:7zip` reads
-- ext4, is already in this index, and is now the declared dependency; the
-- e2fsprogs defect stays recorded and unowned here, because nothing else in
-- the index depends on that `debugfs` and the repin belongs to that package.
--
-- With `<root>` holding only the four extracted files above (no copy of
-- libc++_shared.so anywhere near it):
--
--   LD_LIBRARY_PATH=<xim:android-ndk installdir>/toolchains/llvm/prebuilt/
--     linux-x86_64/sysroot/usr/lib/aarch64-linux-android \
--   qemu-aarch64 -L <root>  hello_aarch64-linux-android_dynamic
--
--     linker: ...: unsupported flags DT_FLAGS_1=0x8000001
--     WARNING: linker: ...: unsupported flags DT_FLAGS_1=0x8000001
--     linker: .../android-ndk/.../libc++_shared.so: unused DT entry:
--       type 0x70000001 arg 0x0
--     WARNING: linker: ...libc++_shared.so: unused DT entry: type
--       0x70000001 arg 0x0
--     android-exec-ok
--   exit code: 0
--
-- (the four "linker:"/"WARNING:" lines are real bionic runtime log
-- output about ELF dynamic-section flags this old, API-24-era linker64
-- does not recognize -- harmless, non-fatal, do not affect the exit code
-- or the program's own output.) The `import std` artifact the same way:
--
--   1-2-3
--   exit code: 0
--
-- THE LIBRARY WAS NEVER COPIED INTO `<root>` -- MEASURED, THE PART OF
-- THIS RESULT THAT ACTUALLY MATTERS FOR PACKAGING. `LD_LIBRARY_PATH`
-- named xim:android-ndk's OWN, completely unmodified install directory,
-- OUTSIDE `<root>` entirely, and the guest bionic linker (running as
-- qemu-aarch64's translated guest code) resolved it there anyway -- the
-- linker's own log line above names that real host path verbatim. So no
-- file ever needs to be copied or symlinked between this package's
-- install directory and xim:android-ndk's: two independently-versioned,
-- read-only xim packages, joined only by one env var and one flag at run
-- time, with an identical result whether the flag is spelled `-L <root>`
-- or `QEMU_LD_PREFIX=<root>` (both measured). Determinism checked: two
-- repeated runs of the `import std` artifact, plus the whole sequence
-- independently re-run against a FRESH download of xim:qemu-user-
-- aarch64's own pinned binary (sha256 b5dd968d..., matched that package's
-- own pin exactly) instead of the host's apt `qemu-user` -- same output,
-- same exit code, every time.
--
-- THIS IS THE DEFAULT CONFIGURATION, NOT A STATIC-ONLY FINDING. The two
-- artifacts above are the ordinary dynamic NDK build (mcpp's own row
-- model carries `defaultStatic = false` for this target) -- not a static
-- fallback. A static aarch64-linux-android artifact already ran under
-- plain `qemu-aarch64` with no `-L` at all before this investigation
-- (re-verified here as a control: `android-exec-ok`, exit 0) -- that part
-- of the row's tier was never in question. What changes is the DEFAULT
-- one.
--
-- NOTHING NEW NEEDS PACKAGING FOR EITHER MISSING PIECE:
--
--   qemu-aarch64      already xim:qemu-user-aarch64 (pkgs/q/qemu-user-
--                     aarch64.lua), packaged for an unrelated reason
--                     (xlings' own aarch64 CI needing to run its
--                     cross-built output). Re-verified directly against
--                     THIS use case, not assumed to behave the same
--                     because it is "the same program": fresh download,
--                     sha256 matched that package's own pin, -L /
--                     LD_LIBRARY_PATH behavior identical to the host's
--                     apt qemu-user.
--   libc++_shared.so  already xim:android-ndk (pkgs/a/android-ndk.lua).
--   simg2img          NOT needed -- see above, this image is raw ext4.
--
-- THE ONE OPEN DESIGN QUESTION -- INSTALL TIME vs USE TIME EXTRACTION --
-- AND WHY install() BELOW NOW DOES IT AT INSTALL TIME, ARM64-V8A KEYS
-- ONLY.
--
-- Extracting those four files costs opening a 2.5 GB partition and four
-- `debugfs` invocations; done once per install that is a few seconds and
-- a little over 1 MB. Done on every `mcpp run` / `mcpp test` invocation
-- instead, it is a few seconds paid EVERY TIME a runner executes one
-- artifact -- exactly the cost a `runner` contract (spawn one process,
-- read its exit code) should not carry. So install() below extracts once,
-- for arm64-v8a version keys only (never for x86_64 keys -- those are
-- consumed by the actual emulator via `-sysdir`, never by qemu-user,
-- since an x86_64 guest on an x86_64 host needs no user-mode CPU
-- translation at all), into a new subdirectory ADDED TO, not replacing,
-- the existing flat emulator-facing layout (`-sysdir` still needs that
-- flat layout):
--
--   <install_dir>/qemu-user-root/system/bin/linker64
--   <install_dir>/qemu-user-root/system/lib64/{libc,libdl,libm}.so
--
-- A runner declares:
--
--   LD_LIBRARY_PATH=<xim:android-ndk installdir>/toolchains/llvm/prebuilt/
--     linux-x86_64/sysroot/usr/lib/aarch64-linux-android \
--   <xim:qemu-user-aarch64 installdir>/bin/qemu-aarch64-static \
--     -L <this package's installdir for 24-default-arm64-v8a>/qemu-user-root \
--     <artifact>
--
-- three independently-versioned xim packages, zero merged directories,
-- zero files copied between them at run time -- only at this package's
-- own install time, and only from bytes it already owns.
--
-- ═══════════════════════════════════════════════════════════════════════
-- LICENCE AND HOST ARCH SCOPE
-- ═══════════════════════════════════════════════════════════════════════
--
-- MIRRORED FOR CN, under SDK Agreement 3.5 -- see the clause note in
-- pkgs/a/android-platform-tools.lua. These are `default` (AOSP, no Google
-- Play services) images and `NOTICE.txt` carries the open-source notices for
-- their contents, so 3.5 governs and 3.4 does not. The GitCode objects are
-- byte-identical, verified by downloading each back and hashing it.
--
-- `archs = {"x86_64", "aarch64"}`, DELIBERATELY WIDER than the other two
-- Android packages in this index. This is not an inconsistency: a system
-- image's bytes are GUEST content, independent of the HOST machine that
-- downloads and stores them, matching contributing.md SS5.2's rule for a
-- target-independent payload ("载荷与宿主无关 ⇒ 一个 sha256 服务全平台") --
-- the same rule xim:picolibc-riscv already applies. The curl-and-extract
-- install() below has no host-arch branch of any kind. Only fetching was
-- exercised on a Linux/x86_64 host in this task; the aarch64 host case
-- follows from the same argument, not from having been run.
--
-- ═══════════════════════════════════════════════════════════════════════
-- INSTALLED LAYOUT
-- ═══════════════════════════════════════════════════════════════════════
--
--   <install_dir>/system.img, ramdisk.img, kernel-ranchu, kernel-qemu,
--                 userdata.img, build.prop, source.properties,
--                 advancedFeatures.ini, NOTICE.txt
--       upstream's own flat layout (the zip's own top-level directory is
--       already named after the abi -- "x86_64" or "arm64-v8a" -- and is
--       renamed to this package's install directory, unmodified beyond
--       that), matching this package's "no SDK-root nesting invented"
--       stance above.
--   <install_dir>/qemu-user-root/system/bin/linker64
--   <install_dir>/qemu-user-root/system/lib64/{libc,libdl,libm}.so
--       ARM64-V8A VERSION KEYS ONLY. Added to, not replacing, the flat
--       layout above -- see "A SECOND, INDEPENDENT PATH" for why this
--       exists and what it is for (a qemu-user `-L`/`QEMU_LD_PREFIX`
--       target). Not produced for x86_64 keys: nothing consumes it there.
package = {
    spec = "2",
    homepage = "https://developer.android.com/tools/releases/platforms",

    name = "android-system-image",
    description = "Android system image (AOSP \"default\" tag): kernel, ramdisk and system.img for the Android Emulator",

    maintainers = {"Google", "The Android Open Source Project"},
    licenses = {"Android Software Development Kit License Agreement"},
    repo = "https://android.googlesource.com/platform/prebuilts/android-emulator",
    docs = "https://developer.android.com/studio/run/emulator-command-line",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"data", "android", "emulator"},
    keywords = {"android", "system-image", "avd", "aosp"},

    xpm = {
        linux = {
            -- THE EXTRACTION TOOL COMES FROM THE ECOSYSTEM, AND IT IS NOT
            -- THE OBVIOUS ONE.
            --
            -- `system.img` is a raw ext4 filesystem (measured -- see "A
            -- SECOND, INDEPENDENT PATH" above), and reading four files out of
            -- it needs a program that can open ext4. The obvious answer is
            -- `debugfs` from `xim:e2fsprogs`, and that is what this declared;
            -- the measured answer is that the payload's `debugfs` is a broken
            -- static build which SIGFPEs on every filesystem-opening command
            -- while dumpe2fs, e2fsck and tune2fs from the SAME payload work
            -- (pkgs/e/e2fsprogs.lua records the measurements). So declaring it
            -- produced a package that installed and could not serve the one
            -- route the arm64-v8a key exists for.
            --
            -- `xim:7zip` reads ext4. Measured 2026-09-11 against this exact
            -- image:
            --
            --   7zz l system.img            Type = Ext, Label = system
            --   7zz x system.img -o<dir> \
            --     bin/linker64 lib64/libc.so lib64/libdl.so lib64/libm.so
            --                               Everything is Ok / Files: 4
            --
            -- One command instead of four, the in-image paths carry no
            -- leading slash, and the directory layout is preserved -- which is
            -- exactly the `<root>/system/{bin,lib64}` shape qemu-user needs,
            -- so the extraction writes it directly instead of composing it.
            --
            -- THE OTHER PACKAGE'S DEFECT IS NOT FIXED BY THIS, and it is not
            -- worked around either: nothing else in the index depends on that
            -- `debugfs`, so the repin belongs to e2fsprogs and this recipe
            -- simply stops being the only consumer of a program that does not
            -- work.
            --
            -- Declared for every key rather than only the non-x86_64 ones:
            -- `deps` is a property of the descriptor and the arm64-v8a key is
            -- the reason this package can answer for `aarch64-linux-android`
            -- at all. One extra small payload on an x86_64-only install is a
            -- better trade than an extraction step whose availability depends
            -- on the host.
            deps = { "xim:7zip" },
            -- No `latest` key -- see the header: these versions are not
            -- totally ordered, so there is no single unambiguous newest.
            ["24-default-x86_64"] = {
                -- Measured 2026-09-11 against
                -- https://dl.google.com/android/repository/sys-img/android/
                -- sys-img2-3.xml: size and sha1 both matched exactly.
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/sys-img/android/x86_64-24_r08.zip",
                    CN     = "https://gitcode.com/xlings-res/android-system-image/releases/download/24-default-x86_64/x86_64-24_r08.zip",
                },
                sha256 = "c122b69f70a229186314ec9a6f7abedcc7a6ff7ed52cb6fdce0d4f1585c09f92",
            },
            ["24-default-arm64-v8a"] = {
                -- Same manifest, same measurement. Downloads and extracts
                -- correctly (verified); does not BOOT on an x86_64 host --
                -- see android-emulator.lua's header for why that is a
                -- property of the engine, not of this image. The default
                -- (dynamic) configuration DOES run on an x86_64 host
                -- through a different mechanism that does not boot
                -- anything -- see "A SECOND, INDEPENDENT PATH" above,
                -- which is why install() below extracts a qemu-user-root
                -- for this abi.
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/sys-img/android/arm64-v8a-24_r09.zip",
                    CN     = "https://gitcode.com/xlings-res/android-system-image/releases/download/24-default-arm64-v8a/arm64-v8a-24_r09.zip",
                },
                sha256 = "3c3a70dcffe8c162984ec190fc3388bf237b241b3ba80bf7aa5c86e130d8f59b",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

-- The two ABI directory names this recipe's versions currently produce.
-- Checked both because install() does not otherwise know which version
-- string is being installed -- the same "derive it from what actually
-- extracted" approach android-ndk.lua uses for its own release-name
-- mismatch, applied here to abi instead of release name. A future third
-- entry (a different tag, or a new ABI) extends this list, not the logic.
local KNOWN_ABI_DIRS = {"x86_64", "arm64-v8a"}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    local found = nil
    for _, abi in ipairs(KNOWN_ABI_DIRS) do
        if os.isdir(abi) then
            found = abi
            break
        end
    end
    if not found then
        raise("android-system-image: none of the known abi directories ("
              .. table.concat(KNOWN_ABI_DIRS, ", ")
              .. ") were found beside the downloaded archive -- upstream's "
              .. "internal zip layout may have changed")
    end
    os.mv(found, dir)

    local system_img = path.join(dir, "system.img")
    if not os.isfile(system_img) then
        raise("android-system-image: no system.img under " .. dir
              .. " -- payload does not look like an Android system image")
    end
    if not os.isfile(path.join(dir, "userdata.img")) then
        raise("android-system-image: no userdata.img under " .. dir
              .. " -- an AVD built from this image cannot be created "
              .. "without the initial-data template (see android-"
              .. "emulator.lua's \"avdmanager IS NOT NEEDED\" section: this "
              .. "file is what gets copied into a hand-written AVD directory)")
    end

    -- qemu-user needs `/system/bin/linker64` and its three core NEEDED
    -- libraries reachable at a `<root>/system/...` path it can be pointed
    -- at with `-L` / `QEMU_LD_PREFIX` -- see "A SECOND, INDEPENDENT PATH"
    -- above for the full measurement. Only non-x86_64 keys need this: an
    -- x86_64 guest on an x86_64 host needs no user-mode CPU translation,
    -- so only the flat layout above (consumed by the emulator's
    -- `-sysdir`) is ever used for that key. Extracted once, here, rather
    -- than on every runner invocation -- see the header for why.
    if found ~= "x86_64" then
        -- THE EXTRACTOR IS A DECLARED DEPENDENCY, SO ITS ABSENCE IS A BROKEN
        -- INSTALLATION AND NOT A HOST VARIATION TO WARN ABOUT. Refused rather
        -- than skipped: a skip here produces a package that installs
        -- successfully and cannot serve the one route the arm64-v8a key exists
        -- for, and the failure surfaces later as a runner that cannot find
        -- `linker64`.
        --
        -- RESOLVED THROUGH THE DEPENDENCY'S INSTALL DIR, NOT THROUGH PATH,
        -- which is this index's own rule (contributing.md R6) and was broken
        -- here once already: the previous version probed `debugfs -V` on PATH,
        -- and a xim shim is NOT on PATH inside an install hook, so with the
        -- dependency correctly installed the probe still failed.
        --
        -- `xim:7zip` puts its program at the payload ROOT rather than in
        -- `bin/` (pkgs/7/7zip.lua moves `7zz` straight into install_dir), and
        -- both names are accepted so a future layout change is an entry in
        -- this list rather than a broken install.
        local zbin
        local z_dir = pkginfo.dep_install_dir("xim:7zip")
        if z_dir then
            for _, rel in ipairs({"7zz", "7zzs", "7z",
                                  path.join("bin", "7zz"),
                                  path.join("bin", "7z")}) do
                local candidate = path.join(z_dir, rel)
                if os.isfile(candidate) then zbin = candidate break end
            end
        end
        if not zbin then
            raise("android-system-image: no 7-Zip program in the xim:7zip "
                  .. "payload (looked for 7zz, 7zzs and 7z under "
                  .. tostring(z_dir) .. "). It is a declared dependency of "
                  .. "this package, so this is a broken installation rather "
                  .. "than a host variation. The qemu-user route for "
                  .. found .. " cannot be prepared without it.")
        end

        -- THE PROBE HAS TO OPEN THE FILESYSTEM, BECAUSE A VERSION STRING
        -- PASSES ON A BINARY THAT CANNOT.
        --
        -- This is the lesson the debugfs route taught and it is kept for the
        -- new one: `debugfs -V` was the one command that binary answered
        -- without touching the image, and it answered it and then SIGFPEd on
        -- everything else. So the probe here LISTS the image and requires the
        -- answer to name the filesystem type -- a statement that can only come
        -- from having opened it.
        --
        -- `try { os.iorun }` is the idiom this file already uses: os.iorun
        -- raises on a non-zero exit (a signal included), and try turns that
        -- into nil. This hook runtime has been measured to leave `os.arch()`
        -- and `os.files()` unbound, so an unverified API is not the thing to
        -- put in a check.
        local probe = try { function()
            return os.iorun(string.format('"%s" l "%s"', zbin, system_img))
        end }
        if not probe or not tostring(probe):find("Type = Ext", 1, true) then
            raise("android-system-image: the 7-Zip at " .. zbin
                  .. " cannot open " .. system_img .. " as a filesystem "
                  .. "(`l` did not report `Type = Ext`), so the four bionic "
                  .. "files this key needs cannot be extracted.\n"
                  .. "This image IS a raw ext4 filesystem -- measured -- so "
                  .. "the fault is in the extractor or in the download. The "
                  .. "x86_64 key of this package is unaffected: an x86_64 "
                  .. "guest on an x86_64 host needs no user-mode translation "
                  .. "and therefore no extraction.")
        end

        do
            -- ONE COMMAND, AND THE LAYOUT COMES OUT RIGHT BY ITSELF.
            --
            -- qemu-user needs `<root>/system/bin/linker64` and the three core
            -- NEEDED libraries under `<root>/system/lib64/` -- see "A SECOND,
            -- INDEPENDENT PATH" above for the full measurement. 7-Zip
            -- preserves the in-image directories, so extracting the four
            -- paths into `<dir>/qemu-user-root/system` produces that tree
            -- directly; the previous route dumped four files to four composed
            -- destinations, which is four places for the layout to be stated.
            --
            -- Extracted once, here, rather than on every runner invocation --
            -- see the header for why.
            local qroot = path.join(dir, "qemu-user-root", "system")
            os.mkdir(qroot)

            -- No leading slash: that is how 7-Zip names entries in an ext4
            -- image, measured against this image with `7zz l`.
            local WANTED = {
                {"bin/linker64",   path.join(qroot, "bin", "linker64")},
                {"lib64/libc.so",  path.join(qroot, "lib64", "libc.so")},
                {"lib64/libdl.so", path.join(qroot, "lib64", "libdl.so")},
                {"lib64/libm.so",  path.join(qroot, "lib64", "libm.so")},
            }
            local args = ""
            for _, w in ipairs(WANTED) do args = args .. ' "' .. w[1] .. '"' end
            system.exec(string.format('"%s" x "%s" -o"%s" -y%s',
                                      zbin, system_img, qroot, args))

            -- EVERY FILE, NOT THE COMMAND'S EXIT CODE. 7-Zip exits 0 having
            -- extracted nothing when a named entry is absent from the archive
            -- (it reports a warning), so the only honest check is the files.
            for _, w in ipairs(WANTED) do
                if not os.isfile(w[2]) then
                    raise("android-system-image: 7-Zip did not extract "
                          .. w[1] .. " from " .. system_img .. " into "
                          .. w[2] .. " -- upstream's internal partition "
                          .. "layout may have changed")
                end
            end
            system.exec("chmod +x " .. path.join(qroot, "bin", "linker64"))
        end
    end

    return true
end

function config()
    -- Pure data payload -- no executable, so no bare-name shim, matching
    -- contributing.md SS5.2's convention for a target/content payload
    -- ("这类包的 config() 只注册 umbrella 节点"). A consumer reaches it by
    -- absolute xpkg_dir path, via `-sysdir` or a hand-written config.ini
    -- (see the header).
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
