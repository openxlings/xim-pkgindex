package = {
    spec = "1",
    -- base info
    name = "cmake",
    description = "A Powerful Software Build System",

    maintainers = {"Kitware"},
    licenses = {"BSD-3Clause"},
    repo = "https://github.com/Kitware/CMake",
    contributors = "https://github.com/Kitware/CMake/blob/master/CONTRIBUTORS.rst",
    docs = "https://cmake.org/documentation",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "arm64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"build", "system", "cmake"},
    keywords = {"build", "system", "cmake", "make", "generator", "cross-platform"},

    -- xvm: xlings version management
    xvm_enable = true,

    -- Mirrored through the xlings-res resource service, so every version entry
    -- below needs the SAME tag present on both legs before it can be referenced
    -- here (xpkg-creater §1.2.1): github.com/xlings-res/cmake and
    -- gitcode.com/xlings-res/cmake. Asset names follow the resource-service
    -- convention `cmake-<ver>-<os>-<arch>.{tar.gz,zip}` (the installer appends
    -- the host arch itself) plus a matching `.sha256` sidecar.
    --
    -- macosx-arm64 is upstream's `cmake-<ver>-macos-universal.tar.gz` REPACKED
    -- so the top-level directory matches the asset name — install() derives the
    -- extracted directory by stripping the extension off the download, so a
    -- plain rename would leave it looking for a directory that isn't there.
    -- linux-x86_64 and windows-x86_64 are upstream bytes verbatim.
    --
    -- No `ci = { update = true }` / `res_versioned = true` here: the auto-bump
    -- path verifies mirrored assets but does not create them, so it would just
    -- error on every upstream release until someone mirrors it by hand. That is
    -- also why this recipe sat on 4.0.2 while upstream reached 4.4.2 — worth
    -- automating (mirror-then-bump), but that is a tooling change, not a
    -- recipe change.
    xpm = {
        linux = {
            -- Runtime deps, re-measured across the WHOLE 4.4.2 payload rather
            -- than just bin/cmake (readelf on every ELF under bin/):
            --
            --   cmake, ctest, cpack, ccmake   libdl librt libpthread libm libc
            --                                 + ld-linux  -> all glibc
            --   cmake-gui                     the same, plus libxcb.so.1,
            --                                 libfontconfig.so.1, libfreetype.so.6
            --
            -- No libstdc++ anywhere (statically linked in), and ccmake does NOT
            -- need ncurses — also static.
            --
            -- The three GUI sonames are why fontconfig/freetype/libxcb are
            -- declared even though most consumers only ever run `cmake`.
            -- Because this recipe declares xim:glibc the payload gets our
            -- loader, and behind our loader there is no host fallback — an
            -- undeclared soname is simply not found (closure rules D1/D2).
            -- Declaring them is also what puts their libdirs in this payload's
            -- RPATH closure; a transitive dep would not.
            --
            -- bin/cmake's own floor is only GLIBC_2.17. The `>=2.39` below is
            -- deliberately the index's glibc baseline (glibc.lua ships 2.39 and
            -- 2.44), not the binary's requirement — don't "fix" it down to
            -- 2.17, there is nothing older to resolve to.
            deps = {
                runtime = {
                    "xim:glibc@>=2.39",
                    "xim:fontconfig@>=2.15",
                    "xim:freetype@>=2.13",
                    "xim:libxcb@>=1.17",
                },
            },
            ["latest"] = { ref = "4.4.2" },
            ["4.4.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3ada9a3f5d8a85413579bdd0ea6aa8e8da86efdd6d15c91a1afa517f2021956c",
                },
            },
            ["4.0.2"] = "XLINGS_RES",
        },
        macosx = {
            ["latest"] = { ref = "4.4.2" },
            ["4.4.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "666abd8a375c61affdc68bdebfa2124aee9aa08cd795f7568aef4fcabb75f2db",
                },
            },
            ["4.0.2"] = "XLINGS_RES",
        },
        windows = {
            ["latest"] = { ref = "4.4.2" },
            ["4.4.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e8139d85b3813bc38833142ae1940472e9a587e9b5d2718ac1804c60f4e57a64",
                },
            },
            ["4.0.2"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    local cmakedir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.mv(cmakedir, pkginfo.install_dir())
    return true
end

function config()
    local config
    if os.host() == "macosx" then
        config = { bindir = path.join(pkginfo.install_dir(), "CMake.app/Contents/bin") }
    else
        config = { bindir = path.join(pkginfo.install_dir(), "bin") }
    end
    xvm.add("cmake", config)
    return true
end

function uninstall()
    xvm.remove("cmake")
    return true
end