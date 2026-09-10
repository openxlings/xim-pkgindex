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
-- LICENCE AND HOST ARCH SCOPE
-- ═══════════════════════════════════════════════════════════════════════
--
-- Same EULA posture as the other two Android packages in this index:
-- fetch dl.google.com directly, no CN mirror, no re-host.
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
            -- No `latest` key -- see the header: these versions are not
            -- totally ordered, so there is no single unambiguous newest.
            ["24-default-x86_64"] = {
                -- Measured 2026-09-11 against
                -- https://dl.google.com/android/repository/sys-img/android/
                -- sys-img2-3.xml: size and sha1 both matched exactly.
                url = "https://dl.google.com/android/repository/sys-img/android/x86_64-24_r08.zip",
                sha256 = "c122b69f70a229186314ec9a6f7abedcc7a6ff7ed52cb6fdce0d4f1585c09f92",
            },
            ["24-default-arm64-v8a"] = {
                -- Same manifest, same measurement. Downloads and extracts
                -- correctly (verified); does not BOOT on an x86_64 host --
                -- see android-emulator.lua's header for why that is a
                -- property of the engine, not of this image.
                url = "https://dl.google.com/android/repository/sys-img/android/arm64-v8a-24_r09.zip",
                sha256 = "3c3a70dcffe8c162984ec190fc3388bf237b241b3ba80bf7aa5c86e130d8f59b",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

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
