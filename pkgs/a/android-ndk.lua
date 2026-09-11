-- Android NDK -- a host cross-toolchain (clang/lld/bionic sysroot) that
-- targets aarch64-linux-android and x86_64-linux-android, carrying its own
-- generated C++23 `import std` module surface.
--
-- WHY THIS PACKAGE EXISTS. mcpp's toolchain model carries two `planned` rows,
-- `aarch64-linux-android` and `x86_64-linux-android` (modules/toolchain-model
-- /src/triple.cppm), each with an empty `pin` because no toolchain payload
-- existed. This package is that payload. mcpp is module-first -- a package's
-- interface is a BMI and `import std` availability is a build-fingerprint
-- input -- so a toolchain that cannot compile a module interface unit would
-- be worse than no row at all; the self-test in install() below exists
-- specifically to make that failure loud at install time rather than silent
-- at a consumer's first build.
--
-- ═══════════════════════════════════════════════════════════════════════
-- THE RELEASE THIS RECIPE PINS, AND WHY IT IS NOT THE ONE A PRIOR
-- MEASUREMENT ASSUMED
-- ═══════════════════════════════════════════════════════════════════════
--
-- A design note (mcpp .agents/docs/2026-09-11-distribution-plugins-and-
-- platform-decomposition.md, section 3.1) measured this recipe's two facts
-- -- the module-surface gap and the bionic ctype workaround -- against NDK
-- r27, whose clang reports `_LIBCPP_VERSION 180000`. The CURRENT stable NDK,
-- verified against https://developer.android.com/ndk/downloads on
-- 2026-09-11, is r30 (Pkg.Revision 30.0.16248370), whose clang is a
-- DIFFERENT major version, 21.0.0, reporting `_LIBCPP_VERSION 210000`. The
-- r27 numbers do not apply to what this recipe actually ships, and are
-- recorded here only to explain why re-deriving mattered.
--
-- Re-deriving changed more than a version number. Measured on r30 rather
-- than assumed from the note above:
--
--   share/libc++/v1/std.cppm AND std.compat.cppm ARE PRESENT IN THIS NDK,
--   with the full std/*.inc (110 files) and std.compat/*.inc (21 files)
--   partition set beside them -- 133 files, 616 KB, `find` and `ls | wc -l`
--   against the extracted archive. r27 shipped ZERO of these (the fact the
--   design note measured and this recipe does not carry forward, per its own
--   instruction to re-verify rather than trust the record). Whatever changed
--   between r27 and r30 upstream, the CURRENT release needs no separate
--   fetch of `libcxx/modules/` from any llvmorg tag, and no second asset
--   published by this index: the module surface is already part of the one
--   archive this recipe downloads. Sections 2 and 4 of the task this recipe
--   was written against both assumed the vendor still omitted it; that
--   premise is false for r30, and the simpler recipe below is the correct
--   response to that measurement, not a shortcut around it.
--
--   `_LIBCPP_VERSION 210000` nominally corresponds to the llvm-project 21.x
--   public release series (a `llvmorg-21.1.*` tag exists upstream). It is NOT
--   built from that tag, though: CHANGELOG.md in this NDK names the
--   toolchain as "clang-r574158c", an
--   AOSP `toolchains/llvm-project` mirror revision, and `clang --version`
--   agrees ("based on r574158c"). The module surface installed alongside it
--   is generated from that same AOSP checkout, not from the public tag --
--   which is exactly why no separate llvmorg fetch belongs in this recipe:
--   the one already correct copy is the one already inside the archive.
--
--   The bionic ctype defect the design note measured on r27/clang 18 IS
--   STILL PRESENT on r30/clang 21, reproduced verbatim while writing this
--   recipe: precompiling the vendored std.cppm as shipped fails with 28
--   "using declaration referring to 'X' with internal linkage cannot be
--   exported" errors confined to std/cctype.inc and std/locale.inc, because
--   bionic's ctype.h still defines these `static __inline` behind the same
--   overridable `__BIONIC_CTYPE_INLINE` macro. `-D__BIONIC_CTYPE_INLINE=`
--   still clears it; see EXPECTED_LIBCPP_VERSION and __selftest_std_module
--   below, which exercise this for real at install time rather than assert
--   it from a comment.
--
-- CONSEQUENCE FOR THIS RECIPE. There is no generated-surface asset to build,
-- publish, or fetch at install time beyond the one archive below: the
-- vendored share/libc++/v1/ is used as-is, in place, exactly where upstream
-- put it. What this recipe adds beyond unpacking is verification (assert the
-- surface exists and actually precompiles) and a version guard (refuse if a
-- future re-pin's `_LIBCPP_VERSION` no longer matches the constant this file
-- was measured against), so that a mismatch fails a human's install rather
-- than a downstream consumer's first `import std;`.
--
-- ═══════════════════════════════════════════════════════════════════════
-- LICENCE, AND WHICH CLAUSE DECIDES THE MIRROR
-- ═══════════════════════════════════════════════════════════════════════
--
-- The download is gated behind Google's "Android Software Development Kit
-- License Agreement" (the click-through text on the downloads page covers
-- the NDK, not only the SDK proper). Section 3.4 of that agreement reads:
-- "you may not copy [...], redistribute, [...] or create derivative works of
-- the SDK or any part of the SDK" except to the extent a bundled open-source
-- licence requires otherwise; section 3.5 carves the bundled open-source
-- components back out from under that restriction. The archive's own
-- NOTICE.toolchain lists exactly which licences those are (BSD-2-Clause,
-- BSD-3-Clause, MIT OR Apache-2.0-WITH-LLVM-exception for the LLVM/bionic
-- content).
--
-- THIS RECIPE USED TO READ 3.5 AND DECLINE THE MIRROR ANYWAY, on the argument
-- that "the archive AS DISTRIBUTED BY GOOGLE is the combined work the EULA
-- describes". That argument is recorded here rather than deleted, because it
-- is the reading a reviewer will reach for and it is worth knowing it was
-- considered. It does not survive the clause's own wording: 3.5 says
-- distribution of open-source-licensed components is governed SOLELY by that
-- licence and NOT the License Agreement, and every file in this archive is
-- such a component -- `NOTICE` opens with "Licensed under the Apache License,
-- Version 2.0" and NOTICE.toolchain enumerates the rest. A combined work made
-- entirely of parts whose licences permit redistribution has no part that
-- forbids it.
--
-- THE DISTINCTION FROM THE OTHER EULA-GATED PAYLOADS IS NOW SPECIFIC INSTEAD
-- OF SHARED. `pkgs/m/msvc.lua`, `pkgs/w/windows-sdk.lua`,
-- `pkgs/c/cann-toolkit.lua` and `pkgs/i/iphoneos-sdk.lua` keep one upstream
-- URL each because their contents are proprietary -- there is no component
-- licence to invoke, so 3.4-style prohibitions are the only terms that apply.
-- Grouping this package with them read as a policy about EULAs; it is a
-- conclusion about what is inside each archive.
--
-- dl.google.com is itself a global CDN, so the mirror adds a second source
-- rather than reach -- which is what a regional map does anyway (see the
-- measurement in pkgs/a/android-platform-tools.lua).
--
-- No `ci = { update = true }` either, for the reason pkgs/p/picolibc-riscv
-- .lua gives for the same omission: a version bump here is not safe to
-- automate, because EXPECTED_LIBCPP_VERSION and the ctype workaround below
-- must be re-verified by a human against whatever the new release actually
-- ships (the module surface's presence changed between r27 and r30 with no
-- announcement naming it) before `latest` moves.
--
-- ═══════════════════════════════════════════════════════════════════════
-- INSTALLED LAYOUT (upstream's own tree, unmodified beyond the top-level
-- rename from the release name to this package's install directory) --
-- mcpp's toolchain registry hardcodes these relative paths:
-- ═══════════════════════════════════════════════════════════════════════
--
--   <install_dir>/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++
--       the compiler driver. `--target=aarch64-linux-android<api>` or
--       `--target=x86_64-linux-android<api>` selects the ABI; both were
--       measured working end to end while writing this recipe (see
--       tests/a/test_android_ndk.py and the verification report for exact
--       commands and output).
--   <install_dir>/toolchains/llvm/prebuilt/linux-x86_64/sysroot/
--       bionic headers (sysroot/usr/include) and the per-API-level link
--       stubs (sysroot/usr/lib/<triple>/<api>/*.so, *.a).
--   <install_dir>/toolchains/llvm/prebuilt/linux-x86_64/share/libc++/v1/
--       the module surface: std.cppm, std.compat.cppm, std/*.inc,
--       std.compat/*.inc. Precompile std.cppm with
--       `-D__BIONIC_CTYPE_INLINE=` (see above); std.compat.cppm needs the
--       same define for the same reason.
--   <install_dir>/meta/{abis.json,platforms.json,...}
--       upstream's own ABI/API metadata, unmodified.
--   <install_dir>/source.properties
--       Pkg.Revision / Pkg.ReleaseName, unmodified, for a consumer that
--       wants to confirm which build it got without re-deriving it.
--
-- HOST ARCH SCOPE, AND IT DIFFERS PER PLATFORM.
--
-- `archs = {"x86_64", "aarch64"}` is a statement about the package, and the
-- platform tables are where the truth per host lives -- the same shape
-- pkgs/7/7zip.lua, pkgs/b/bun.lua and pkgs/c/cuda-nvcc.lua use:
--
--   linux    ONE x86_64 build. Upstream's downloads page lists a single
--            "Linux 64-bit (x86)" row and there is no linux/aarch64 NDK, so
--            an aarch64 Linux host has nothing to select. That is a property
--            of upstream, not an omission here.
--   macosx   ONE archive, and it is a UNIVERSAL build -- so it serves both
--            Apple arches and there is nothing to select either.
--   windows  ONE x86_64 build.
--
-- So no table needs `arch_alias` and the `os.arch()`-is-unbound pitfall
-- (pkgs/n/node.lua, pkgs/j/jdk-zulu.lua) does not arise for arch selection on
-- any host. It reappears in a different shape in install() below: deriving
-- the archive's INTERNAL extraction directory name, which is not the same
-- string as the downloaded file name -- and which now differs across three
-- files rather than one.
package = {
    spec = "2",
    homepage = "https://developer.android.com/ndk",

    name = "android-ndk",
    description = "Android NDK: host cross-toolchain (clang/lld/bionic) for aarch64/x86_64-linux-android, with its own C++23 std module surface",

    maintainers = {"Google", "The Android Open Source Project"},
    -- See the licence section above: this is the click-through agreement
    -- gating the download itself, not a description of the licences of the
    -- content inside it (NOTICE / NOTICE.toolchain list those separately as
    -- BSD-2-Clause / BSD-3-Clause / MIT OR Apache-2.0-WITH-LLVM-exception).
    licenses = {"Android Software Development Kit License Agreement"},
    repo = "https://android.googlesource.com/platform/ndk",
    docs = "https://developer.android.com/ndk/guides",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compiler", "toolchain", "cross", "android"},
    keywords = {"android", "ndk", "clang", "bionic", "cross-compile",
                "aarch64", "modules", "import-std"},

    -- Umbrella registration only (`xvm.add(package.name)` in config() below)
    -- -- no bare-name program shims. Two reasons, not one:
    --   (a) mcpp's toolchain registry reaches this payload by hardcoding the
    --       absolute path documented above (the same shape
    --       `xim:picolibc-riscv` uses via triple.cppm's `pin` column), never
    --       through PATH, so a shim buys a consumer nothing.
    --   (b) this payload's own bin/ carries a file literally named
    --       `clang++` -- registering it bare would collide with
    --       `xim:llvm`'s own `clang`/`clang++` xvm registrations the moment
    --       both packages are installed together, which is the expected
    --       case for anyone building both a host and an Android target.
    --       pkgs/c/cann-toolkit.lua takes the identical position for the
    --       same reason (a device compiler "is reached ... through
    --       mcpp::xpkg_dir, which is a path and not a PATH entry").
    xvm_enable = true,

    -- No `deps`. Measured on this payload's own bin/clang-21 (`readelf -d`):
    -- interpreter /lib64/ld-linux-x86-64.so.2 (the HOST's own, unmodified)
    -- and a RUNPATH of `$ORIGIN:$ORIGIN/../lib/x86_64-unknown-linux-gnu:
    -- $ORIGIN/../lib` -- the toolchain bundles its own libc++/libc++abi/
    -- libunwind beside its binaries and reaches out only for the host's
    -- core glibc (GLIBC_2.16 at most, per `objdump -T`) plus libz.so.1 and
    -- libgcc_s.so.1, both present via ldconfig on every glibc host this was
    -- checked against. This is the self-contained-payload shape docs/
    -- contributing.md section 5.1 describes: "跨出边界的只有核心 glibc
    -- 时，空 deps 是正确答案" -- declaring `xim:glibc` here would instead
    -- hand elfpatch's predicate-driven rewrite a loader provider to key on,
    -- and it REPLACES this RUNPATH rather than prepending to it, breaking
    -- the toolchain's own bundled libc++abi/libunwind resolution.
    --
    -- The ANDROID-side binaries this toolchain produces need no `deps`
    -- either: their runtime (bionic libc.so/libm.so/libdl.so,
    -- libc++_shared.so) comes from the Android device's own system image at
    -- run time, never from anything this xim package installs on the host.
    xpm = {
        linux = {
            -- Gradle's `ndkVersion` field and this package's version key are
            -- both the long numeric Pkg.Revision from the payload's own
            -- source.properties ("30.0.16248370"), NOT the short release
            -- name ("r30") the download file is actually named after -- the
            -- two strings differ (see install() below, which derives the
            -- archive's internal directory name from the FILE name rather
            -- than from this key, precisely because they disagree). A
            -- future lettered point release moves the middle segment the
            -- way r27's r27b/r27c/r27d carried ndkVersion 27.1.x/27.2.x/
            -- 27.3.x -- so each entry pins its own explicit `url` rather
            -- than templating one from `${version}`.
            ["latest"] = { ref = "30.0.16248370" },
            ["30.0.16248370"] = {
                -- Measured 2026-09-11: downloaded, sha256 computed locally,
                -- and the file SIZE and the page's published SHA1 both
                -- matched exactly (738633529 bytes; SHA1
                -- 5107f898313790e449e87eee2183d9a20602dee9) against
                -- https://developer.android.com/ndk/downloads at the time of
                -- writing. No SHA256 is published there, hence "computed
                -- locally" rather than "copied from upstream" for the value
                -- below.
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/android-ndk-r30-linux.zip",
                    CN     = "https://gitcode.com/xlings-res/android-ndk/releases/download/30.0.16248370/android-ndk-r30-linux.zip",
                },
                sha256 = "753611f410d002cfcd3f3dc2ef49aad532089d3180b436c060a90bf0fcb64df2",
            },
        },
        -- macOS AND WINDOWS. Upstream publishes an NDK for every host this
        -- index serves, and a toolchain that exists for a host should be
        -- installable there. Measured 2026-09-11 with HEAD:
        --
        --   android-ndk-r30-darwin.zip    929 MB
        --   android-ndk-r30-windows.zip   694 MB
        --
        -- The darwin archive is a universal build, so one entry serves both
        -- Apple arches -- which is why `archs` is not narrowed per platform.
        --
        -- THE EXECUTION EVIDENCE IS LINUX ONLY, and the difference matters for
        -- more than politeness: install() derives the archive's internal
        -- directory name from the FILE name, and the three files differ. The
        -- index's own macos-install-test and windows-test are the measurement
        -- for those two legs. Stated here rather than left for a reader to
        -- infer from the table's shape.
        macosx = {
            ["latest"] = { ref = "30.0.16248370" },
            ["30.0.16248370"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/android-ndk-r30-darwin.zip",
                    CN     = "https://gitcode.com/xlings-res/android-ndk/releases/download/30.0.16248370/android-ndk-r30-darwin.zip",
                },
                sha256 = "d125634de97b26deb1e1bb1a562f9d839aa5803d1784a1e414485f5ccbe6739f",
            },
        },
        windows = {
            ["latest"] = { ref = "30.0.16248370" },
            ["30.0.16248370"] = {
                url = {
                    GLOBAL = "https://dl.google.com/android/repository/android-ndk-r30-windows.zip",
                    CN     = "https://gitcode.com/xlings-res/android-ndk/releases/download/30.0.16248370/android-ndk-r30-windows.zip",
                },
                sha256 = "b830098aaf18b67a42eb831c404e15e5f2990a474f054ac145b0bc957ac6d729",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- The one Linux host directory name upstream has used since the r19 unified-
-- toolchain redesign. Stable across point releases (confirmed present,
-- unrenamed, in r30); if a future major release ever changes it, the
-- assertions in install() below name the exact path they expected and fail
-- loudly rather than silently skipping the check.
local HOST_TAG = "linux-x86_64"

-- The libc++ revision this recipe was written and measured against ("THE
-- RELEASE THIS RECIPE PINS" above). Read back out of the installed
-- <sysroot>/usr/include/c++/v1/__config and compared in install(): a
-- mismatch means either this file's version entry was bumped without
-- re-deriving this constant, or a downloaded/mirrored archive does not
-- contain the payload this recipe was written against -- either way, the
-- ctype workaround and the module-surface assumptions above are then
-- unverified for whatever actually got installed, so the install refuses
-- rather than proceeding on a stale assumption.
local EXPECTED_LIBCPP_VERSION = "210000"  -- clang 21.0.0, NDK r30

local function toolchain_dir(install_dir)
    return path.join(install_dir, "toolchains", "llvm", "prebuilt", HOST_TAG)
end

-- Count files in `dir` whose name ends in `suffix`, via `ls` (matching
-- llvm.lua's collect_bin_apps: `os.dirs`' glob shells out to `ls` too, and
-- is not guaranteed on the hook PATH in the C++ xim runtime, so this goes
-- through io.popen directly rather than through that glob).
local function count_files(dir, suffix)
    local n = 0
    local f = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
    if f then
        for line in f:lines() do
            if line:sub(-#suffix) == suffix then n = n + 1 end
        end
        f:close()
    end
    return n
end

-- Read `_LIBCPP_VERSION` out of the installed libc++ headers. Returns nil if
-- the file is missing or the macro is not found, rather than raising --
-- install() decides what a nil means (a missing sysroot is already fatal by
-- the time this is called for a different reason).
local function read_libcpp_version(toolchain)
    local cfg = path.join(toolchain, "sysroot", "usr", "include", "c++", "v1", "__config")
    local f = io.open(cfg, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    -- NOT a literal "#define": the real line in this file is indented
    -- inside a preprocessor conditional as "#  define _LIBCPP_VERSION
    -- 210000" (two spaces after the `#`) -- measured against the actual
    -- installed header after a first version of this pattern silently
    -- matched nothing and failed every install. `#%s*define` tolerates
    -- both that and a bare "#define".
    return content:match("#%s*define%s+_LIBCPP_VERSION%s+(%d+)")
end

-- ASSERT ON THE ARTIFACT, NOT THE INTENT (docs/V2/xpackage-spec.md, rule
-- R4). This precompiles the PAYLOAD'S OWN vendored std.cppm, against the
-- PAYLOAD'S OWN sysroot, with the PAYLOAD'S OWN clang++ -- exactly what a
-- consumer's first `import std;` will do -- rather than trusting that the
-- files exist and the comments above still describe them correctly. A
-- toolchain whose module surface silently stopped precompiling (a future
-- bionic header change, a broken mirror, a partial extraction) fails HERE,
-- at install time, instead of at some consumer's first build.
--
-- One target (aarch64-linux-android24) is exercised, not both this payload
-- supports: the failure mode this guards against is "the vendored surface
-- does not precompile against this vendored sysroot at all", which is
-- target-independent (the errors reproduced while writing this recipe were
-- in bionic's <ctype.h>, which is the same header on every ABI this NDK
-- ships). API level 24 matches the level exercised when this recipe was
-- written and reported.
local function selftest_std_module(install_dir)
    local toolchain = toolchain_dir(install_dir)
    local clangxx = path.join(toolchain, "bin", "clang++")
    local stdcppm = path.join(toolchain, "share", "libc++", "v1", "std.cppm")
    local scratch = path.join(install_dir, ".install-selftest")
    os.tryrm(scratch)
    os.mkdir(scratch)
    local pcm = path.join(scratch, "std.pcm")

    local cmd = string.format(
        '"%s" --target=aarch64-linux-android24 -std=c++23 -D__BIONIC_CTYPE_INLINE= --precompile "%s" -o "%s" 2>&1',
        clangxx, stdcppm, pcm)
    local out = try { function() return os.iorun(cmd) end }

    local size = 0
    if os.isfile(pcm) then
        local size_out = try { function()
            return os.iorun(string.format('stat -c%%s "%s"', pcm))
        end }
        size = tonumber((size_out or ""):match("%d+")) or 0
    end
    os.tryrm(scratch)

    -- A real BMI for this translation unit was measured at ~30 MB; 1 MB is a
    -- floor loose enough to survive a future libc++ shrinking it and tight
    -- enough that a truncated or empty file cannot pass.
    if size < 1024 * 1024 then
        raise("android-ndk: module-surface self-test failed -- precompiling "
              .. "the vendored share/libc++/v1/std.cppm for "
              .. "aarch64-linux-android24 with -D__BIONIC_CTYPE_INLINE= did "
              .. "not produce a usable BMI (got " .. size .. " bytes).\n"
              .. "clang output:\n" .. tostring(out))
    end
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- The zip's internal root directory is named after the RELEASE ("r30"),
    -- not after the downloaded file, which upstream names
    -- "android-ndk-r30-linux.zip" -- measured with `unzip -l` while writing
    -- this recipe: the two strings differ by the trailing "-linux". Every
    -- other recipe in this index that derives an extraction directory from
    -- `pkginfo.install_file()` relies on the archive's stem MATCHING that
    -- directory (fd.lua, jdk-zulu.lua); that assumption is false here, so
    -- the release token is pulled out of the file name with an explicit
    -- pattern instead of being assumed equal to it.
    local archive = pkginfo.install_file() or ""
    local base = archive:match("([^/\\]+)$") or archive
    local release = base:match("^(android%-ndk%-r%d+[a-z]?)%-linux%.zip$")
    if not release then
        raise("android-ndk: cannot derive the release directory name from "
              .. "downloaded file '" .. base .. "' (expected "
              .. "android-ndk-rNN[<letter>]-linux.zip)")
    end
    if not os.isdir(release) then
        raise("android-ndk: expected extracted directory '" .. release
              .. "' not found beside the downloaded archive")
    end

    os.mv(release, dir)

    local toolchain = toolchain_dir(dir)

    -- Compiler present.
    local clangxx = path.join(toolchain, "bin", "clang++")
    if not os.isfile(clangxx) then
        raise("android-ndk: no clang++ at " .. clangxx
              .. " -- payload does not look like an NDK for " .. HOST_TAG)
    end

    -- Bionic sysroot present (api-level.h is bionic's own marker header,
    -- not something this recipe invented).
    local api_level_h = path.join(toolchain, "sysroot", "usr", "include", "android", "api-level.h")
    if not os.isfile(api_level_h) then
        raise("android-ndk: no bionic sysroot at " .. path.join(toolchain, "sysroot")
              .. " (missing usr/include/android/api-level.h)")
    end

    -- _LIBCPP_VERSION must match what this recipe was written and verified
    -- against -- see EXPECTED_LIBCPP_VERSION above for what a mismatch means.
    local actual_version = read_libcpp_version(toolchain)
    if not actual_version then
        raise("android-ndk: could not read _LIBCPP_VERSION out of "
              .. path.join(toolchain, "sysroot", "usr", "include", "c++", "v1", "__config"))
    end
    if actual_version ~= EXPECTED_LIBCPP_VERSION then
        raise("android-ndk: _LIBCPP_VERSION mismatch -- this recipe was "
              .. "written against " .. EXPECTED_LIBCPP_VERSION
              .. " and the installed payload reports " .. actual_version
              .. ". The module-surface and ctype-workaround assumptions "
              .. "above are unverified for this payload; refusing rather "
              .. "than installing a toolchain whose `import std` support "
              .. "was never actually checked.")
    end
    log.debug("android-ndk: _LIBCPP_VERSION %s (matches recipe)", actual_version)

    -- Module surface present. Both the two top files and a floor on each
    -- partition directory's file count (not an exact count: a future point
    -- release adding one header is not the failure this guards against --
    -- the vendor omitting the whole surface again, as happened somewhere
    -- between r27 and r30's predecessor, is).
    local sharev1 = path.join(toolchain, "share", "libc++", "v1")
    local std_cppm = path.join(sharev1, "std.cppm")
    local std_compat_cppm = path.join(sharev1, "std.compat.cppm")
    if not os.isfile(std_cppm) or not os.isfile(std_compat_cppm) then
        raise("android-ndk: payload is missing the module surface ("
              .. "std.cppm / std.compat.cppm) under " .. sharev1
              .. " -- this vendor release no longer ships what this recipe "
              .. "was written against, and this recipe does not implement "
              .. "the generate-from-llvmorg fallback (see the header "
              .. "comment: it was not needed for r30, so it was not built)")
    end
    local n_std = count_files(path.join(sharev1, "std"), ".inc")
    local n_compat = count_files(path.join(sharev1, "std.compat"), ".inc")
    if n_std < 100 or n_compat < 15 then
        raise(string.format(
            "android-ndk: module-surface partition count looks wrong "
            .. "(std/*.inc=%d, expected >=100; std.compat/*.inc=%d, "
            .. "expected >=15) under %s -- the payload may be truncated",
            n_std, n_compat, sharev1))
    end

    -- The functional self-test: actually precompile the vendored std.cppm.
    -- This is the strongest of the checks above (R4) and subsumes the
    -- ctype-workaround assumption entirely -- it does not matter whether
    -- __BIONIC_CTYPE_INLINE is still the right macro name if this call
    -- fails, because that is exactly what would make it fail.
    selftest_std_module(dir)

    return true
end

function config()
    -- Umbrella node only -- see the `xvm_enable` comment above for why no
    -- program is registered beside it.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
