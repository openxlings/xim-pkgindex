-- Cubism SDK for Native -- Live2D's C++ runtime (`Framework`) and prebuilt
-- Core library (`Core`) for rendering and animating Cubism models from a
-- native application. Added for Lib-Live2D, which today fetches this
-- archive itself through `tools/fetch_cubism.py`; this recipe lets that
-- script (or any other consumer) resolve it through xim instead.
--
-- ══ TIER 2, BY THE SAME LADDER `iphoneos-sdk.lua` DOCUMENTS ═════════════════
--
-- The 2026-09-11 record's ladder for a vendor SDK: (1) redistribute if the
-- licence permits, (2) fetch from upstream with no CN mirror, (3) locate
-- what the machine already has. This package is tier 2, for reasons measured
-- below rather than assumed:
--
-- FACT ONE: THE URL IS ANONYMOUS. `cubism.live2d.com` is Live2D's own CDN
-- and gates on nothing -- no cookie, no account, no redirect to a login.
-- Measured 2026-09-13 with a bare `curl -L`, no credentials:
--
--   GET https://cubism.live2d.com/sdk-native/bin/CubismSdkForNative-5-r.5.zip
--     -> HTTP/2 200, content-type: application/zip, 27566034 bytes
--
-- That is what makes tier 2 reachable at all: `iphoneos-sdk.lua`'s own
-- upstream (Apple's) is not anonymous, and that recipe explains why that
-- forecloses tier 1 there. Here the same absence of a login wall is what
-- lets this recipe exist one tier short of hosting a copy.
--
-- FACT TWO: NOTHING GRANTS REDISTRIBUTION OF THE WHOLE ARCHIVE. The archive
-- carries three licences (see LICENCES below), and the strictest of the
-- three -- Live2D Proprietary Software License, over `Core/` -- does not
-- permit re-hosting the binaries it covers. A CN mirror would mean
-- `xlings-res` holds a copy of Live2D's Core library, which is the one thing
-- that licence does not grant. So: one region, the upstream URL only, no CN
-- entry -- exactly `iphoneos-sdk.lua`'s shape and for the same reason.
--
-- ══ THE HASH WAS MEASURED, NOT COPIED ═══════════════════════════════════════
--
-- Lib-Live2D's `tools/fetch_cubism.py` already pins a sha256 for this exact
-- archive. That pin is not trusted here: the archive was downloaded fresh
-- with a plain `curl -L` (no cookies, no credentials) into a scratch
-- directory and hashed independently.
--
--   sha256sum CubismSdkForNative-5-r.5.zip
--     -> 7ff3a4bbc19c0a8728965aa522ab77eb11b252916453e68a8a78d3b71188bb12
--
-- The measured value equals Lib-Live2D's pin. That agreement is corroborating
-- evidence, not the basis for the pin below -- the pin is the value this
-- recipe's own download produced.
--
-- ══ LICENCES: THREE, READ FROM THE ARCHIVE, NOT ASSUMED ═════════════════════
--
-- `licenses` names the licences' own titles, each read from the file that
-- states it, not a paraphrase:
--
--   "Live2D Proprietary Software License"  -- Core/LICENSE.md: "Live2D
--       Cubism Core is available under Live2D Proprietary Software
--       License." Covers `Core/` -- the prebuilt library and its header.
--   "Live2D Open Software License"         -- Framework/LICENSE.md and the
--       root LICENSE.md: "Live2D Cubism Components is available under
--       Live2D Open Software License." Covers `Framework/`.
--   "Free Material License"                -- root LICENSE.md, the section
--       naming the sample models under `Samples/Resources/` (Haru, Hiyori,
--       Mao, Mark, Natori, Ren, Rice, Wanko) individually: "Live2D models
--       listed below are available under Free Material License."
--
-- The root LICENSE.md additionally describes a "Cubism SDK Release License"
-- -- a separate revenue-threshold obligation on commercial use of the SDK as
-- a whole, not a grant covering any one file tree -- and is recorded here
-- rather than folded into `licenses`, which names only the licences a
-- specific tree in the archive is placed under.
--
-- ══ WHAT WAS NOT DONE ════════════════════════════════════════════════════
--
-- No CI mirror or auto-update: `ci = {}`, matching `iphoneos-sdk.lua`.
-- `mirror = true` would republish Live2D's Core binaries, which the
-- Proprietary licence does not permit; `update = true` would move `latest`
-- to a version this recipe has not measured a hash or a licence set for.
package = {
    spec = "2",

    name = "cubism-sdk-native",
    description = "Cubism SDK for Native: Live2D's C++ runtime (Framework) and prebuilt Core library for rendering Cubism models",

    maintainers = {"Live2D Inc."},
    licenses = {
        "Live2D Proprietary Software License",
        "Live2D Open Software License",
        "Free Material License",
    },
    homepage = "https://www.live2d.com/en/sdk/download/native/",
    docs = "https://docs.live2d.com/en/cubism-sdk-manual/top/",

    -- NO `ci.mirror`, AND THAT IS THE WHOLE POINT OF THIS RECIPE'S SHAPE.
    -- See the header: the Core licence grants no redistribution. `ci.update`
    -- is likewise unset -- a new SDK version needs its licence set and hash
    -- re-measured, not a mechanical bump.
    ci = {},

    type = "package",
    -- Host arches. The payload is a source/prebuilt-library tree that reads
    -- identically regardless of which host extracts it -- the same
    -- "one archive serves every host" property `libcxx-headers.lua` and
    -- `iphoneos-sdk.lua` both record -- so one sha256 covers every platform
    -- below rather than a per-arch table.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "sdk", "graphics"},
    keywords = {"cubism", "live2d", "sdk", "native", "cross"},

    xpm = {
        -- ONE REGION, NO MIRROR. See the header: a CN entry would make this
        -- index a redistributor of Live2D's proprietary Core library.
        linux = {
            ["latest"] = { ref = "5-r.5" },
            ["5-r.5"] = {
                url = "https://cubism.live2d.com/sdk-native/bin/CubismSdkForNative-5-r.5.zip",
                sha256 = "7ff3a4bbc19c0a8728965aa522ab77eb11b252916453e68a8a78d3b71188bb12",
            },
        },
        macosx = {
            ["latest"] = { ref = "5-r.5" },
            ["5-r.5"] = {
                url = "https://cubism.live2d.com/sdk-native/bin/CubismSdkForNative-5-r.5.zip",
                sha256 = "7ff3a4bbc19c0a8728965aa522ab77eb11b252916453e68a8a78d3b71188bb12",
            },
        },
        windows = {
            ["latest"] = { ref = "5-r.5" },
            ["5-r.5"] = {
                url = "https://cubism.live2d.com/sdk-native/bin/CubismSdkForNative-5-r.5.zip",
                sha256 = "7ff3a4bbc19c0a8728965aa522ab77eb11b252916453e68a8a78d3b71188bb12",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

-- The archive's INTERNAL ROOT, which install() moves away. Spelled out
-- rather than derived from the downloaded file's name, exactly as
-- `iphoneos-sdk.lua`'s SDK_DIR is: measured to match the archive's own
-- top-level entry (`unzip -l`), and a bump must re-measure it rather than
-- assume the naming convention held.
local SDK_DIR = "CubismSdkForNative-5-r.5"

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- THE FRAMEWORK HAS ALREADY EXTRACTED THE ARCHIVE, the same idiom
    -- `iphoneos-sdk.lua`, `llvm.lua` and `android-ndk.lua` rely on: the
    -- archive's internal root sits in the working directory and install()
    -- moves it into place.
    if not os.isdir(SDK_DIR) then
        raise("cubism-sdk-native: expected the extracted directory '" .. SDK_DIR
              .. "' beside the downloaded archive and found none. Upstream "
              .. "renamed the archive's internal root and this recipe's "
              .. "SDK_DIR is stale.")
    end
    os.mv(SDK_DIR, dir)

    -- THE VERDICT IS TAKEN FROM THE TREE, NOT FROM AN EXIT CODE. Three
    -- checks, one per licensed tree, so a truncated or partially-unpacked
    -- archive is caught here rather than at a consumer's first build.
    local core_header = path.join(dir, "Core/include/Live2DCubismCore.h")
    if not os.isfile(core_header) then
        raise("cubism-sdk-native: no Core/include/Live2DCubismCore.h under "
              .. dir .. "; this is not a usable Cubism Core payload")
    end
    local framework_src = path.join(dir, "Framework/src/CubismFramework.hpp")
    if not os.isfile(framework_src) then
        raise("cubism-sdk-native: no Framework/src/CubismFramework.hpp under "
              .. dir .. "; the Cubism Framework sources are missing")
    end
    local core_licence = path.join(dir, "Core/LICENSE.md")
    if not os.isfile(core_licence) then
        raise("cubism-sdk-native: no Core/LICENSE.md under " .. dir
              .. "; the Proprietary licence text this package is placed "
              .. "under would be missing from the installed tree")
    end

    log.info("cubism-sdk-native: -I " .. path.join(dir, "Core/include"))
    log.info("cubism-sdk-native: Framework sources under "
             .. path.join(dir, "Framework/src"))
    log.info("cubism-sdk-native: prebuilt Core libraries under "
             .. path.join(dir, "Core/lib") .. " and "
             .. path.join(dir, "Core/dll"))
    return true
end

-- A BARE REGISTRATION, BECAUSE THIS PACKAGE SHIPS NO PROGRAM.
--
-- This is a header, a set of Framework sources to be compiled into a
-- consumer's own target, and a prebuilt Core library selected by the
-- consumer's own target platform -- not one executable a shim could wrap.
-- `xvm.add(name)` with no `bindir` is what `iphoneos-sdk.lua` and
-- `linux-headers.lua` do for the same reason: it registers the package's
-- presence and version so a consumer can resolve it by name, and adds
-- nothing to PATH.
function config()
    xvm.add("cubism-sdk-native")
    return true
end

function uninstall()
    return true
end
