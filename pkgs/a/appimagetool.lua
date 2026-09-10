-- appimagetool packages an AppDir (a staged application tree: an AppRun
-- entry point, a .desktop file, an icon) into a single-file AppImage. It
-- is the reference implementation for the write side of the AppImage
-- format, and is what a build plugin invokes as a build-graph action
-- rather than something an end user runs interactively.
--
-- REPOSITORY: this moved. AppImage/AppImageKit's own latest release (tag
-- "13") is an artifact, not a source of truth -- its release body reads:
--   "Obsolete version. DO NOT USE THIS VERSION ANYMORE. Please switch to
--    the new version at https://github.com/AppImage/appimagetool/releases"
-- and every asset in it is prefixed "obsolete-" (e.g.
-- obsolete-appimagetool-x86_64.AppImage). AppImage/appimagetool is the
-- current, actively maintained repository (pushed_at 2025-12-04, 425
-- stars at the time of writing) and is what this recipe tracks. Verified
-- 2026-09-11 with the GitHub Releases API against both repositories.
--
-- VERSION PIN: GitHub's "latest release" for AppImage/appimagetool
-- resolves to the tag "continuous" rather than a dotted version. That
-- tag is not a one-time snapshot -- its own build.yml runs on every push
-- to main and unconditionally re-uploads the four platform assets to
-- the SAME "continuous" release via pyuploadtool, so the URL is stable
-- but the bytes behind it are not, and pinning a sha256 against it would
-- go stale the next time upstream pushes to main. Upstream also cuts an
-- ordinary dotted-version tag ("1.9.1"); measured 2026-09-11, tag
-- "1.9.1" and tag "continuous" build from the identical commit
-- (8c8c91f762b412a19f4e8d2c4b35afb98f2d7c81) and their assets are the
-- same byte sizes (confirmed with a full sha256 download compare on the
-- two archs this recipe ships). "1.9.1" is what actually appears in
-- `appimagetool --version` output too:
--   appimagetool, continuous build (git version 8c8c91f), build 296
--   built on 2025-12-04 17:55:56 UTC
-- so pinning to the dotted tag loses nothing today and gains an
-- immutable release to hash against, matching this index's convention
-- (see qemu-user-aarch64.lua for the same reasoning about a non-dotted
-- upstream tag).
package = {
    spec = "2",

    homepage = "https://appimage.org",
    name = "appimagetool",
    description = "Command-line tool that packages an AppDir into a single-file AppImage",

    maintainers = {"https://github.com/AppImage/appimagetool/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/AppImage/appimagetool",
    docs = "https://docs.appimage.org/",

    -- Mirrored to GitCode as xlings-res/appimagetool@1.9.1, byte-identical to
    -- upstream and verified by downloading both assets back and hashing them
    -- (see the `source` map below). `mirror` keeps that copy in step on a
    -- later bump; `update` is deliberately NOT set -- the auto-updater reads
    -- GitHub "latest release", which for this repository is the
    -- non-dotted, mutable "continuous" tag explained above, and blindly
    -- wiring that in would either propose "continuous" as a version key
    -- (failing this index's dotted-digits convention, see
    -- qemu-user-aarch64.lua) or bump on every upstream push with no
    -- actual code change. A version bump here is a human decision, made
    -- when upstream cuts the next dotted tag.
    ci = { mirror = true },

    type = "package",
    -- Upstream also publishes armhf and i686 AppImages, but this index's
    -- arch vocabulary (see docs/V2/xpackage-spec.md) only names x86_64
    -- and aarch64, so only those two are declared here.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"packaging", "tools"},
    keywords = {"appimage", "appdir", "packaging", "linux", "squashfs", "desktop-integration"},

    -- Linux only: an AppImage is a Linux-native package format (a
    -- self-mounting or self-extracting ELF), and upstream ships no
    -- macOS or Windows build of the tool that writes one.
    programs = {"appimagetool"},
    xvm_enable = true,

    -- Both assets are static-pie ELF executables: `readelf -d` reports
    -- zero DT_NEEDED entries and `readelf -l` shows no PT_INTERP, on
    -- BOTH the x86_64 and the aarch64 asset (checked directly with
    -- readelf on the aarch64 binary; not executed, since this recipe is
    -- authored on an x86_64 host). Nothing crosses the payload boundary
    -- at the ELF level, so -- as with ninja.lua and qemu-user-aarch64.lua
    -- -- there is no glibc/gcc-runtime dependency to declare.
    --
    -- What DOES cross the boundary, and is NOT something `deps` can
    -- express, is FUSE -- and it crosses conditionally, not always.
    --
    -- appimagetool ships as a type-2 AppImage itself: running it plainly
    -- makes its own embedded runtime try to FUSE-mount its payload
    -- before it can do anything, including answer `--version`. Measured
    -- 2026-09-11 on this asset with `fusermount`/`fusermount3` removed
    -- from PATH (a full coreutils PATH otherwise -- this is what a
    -- minimal container image lacking the `fuse`/`libfuse2` package
    -- looks like; /dev/fuse being present or absent did not change the
    -- outcome, since the missing piece is the setuid helper, not the
    -- kernel driver):
    --
    --   $ PATH=<full PATH minus fusermount*> ./appimagetool-x86_64.AppImage --version
    --   Error: No suitable fusermount binary found on the $PATH
    --   Error: $FUSERMOUNT_PROG not set
    --   Cannot mount AppImage, please check your FUSE setup.
    --   You might still be able to extract the contents of this AppImage
    --   if you run it with the --appimage-extract option.
    --   open dir error: No such file or directory
    --   (exit 127)
    --
    -- The fix upstream ships for exactly this is the
    -- `--appimage-extract-and-run` flag, equivalently the
    -- `APPIMAGE_EXTRACT_AND_RUN=1` environment variable: both make the
    -- runtime unpack itself into a scratch directory under $TMPDIR and
    -- exec from there, with no mount and no FUSE involved. With the same
    -- PATH as above:
    --
    --   $ PATH=<same PATH> APPIMAGE_EXTRACT_AND_RUN=1 ./appimagetool-x86_64.AppImage --version
    --   appimagetool, continuous build (git version 8c8c91f), build 296 built on 2025-12-04 17:55:56 UTC
    --   (exit 0)
    --
    -- This was then confirmed end to end, not just for `--version`: with
    -- the same fusermount-less PATH and ARCH=x86_64 set, running
    -- `APPIMAGE_EXTRACT_AND_RUN=1 appimagetool-x86_64.AppImage <AppDir> out.AppImage`
    -- against a hand-made three-file AppDir (AppRun, a .desktop file, a
    -- 1x1 PNG icon) produced a working out.AppImage, which then ran
    -- (again with fusermount absent, again via
    -- APPIMAGE_EXTRACT_AND_RUN=1) and printed the AppRun script's own
    -- output. `mcpp.dist.appimage` MUST invoke this tool with
    -- `--appimage-extract-and-run` (or the environment variable) rather
    -- than plainly, since a CI runner or container is exactly the
    -- environment likeliest to lack `libfuse2`/`fuse3` -- and doing so
    -- costs nothing on a host that DOES have FUSE, since the extract
    -- path is unconditionally supported, not a fallback that only exists
    -- when the mount fails.
    --
    -- SEPARATELY MEASURED: appimagetool bundles its own mksquashfs
    -- (present inside its own payload at usr/bin/mksquashfs, confirmed
    -- with --appimage-extract) and used it successfully even with the
    -- host's mksquashfs ALSO removed from PATH alongside fusermount --
    -- so, unlike fusermount, there is no host mksquashfs dependency
    -- either.
    --
    -- SEPARATELY MEASURED: building an AppImage downloads a second
    -- artifact over the network on every single invocation -- the type-2
    -- "runtime" stub that gets prepended to the output file -- from
    -- https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-<arch>,
    -- unless `--runtime-file <local path>` is given. With that address
    -- unreachable (tested by pointing every proxy environment variable at
    -- a closed port), the plain invocation fails at exactly that step
    -- (`Failed to download runtime: server returned status code 0`) and
    -- produces no output file. A build-graph action cannot depend on
    -- that: it must always pass --runtime-file, which means it needs a
    -- local copy of that stub to point at.
    --
    -- THIS RECIPE SUPPLIES THAT COPY, and does so WITHOUT a second
    -- download or a second pinned asset. appimagetool's own release
    -- AppImage is itself a type-2 AppImage -- runtime stub followed by a
    -- squashfs payload -- and `--appimage-offset` (answered by the outer
    -- stub directly from its own bytes; no FUSE, no mount, no payload
    -- access) reports exactly where the squashfs half begins. On the
    -- 1.9.1 x86_64 asset that offset is 944632, and byte 944632 is
    -- exactly the squashfs 4.0 magic ("hsqs") -- confirmed with
    -- `xxd -s 944632 -l 16`. Carving those leading 944632 bytes out and
    -- using the result as `--runtime-file` for a brand-new AppDir build
    -- -- with fusermount absent from PATH AND every proxy variable
    -- pointed at a closed port -- succeeded outright and the resulting
    -- AppImage ran correctly. `install()` below does exactly this carve,
    -- driven by a freshly measured `--appimage-offset` rather than a
    -- hard-coded byte count, so it keeps working if a future appimagetool
    -- release embeds a differently sized runtime.
    --
    -- The carved bytes are NOT byte-identical to type2-runtime's own
    -- "continuous" download, nor to its one dated release ("20251108") --
    -- both were downloaded and compared; all three are the same size
    -- (944632) but diverge from each other starting at byte 153, inside
    -- the region where appimagetool's own embedding step (the "Embedding
    -- ELF..." / "Embedding MD5 digest" lines a build prints) and
    -- type2-runtime's own release signing each patch a few bytes in
    -- place. This means pinning a sha256 against ANY external
    -- type2-runtime asset -- continuous or dated -- would be pinning
    -- bytes upstream itself does not hold stable release to release, for
    -- no benefit: a working runtime does not require matching them, only
    -- being a valid runtime of the right size and architecture, which the
    -- magic-byte check in install() confirms directly on the artifact
    -- this recipe already downloads and hashes. This is the "prefer a
    -- bundled answer over a second pinned asset" outcome: there is
    -- exactly one download, one sha256, and one upstream release cycle to
    -- track for this whole package.
    xpm = {
        -- TWO REGIONS, ONE CHECKSUM, AND THAT IS THE WHOLE CONTRACT A MIRROR
        -- CARRIES. The version entry pins one sha256 per architecture and
        -- neither region is exempt from it, so a mirror that drifted from
        -- upstream by one byte fails verification rather than installing
        -- something else. The two were confirmed byte-identical by downloading
        -- the GitCode copies back and hashing them, which is the only check
        -- that distinguishes a published asset from a reported upload.
        --
        -- `source` at platform scope rather than a per-version `url`: the
        -- shape is regular, the template covers both arches, and the two
        -- regions differ only in host. Canonical arch names match upstream's
        -- asset names literally (x86_64, aarch64), so no arch_alias is needed
        -- and neither is ${ext} -- an AppImage is not an archive.
        linux = {
            -- INSIDE THE PLATFORM TABLE, MATCHING THE 23 RECIPES THAT
            -- ALREADY CARRY A REGIONAL MAP (see qemu-arm.lua). Both positions
            -- were measured against xlings 2026.9.5.1 and BOTH WORK: with
            -- GLOBAL pointed at a nonexistent host and `--mirror CN` set, the
            -- install downloads from GitCode either way. The platform position
            -- is chosen for consistency with the rest of the index, not
            -- because the root position fails.
            --
            -- THE MEASUREMENT THAT MADE THIS ANSWERABLE IS WORTH RECORDING,
            -- because three earlier attempts measured the wrong object: a
            -- `--add-xpkg` into a fresh `XLINGS_HOME` is discarded when that
            -- home resyncs its indexes ("catalog build failed ... resyncing"),
            -- so the install read the PUBLISHED recipe and reported the
            -- upstream URL -- which looks exactly like a mirror that is not
            -- being consulted. A local recipe is only under test in a home
            -- where `--add-xpkg` persists.
            source = {
                GLOBAL = "https://github.com/AppImage/appimagetool/releases/download/${version}/appimagetool-${arch}.AppImage",
                CN     = "https://gitcode.com/xlings-res/appimagetool/releases/download/${version}/appimagetool-${arch}.AppImage",
            },
            ["latest"] = { ref = "1.9.1" },
            ["1.9.1"] = {
                sha256 = {
                    x86_64  = "ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0",
                    aarch64 = "f0837e7448a0c1e4e650a93bb3e85802546e60654ef287576f46c71c126a9158",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

function install()
    -- The download is the AppImage itself -- a single ELF, no archive to
    -- extract. Rename it to the bare program name so a consumer (this
    -- includes the forthcoming mcpp.dist.appimage action) can find it at
    -- a fixed path regardless of which arch resolved, matching jq.lua's
    -- and bazel.lua's shape for a bare single-binary release.
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    -- Captured before the move: once the source is renamed to the bare
    -- "appimagetool" below, its original name -- the one piece of this
    -- hook that still says which arch was downloaded -- is gone.
    local downloaded = pkginfo.install_file()

    local target = path.join(pkginfo.install_dir(), "appimagetool")
    os.mv(downloaded, target)
    -- `system.exec`, not `os.exec`: the xim Lua sandbox does not expose
    -- the latter (see qemu-user-aarch64.lua for the same substitution).
    system.exec(string.format([[chmod +x "%s"]], target))

    -- Carve the embedded type-2 runtime stub out of the binary we just
    -- installed instead of fetching type2-runtime's own release -- see
    -- the long comment above `xpm` for the measurement this is built on.
    -- `--appimage-offset` is answered by the outer runtime stub reading
    -- its own bytes; it touches neither FUSE nor the network, so it is
    -- safe to call unconditionally here, on every host this hook runs on.
    local offset_out = try { function()
        return os.iorun(string.format([["%s" --appimage-offset]], target))
    end }
    local offset = tonumber((offset_out or ""):match("%d+"))
    if not offset or offset <= 0 then
        raise("appimagetool: '--appimage-offset' did not report a usable "
              .. "byte offset (got: " .. tostring(offset_out) .. "); cannot "
              .. "carve the embedded type-2 runtime")
    end

    -- MEASURED: `os.arch()` is not bound in the C++ xim hook runtime that
    -- executes this install() (confirmed by running it: "attempt to call
    -- a nil value (field 'arch')"), matching node.lua's and jdk-zulu.lua's
    -- own findings ("os.arch is not bound in hooks", "_RUNTIME.arch is
    -- empty for install hooks") -- the spec's own example snippet using
    -- `os.arch()` inside install() does not hold on this engine. The arch
    -- is read back from the downloaded asset's own name instead, exactly
    -- as jdk-zulu.lua does for the token os.arch() cannot supply: the URL
    -- template above resolves `${arch}` into the literal filename
    -- (appimagetool-x86_64.AppImage / appimagetool-aarch64.AppImage), so
    -- the name already says which arch was fetched.
    local arch = downloaded:match("appimagetool%-([%w_]+)%.AppImage$")
    if not arch then
        raise("appimagetool: could not read an arch token back out of the "
              .. "downloaded filename '" .. tostring(downloaded) .. "'")
    end

    -- Named with the arch, per upstream type2-runtime's own convention
    -- (runtime-x86_64, runtime-aarch64) -- a consumer hardcodes this name,
    -- and only ever sees the one file matching the host it installed on.
    local runtime_name = "runtime-" .. arch
    local runtime_dst = path.join(pkginfo.install_dir(), runtime_name)
    system.exec(string.format([[dd if="%s" of="%s" bs=%d count=1 status=none]],
                               target, runtime_dst, offset))
    system.exec(string.format([[chmod +x "%s"]], runtime_dst))

    -- Assert on the artifact, not the intent (docs/V2/xpackage-spec.md,
    -- rule R4): confirm byte `offset` really is a squashfs boundary, so a
    -- future appimagetool release that changes the size of its own
    -- embedded runtime fails this install loudly instead of silently
    -- shipping a `runtime-<arch>` that is not one. The squashfs 4.0
    -- magic is the four bytes "hsqs".
    local magic = try { function()
        return os.iorun(string.format(
            [[dd if="%s" bs=1 skip=%d count=4 status=none]], target, offset))
    end }
    if magic ~= "hsqs" then
        raise("appimagetool: byte " .. offset .. " of the installed binary "
              .. "is not a squashfs boundary (expected magic 'hsqs', got: "
              .. tostring(magic) .. "); " .. runtime_name .. " would not be "
              .. "a valid --runtime-file")
    end

    return true
end

function config()
    xvm.add("appimagetool", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("appimagetool")
    return true
end
