-- vcpkg 2026.7.27 -- the tool binary plus the vcpkg-tool standalone bundle
-- (scripts/, triplets/, .vcpkg-root, vcpkg-bundle.json), packaged so the
-- extracted directory IS a working VCPKG_ROOT on its own.
--
-- WHY THE BUNDLE IS INCLUDED, NOT JUST THE BINARY. A bare `vcpkg`/`vcpkg.exe`
-- has nowhere to resolve `builtin-baseline` manifests from: that needs
-- `.vcpkg-root` (the sentinel the binary walks upward for) and the
-- `scripts/`/`triplets/` tree the binary reads relative to it. Upstream ships
-- these two things as SEPARATE release assets (the per-platform tool binary,
-- and vcpkg-tool's own `vcpkg-standalone-bundle.tar.gz`, both from the same
-- vcpkg-tool GitHub release) -- xlings-res/vcpkg republishes them already
-- unpacked and merged into one directory per platform/arch, so this recipe
-- has one download instead of two and one install() instead of a merge step.
-- MEASURED: with `vcpkg-bundle.json` carrying `"usegitregistry": true`, a
-- manifest install resolves `builtin-baseline` through vcpkg's own git
-- registry cache -- no separate `.git` checkout of the vcpkg repo needed.
--
-- Upstream provenance (sha256 PREFIX of the microsoft/vcpkg-tool 2026-07-27
-- GitHub release assets that were unpacked to build the xlings-res archives
-- below -- recorded, as a partial fingerprint, so a future re-mirror can be
-- eyeballed against the same origin; these are NOT the full digests and must
-- not be treated as verification checksums -- the sha256 fields in `xpm`
-- below are the ones that gate the install):
--   vcpkg.exe (windows x86_64)        13b8175e...
--   vcpkg-arm64.exe (windows aarch64) 5e8d7acd...
--   vcpkg-glibc (linux x86_64)        7e97ef6b...
--   vcpkg-glibc-arm64 (linux aarch64) d7a07b1d...
--   vcpkg-macos (macosx universal)    352a5215...
--   vcpkg-standalone-bundle.tar.gz    55c0af29...
-- (Every asset above is the SAME upstream vcpkg-tool release regardless of
-- OS/arch, so the bundle half is shared -- only the binary half differs.)
--
-- Linux ships the GLIBC build. Upstream's release also carries a musl build
-- of the tool, but it is NOT what xlings-res/vcpkg publishes here -- this
-- package assumes a glibc host and does not attempt musl compatibility.
package = {
    spec = "2",

    name = "vcpkg",
    description = "Microsoft's C/C++ package manager -- carries the vcpkg tool and its matching scripts/triplets, so the install directory is a ready-made VCPKG_ROOT",

    maintainers = {"Microsoft"},
    licenses = {"MIT"},
    repo = "https://github.com/microsoft/vcpkg",
    docs = "https://learn.microsoft.com/vcpkg",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"package-manager", "c++", "c", "build-system"},
    keywords = {"vcpkg", "c++", "c", "package-manager", "microsoft"},

    programs = {"vcpkg"},
    xvm_enable = true,

    -- Mirrored through the xlings-res resource service (xpkg-creater §1.2.1):
    -- github.com/xlings-res/vcpkg and gitcode.com/xlings-res/vcpkg both carry
    -- tag 2026.7.27 with every asset below, verified byte-identical against
    -- each other AND against the upstream vcpkg-tool release they were built
    -- from. Asset naming: `vcpkg-2026.7.27-<os>-<arch>.<zip|tar.gz>` (zip on
    -- windows, tar.gz elsewhere) + a matching `.sha256` sidecar.
    --
    -- macosx: xlings-res's own naming convention spells the Apple arch
    -- `arm64` in the asset filename (`vcpkg-2026.7.27-macosx-arm64.tar.gz`),
    -- not the canonical `aarch64` this table's key uses -- the key is what
    -- the resolver matches against `archs`/the host arch, the filename is a
    -- resource-service detail. Both macosx assets (arm64-named and
    -- x86_64-named) carry the SAME universal vcpkg binary; they are still two
    -- distinct archives with two distinct sha256, not one file referenced
    -- twice, so both are pinned here rather than aliased.
    xpm = {
        linux = {
            ["latest"] = { ref = "2026.7.27" },
            ["2026.7.27"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64  = "d23b797eb93679d98569c23ee623b88215a0ef4dda93db334d675f9d0dab83bd",
                    aarch64 = "0df7f7522ff4f6e9c2d772b20c40248fb482f858e6d37e0f40921024a201552c",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "2026.7.27" },
            ["2026.7.27"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "433a4af350b4b63d4de7ffe133c80afe58ee5f345c14ce78ff89c70143be8497",
                    x86_64  = "e5fa84661acee0821697a07ecf90a67343ce9f8ff37fea808e736565b48e7a1e",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2026.7.27" },
            ["2026.7.27"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64  = "e676aebd1b364f50339a22cb38c85106432ff56cf675ab854b969a854c7fcdae",
                    aarch64 = "6abd963568e471308c05b70b8aa6a38d1b2e76b45b71c467e71a7258f1f6f965",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- The binary this recipe's own `installed()` checks for -- named per host,
-- matching cmake.lua's/ninja.lua's os.host()-branch shape.
local function vcpkg_exe()
    return os.host() == "windows" and "vcpkg.exe" or "vcpkg"
end

function install()
    -- Same shape as pkgs/c/cmake.lua: the archive's own top-level directory
    -- is the download's basename with the archive extension stripped, and
    -- that directory already IS the install layout (binary + .vcpkg-root +
    -- scripts/ + triplets/ at its root) -- move it in as-is.
    os.tryrm(pkginfo.install_dir())
    local extracted = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.mv(extracted, pkginfo.install_dir())
    return os.isfile(path.join(pkginfo.install_dir(), vcpkg_exe()))
end

function installed()
    local d = pkginfo.install_dir()
    -- The binary alone is not "installed" in the sense this recipe means:
    -- `.vcpkg-root` and `scripts/buildsystems/vcpkg.cmake` are what make the
    -- directory a working VCPKG_ROOT rather than just a copy of the tool.
    if not os.isfile(path.join(d, vcpkg_exe())) then return false end
    if not os.isfile(path.join(d, ".vcpkg-root")) then return false end
    if not os.isfile(path.join(d, "scripts", "buildsystems", "vcpkg.cmake")) then
        return false
    end
    return true
end

function config()
    -- The binary sits at the install root, not under bin/.
    xvm.add("vcpkg", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("vcpkg")
    return true
end
