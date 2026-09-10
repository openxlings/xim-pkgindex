-- iPhoneOS SDK -- the headers, framework stubs and link stubs an iOS build
-- compiles and links against. Added because mcpp carries the target row
-- `aarch64-ios`, and a target row without a sysroot resolves and builds
-- nothing.
--
-- ══ WHY THIS RECIPE HOSTS NOTHING, AND WHY THAT IS NOT THE SAME DECISION
--    `windows-sdk.lua` MADE ═════════════════════════════════════════════════
--
-- `windows-sdk.lua` is the closest neighbour -- a proprietary vendor SDK,
-- `licenses = {"Proprietary"}` -- and it DOES re-host its payloads on
-- `gitcode.com/xlings-res/windows-sdk`, with Microsoft's own address as a
-- second entry in each `urls` list. This recipe deliberately does neither of
-- those things, and the difference is two measured facts rather than a
-- preference.
--
-- FACT ONE: THERE IS NO ANONYMOUS OFFICIAL ADDRESS. Microsoft's
-- `download.visualstudio.microsoft.com` serves its MSIs to anyone, which is
-- what lets `windows-sdk.lua` name it as a fallback. Every Apple route
-- redirects to a login. Measured 2026-09-11:
--
--   HEAD https://download.developer.apple.com/Developer_Tools/Xcode_16/Xcode_16.xip
--     -> HTTP/2 302, location: https://developer.apple.com/unauthorized/
--   HEAD https://developer.apple.com/services-account/download?path=...
--     -> 403
--   HEAD https://developer.apple.com/download/all/
--     -> 403
--
-- So "point at the official URL instead" is not an option that exists. Apple
-- ships this SDK inside Xcode and inside the Command Line Tools, both behind
-- an Apple ID.
--
-- FACT TWO: NOTHING GRANTS REDISTRIBUTION. The SDK is Apple's, under the Xcode
-- licence agreement, which does not permit redistributing it. The mirror this
-- recipe names carries no licence at all -- measured: `LICENSE`, `LICENSE.md`,
-- `LICENSE.txt` and `COPYING` are all 404 in that repository, and its README is
-- one line. It therefore grants nothing either.
--
-- THE CONSEQUENCE IS THE `url` SHAPE. A `CN` entry would mean `xlings-res`
-- holds a copy of Apple's SDK, and holding a copy is what redistribution IS.
-- Naming a third party's address is not: it is an address. So this recipe has
-- exactly one region and no mirror, which is the middle of the three tiers a
-- vendor SDK can occupy:
--
--   1. redistribute            -- a published payload with a CN mirror, as
--                                 every ordinary toolchain package here does.
--                                 CLOSED for this SDK: nothing grants it.
--   2. fetch, mirror nothing   -- THIS RECIPE. Declining the mirror is the
--                                 point rather than an omission.
--   3. locate what is present  -- install nothing; find and pin the Xcode the
--                                 machine already has. Correct under any
--                                 licence, and it belongs on the mcpp side
--                                 rather than here (see below).
--
-- TIER 3 IS THE PREFERRED ROUTE ON A MAC AND IS NOT THIS PACKAGE. A macOS host
-- with Xcode installed already has this SDK, so nothing should be downloaded
-- and the licence question does not arise. That is mcpp's `msvc@system` shape
-- and mcpp resolves it itself. This package serves the case that shape cannot:
-- a host with no Xcode, which in practice means CROSS-COMPILING iOS FROM LINUX
-- -- measured to work, see below.
--
-- ══ THE DURABILITY RISK, STATED RATHER THAN DISCOVERED ══════════════════════
--
-- A public mirror of a vendor SDK is a takedown candidate. GitHub release
-- assets are immutable while the repository exists, so the sha256 below is
-- stable -- but the repository may disappear, and if it does this recipe stops
-- working and no mirror of ours will save it, by construction. That is the
-- price of tier 2 and it is the right price: the alternative is holding a copy
-- we have no right to hold.
--
-- The mcpp row this serves is therefore `preview` at best, never `verified`,
-- for a second reason as well: an iOS artifact cannot be executed by any CI
-- runner this ecosystem has.
--
-- ══ WHAT WAS MEASURED, 2026-09-11 ══════════════════════════════════════════
--
-- Against `iPhoneOS26.5.sdk` and `xim:llvm@22.1.8`, on an x86_64 Linux host:
--
--   _LIBCPP_VERSION          210106   -- a PUBLIC revision: llvmorg-21.1.6
--   _LIBCPP_ABI_NAMESPACE    __1      -- upstream's own default, not a
--                                       vendor-private namespace like the
--                                       NDK's __ndk1
--   _LIBCPP_HAS_NO_STD_MODULES        -- `/* #undef */`: Apple does NOT
--                                       disable std modules
--   share/libc++/v1/std.cppm 0 files  -- the generated module surface is
--                                       ABSENT, as it is in the NDK and in
--                                       Emscripten
--
-- That combination is the good case: the surface is missing but DERIVABLE,
-- because the version is public. Taking `libcxx/modules/` from llvmorg-21.1.6
-- and performing the `@LIBCXX_MODULE_STD_INCLUDE_SOURCES@` substitution yields
-- 133 files and 620 KB -- the same count and size the other two toolchains
-- need and the same the vendor ships where it ships one at all. Carried to a
-- linked artifact:
--
--   clang++ --no-default-config --target=arm64-apple-ios18.0 -isysroot <sdk> \
--     -nostdinc++ -isystem <sdk>/usr/include/c++/v1 -std=c++23 \
--     --precompile surface/std.cppm -o std.pcm          # 34 MB BMI
--   clang++ ... -fmodule-file=std=std.pcm -c app.cpp    # import std;  OK
--   clang++ ... -fuse-ld=lld app.o std.pcm -lc++ -o app
--   file app -> Mach-O 64-bit arm64 executable, flags:<...|PIE>
--
-- NOT EXECUTED -- no device and no simulator on this host -- so this is
-- "compiles and links".
--
-- `--no-default-config` IS LOAD-BEARING AND THE REASON REACHES PAST iOS.
-- `xim:llvm` ships a `bin/clang++.cfg` that injects the host's glibc and
-- libc++ unconditionally, for every target the driver is pointed at:
--
--   -isystem <xim:llvm>/include/c++/v1
--   -isystem <xim:glibc>/include
--   -Wl,--dynamic-linker=<xim:glibc>/lib64/ld-linux-x86-64.so.2
--
-- `-nostdinc++` does NOT displace them: measured with both `-isysroot` and
-- `-nostdinc++` given, the include search list still began with the host's
-- `include/c++/v1` and the compile died inside the host's `stdint.h` on
-- `gnu/stubs-32.h`. The criterion is `clang -v`'s search list and not whether
-- the compile succeeds, because a compile that silently reads the wrong
-- standard library usually succeeds.
--
-- THE MODULE SURFACE IS NOT INSTALLED BY THIS RECIPE. It is a function of the
-- libc++ revision rather than of the SDK, three toolchains need the same
-- machinery, and generating it needs a 240 MB llvm-project tarball at install
-- time. It belongs beside the other two rather than duplicated here; until
-- that lands, a consumer supplies it with `-isystem`.
package = {
    spec = "2",

    name = "iphoneos-sdk",
    description = "iPhoneOS SDK: headers, framework stubs and link stubs for an iOS target",

    -- Apple's, and the mirror grants nothing. `Proprietary` is what
    -- `windows-sdk.lua` records for the same kind of thing; unlike that one,
    -- this recipe re-hosts nothing.
    maintainers = {"Apple"},
    licenses = {"Proprietary"},
    homepage = "https://developer.apple.com/xcode/",
    repo = "https://github.com/xybp888/iOS-SDKs",
    docs = "https://developer.apple.com/documentation/",

    -- NO `ci.mirror`, AND THAT IS THE WHOLE POINT OF THIS RECIPE'S SHAPE.
    -- Setting it would republish Apple's SDK under `xlings-res`, which is the
    -- one thing the licence does not allow. `ci.update` is likewise unset: a
    -- new SDK carries a new libc++ revision, and the surface pairing above has
    -- to be re-measured rather than bumped.
    ci = { },

    type = "package",
    -- The device SDK. The simulator is a different SDK producing a different
    -- object and would be a different package, exactly as it is a different
    -- mcpp target row.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"toolchain", "sdk", "ios", "apple"},
    keywords = {"ios", "iphoneos", "sdk", "apple", "sysroot", "cross"},

    xpm = {
        -- BOTH HOSTS, AND LINUX IS NOT A CURIOSITY. clang and lld cross-target
        -- `arm64-apple-ios` with `-isysroot`, measured above, so a Linux host
        -- is a first-class consumer of this package. A macOS host that has
        -- Xcode should reach tier 3 instead and install nothing.
        linux = {
            ["latest"] = { ref = "26.5" },
            ["26.5"] = {
                -- ONE REGION, NO MIRROR. See the header: a `CN` entry would
                -- make this index a redistributor of Apple's SDK.
                url = "https://github.com/xybp888/iOS-SDKs/releases/download/iOS26.5-SDKs/iPhoneOS26.5.sdk.zip",
                sha256 = "bed0f155d84e98ad8273b3bd57a0816ae5e772e1aa8539e6d79476221ce33173",
            },
        },
        macosx = {
            ["latest"] = { ref = "26.5" },
            ["26.5"] = {
                url = "https://github.com/xybp888/iOS-SDKs/releases/download/iOS26.5-SDKs/iPhoneOS26.5.sdk.zip",
                sha256 = "bed0f155d84e98ad8273b3bd57a0816ae5e772e1aa8539e6d79476221ce33173",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

-- The archive's INTERNAL ROOT, which install() moves away. It is not the path
-- a consumer names -- `install_dir()` itself is the sysroot, so `-isysroot
-- <pkgdir>` carries no version and survives a bump. Spelled out rather than
-- derived from the archive's file name: the two differ here, exactly as they
-- do for `android-ndk`, and assuming they match is what that recipe records
-- as a false assumption other recipes in this index rely on.
local SDK_DIR = "iPhoneOS26.5.sdk"

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- THE FRAMEWORK HAS ALREADY EXTRACTED THE ARCHIVE, and the first revision
    -- of this hook did not know that: it ran `unzip` on
    -- `pkginfo.install_file()` and reported "unpacking failed" on both hosts.
    -- The extraction had in fact succeeded -- CI's post-test dump listed the
    -- complete `iPhoneOS26.5.sdk/{Developer,usr,System,SDKSettings.plist,...}`
    -- tree -- so the hook was refusing an install that had worked. `llvm.lua`,
    -- `llvm-tools.lua` and `android-ndk.lua` all use the idiom below: the
    -- archive's internal root sits in the working directory and install()
    -- moves it into place.
    --
    -- It also removes a dependency on the host's `unzip`, which a recipe that
    -- fetches and checksums a pinned payload should not be leaving to the
    -- machine -- the same argument `windows-sdk.lua` makes when it declares
    -- `xim:curl` rather than trusting the host to have one.
    if not os.isdir(SDK_DIR) then
        raise("iphoneos-sdk: expected the extracted directory '" .. SDK_DIR
              .. "' beside the downloaded archive and found none. Upstream "
              .. "renamed the archive's internal root and this recipe's "
              .. "SDK_DIR is stale.")
    end

    -- `install_dir()` IS THE SYSROOT, rather than holding a `<version>.sdk`
    -- directory inside it. A consumer hardcodes `-isysroot <pkgdir>` and an
    -- SDK bump then changes nothing on its side; the alternative puts the
    -- version in the path every consumer spells.
    os.mv(SDK_DIR, dir)

    -- The archive was made on a Mac and carries an AppleDouble sidecar for
    -- nearly every entry -- 24946 entries in total, roughly half of them `._`
    -- resource forks that no compiler reads. The framework's extraction has no
    -- exclusion list, so they are dropped here instead.
    os.tryrm(path.join(dir, "__MACOSX"))

    -- THE VERDICT IS TAKEN FROM THE TREE, NOT FROM AN EXIT CODE. That is what
    -- the first revision got wrong in the other direction as well: an
    -- extraction can warn and succeed, or succeed and be truncated, and only
    -- the result distinguishes them. These two checks are what say this is a
    -- usable C++ sysroot rather than merely a directory.
    local config = path.join(dir, "usr/include/c++/v1/__config")
    if not os.isfile(config) then
        raise("iphoneos-sdk: no libc++ headers at usr/include/c++/v1 under "
              .. dir .. "; this is not a usable C++ sysroot")
    end
    if not os.isdir(path.join(dir, "System/Library/Frameworks")) then
        raise("iphoneos-sdk: no System/Library/Frameworks under " .. dir
              .. "; an iOS link needs the framework stubs")
    end

    -- The value the module surface must be paired against, read from the SDK
    -- rather than written here so it cannot drift. Measured 26.5: `210106`, a
    -- PUBLIC revision -- llvmorg-21.1.6 exists -- which is what makes the
    -- absent surface derivable rather than a dead end.
    local version = try { function()
        return os.iorun(string.format([[grep -m1 "define _LIBCPP_VERSION" "%s"]], config))
    end }
    if version then
        log.info("iphoneos-sdk: " .. version:trim())
    end
    log.info("iphoneos-sdk: the generated std module surface is ABSENT from "
             .. "this SDK; derive it from the matching llvmorg tag")
    log.info("iphoneos-sdk: -isysroot " .. dir)
    return true
end

-- A BARE REGISTRATION, BECAUSE THIS PACKAGE SHIPS NO EXECUTABLE.
--
-- An SDK is a sysroot: headers, framework stubs and link stubs, and not one
-- program a shim could wrap. `xvm.add(name)` with no `bindir` is what
-- `linux-headers` and `glibc` do for the same reason -- it registers the
-- package's presence and version so a consumer can resolve it by name, and
-- adds nothing to `PATH`.
--
-- The hook is required rather than optional: spec D1/D3 refuses an ordinary
-- package that defines no `config()`, and a package that registers nothing is
-- a package `xvm` cannot report on. The first revision of this recipe omitted
-- it and `test_spec_d1_package_name_registered[iphoneos-sdk]` was the one
-- failure in an otherwise green whole-index run.
function config()
    xvm.add("iphoneos-sdk")
    return true
end

function uninstall()
    return true
end
