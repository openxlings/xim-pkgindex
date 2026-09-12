-- Cubism SDK for Web -- Live2D's TypeScript runtime (`Framework`) and
-- prebuilt Core JavaScript library (`Core`) for rendering and animating
-- Cubism models in a browser or Node/WebGL context. Added for Lib-Live2D,
-- which today fetches this archive itself through `tools/fetch_cubism.py`;
-- this recipe lets that script (or any other consumer) resolve it through
-- xim instead.
--
-- ══ TIER 2, BY THE SAME LADDER `iphoneos-sdk.lua` AND `cubism-sdk-native.lua`
--    DOCUMENT ═════════════════════════════════════════════════════════════
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
--   GET https://cubism.live2d.com/sdk-web/bin/CubismSdkForWeb-5-r.5.zip
--     -> HTTP/2 200, content-type: application/zip, 20708681 bytes
--
-- FACT TWO: NOTHING GRANTS REDISTRIBUTION OF THE WHOLE ARCHIVE. Exactly as
-- for the Native SDK, the archive carries three licences (see LICENCES
-- below) and the strictest -- Live2D Proprietary Software License, over
-- `Core/` -- does not permit re-hosting the binaries it covers. One region,
-- the upstream URL only, no CN entry.
--
-- ══ THE HASH WAS MEASURED, NOT COPIED ═══════════════════════════════════════
--
-- Lib-Live2D's `tools/fetch_cubism.py` already pins a sha256 for this exact
-- archive. That pin is not trusted here: the archive was downloaded fresh
-- with a plain `curl -L` (no cookies, no credentials) into a scratch
-- directory and hashed independently.
--
--   sha256sum CubismSdkForWeb-5-r.5.zip
--     -> 67064a7fb1812cf502f5c4a03bfe12cc638c75a621bb4acf06bb28763df06ba0
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
--       License." Covers `Core/` -- the prebuilt `live2dcubismcore.js` /
--       `.min.js` and its `.d.ts`.
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
-- No CI mirror or auto-update: `ci = {}`, matching `cubism-sdk-native.lua`
-- and `iphoneos-sdk.lua`. `mirror = true` would republish Live2D's Core
-- binary, which the Proprietary licence does not permit; `update = true`
-- would move `latest` to a version this recipe has not measured a hash or a
-- licence set for.
package = {
    spec = "2",

    name = "cubism-sdk-web",
    description = "Cubism SDK for Web: Live2D's TypeScript runtime (Framework) and prebuilt Core JS library for rendering Cubism models in a browser",

    maintainers = {"Live2D Inc."},
    licenses = {
        "Live2D Proprietary Software License",
        "Live2D Open Software License",
        "Free Material License",
    },
    homepage = "https://www.live2d.com/en/sdk/download/web/",
    docs = "https://docs.live2d.com/en/cubism-sdk-manual/top/",

    -- NO `ci.mirror`, AND THAT IS THE WHOLE POINT OF THIS RECIPE'S SHAPE.
    -- See the header: the Core licence grants no redistribution. `ci.update`
    -- is likewise unset -- a new SDK version needs its licence set and hash
    -- re-measured, not a mechanical bump.
    ci = {},

    type = "package",
    -- Host arches. The payload is JavaScript/TypeScript source and a
    -- prebuilt JS Core library -- text, read identically regardless of
    -- which host extracts it, the same "one archive serves every host"
    -- property `libcxx-headers.lua` and `cubism-sdk-native.lua` both
    -- record -- so one sha256 covers every platform below.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "sdk", "graphics", "web"},
    keywords = {"cubism", "live2d", "sdk", "web", "typescript", "webgl"},

    xpm = {
        -- ONE REGION, NO MIRROR. See the header: a CN entry would make this
        -- index a redistributor of Live2D's proprietary Core library.
        linux = {
            ["latest"] = { ref = "5-r.5" },
            ["5-r.5"] = {
                url = "https://cubism.live2d.com/sdk-web/bin/CubismSdkForWeb-5-r.5.zip",
                sha256 = "67064a7fb1812cf502f5c4a03bfe12cc638c75a621bb4acf06bb28763df06ba0",
            },
        },
        macosx = {
            ["latest"] = { ref = "5-r.5" },
            ["5-r.5"] = {
                url = "https://cubism.live2d.com/sdk-web/bin/CubismSdkForWeb-5-r.5.zip",
                sha256 = "67064a7fb1812cf502f5c4a03bfe12cc638c75a621bb4acf06bb28763df06ba0",
            },
        },
        windows = {
            ["latest"] = { ref = "5-r.5" },
            ["5-r.5"] = {
                url = "https://cubism.live2d.com/sdk-web/bin/CubismSdkForWeb-5-r.5.zip",
                sha256 = "67064a7fb1812cf502f5c4a03bfe12cc638c75a621bb4acf06bb28763df06ba0",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

-- The archive's INTERNAL ROOT, which install() moves away. Spelled out
-- rather than derived from the downloaded file's name, exactly as
-- `cubism-sdk-native.lua`'s SDK_DIR and `iphoneos-sdk.lua`'s are: measured
-- to match the archive's own top-level entry (`unzip -l`), and a bump must
-- re-measure it rather than assume the naming convention held.
local SDK_DIR = "CubismSdkForWeb-5-r.5"

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- THE FRAMEWORK HAS ALREADY EXTRACTED THE ARCHIVE, the same idiom
    -- `cubism-sdk-native.lua` and `iphoneos-sdk.lua` rely on: the archive's
    -- internal root sits in the working directory and install() moves it
    -- into place.
    if not os.isdir(SDK_DIR) then
        raise("cubism-sdk-web: expected the extracted directory '" .. SDK_DIR
              .. "' beside the downloaded archive and found none. Upstream "
              .. "renamed the archive's internal root and this recipe's "
              .. "SDK_DIR is stale.")
    end
    os.mv(SDK_DIR, dir)

    -- THE VERDICT IS TAKEN FROM THE TREE, NOT FROM AN EXIT CODE. Three
    -- checks, one per licensed tree, so a truncated or partially-unpacked
    -- archive is caught here rather than at a consumer's first build.
    local core_js = path.join(dir, "Core/live2dcubismcore.js")
    if not os.isfile(core_js) then
        raise("cubism-sdk-web: no Core/live2dcubismcore.js under " .. dir
              .. "; this is not a usable Cubism Core payload")
    end
    local core_dts = path.join(dir, "Core/live2dcubismcore.d.ts")
    if not os.isfile(core_dts) then
        raise("cubism-sdk-web: no Core/live2dcubismcore.d.ts under " .. dir
              .. "; the Core type declarations are missing")
    end
    local framework_src = path.join(dir, "Framework/src/live2dcubismframework.ts")
    if not os.isfile(framework_src) then
        raise("cubism-sdk-web: no Framework/src/live2dcubismframework.ts under "
              .. dir .. "; the Cubism Framework sources are missing")
    end
    local core_licence = path.join(dir, "Core/LICENSE.md")
    if not os.isfile(core_licence) then
        raise("cubism-sdk-web: no Core/LICENSE.md under " .. dir
              .. "; the Proprietary licence text this package is placed "
              .. "under would be missing from the installed tree")
    end

    log.info("cubism-sdk-web: Core JS at " .. core_js)
    log.info("cubism-sdk-web: Framework sources under "
             .. path.join(dir, "Framework/src"))
    return true
end

-- A BARE REGISTRATION, BECAUSE THIS PACKAGE SHIPS NO PROGRAM.
--
-- This is a prebuilt JS Core library, its type declarations, and a set of
-- TypeScript Framework sources a consumer's own bundler compiles -- not one
-- executable a shim could wrap. `xvm.add(name)` with no `bindir` is what
-- `cubism-sdk-native.lua` and `iphoneos-sdk.lua` do for the same reason: it
-- registers the package's presence and version so a consumer can resolve it
-- by name, and adds nothing to PATH.
function config()
    xvm.add("cubism-sdk-web")
    return true
end

function uninstall()
    return true
end
