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

    -- From 4.5.0 on, resources come straight from Kitware's own GitHub
    -- release assets (same bytes as cmake.org), sha256 cross-checked against
    -- the release's `cmake-<ver>-SHA-256.txt` manifest. Upstream archive
    -- names match their extracted top-level directories, so install()'s
    -- strip-the-extension derivation needs no repack — including
    -- macos-universal, the asset the xlings-res leg had to repack.
    --
    -- Historical 4.4.2 / 4.0.2 stay on the xlings-res mirror (both legs,
    -- github.com/xlings-res/cmake and gitcode.com/xlings-res/cmake),
    -- untouched. The autoupdate source now points at the real upstream
    -- release directory so future versions no longer wait on a hand-mirrored
    -- xlings-res tag (the reason this recipe sat on 4.0.2 while upstream
    -- reached 4.4.2). Kitware publishes one `cmake-<ver>-SHA-256.txt`
    -- manifest per release instead of per-asset `.sha256` sidecars, so the
    -- old `verify = "sha256-sidecar"` does not apply upstream and is dropped.


    extensions = {
        autoupdate = {
            source = "https://github.com/Kitware/CMake/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/Kitware/CMake/releases/download/v${version}/cmake-${version}-linux-x86_64.tar.gz",
                        },
                        macosx = {
                            aarch64 = "https://github.com/Kitware/CMake/releases/download/v${version}/cmake-${version}-macos-universal.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/Kitware/CMake/releases/download/v${version}/cmake-${version}-windows-x86_64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            -- Runtime deps, re-measured across the WHOLE 4.5.0 payload rather
            -- than just bin/cmake (readelf on every ELF under bin/; the
            -- closure is identical to 4.4.2):
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
            ["latest"] = { ref = "4.5.0" },
            ["4.5.0"] = {
                url = "https://github.com/Kitware/CMake/releases/download/v4.5.0/cmake-4.5.0-linux-x86_64.tar.gz",
                sha256 = {
                    x86_64 = "81f0d5b0960fb6adc8197030ffc827fba937640d51e73e39e0e9e40d88c66f6f",
                },
            },
            ["4.4.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3ada9a3f5d8a85413579bdd0ea6aa8e8da86efdd6d15c91a1afa517f2021956c",
                },
            },
            ["4.0.2"] = "XLINGS_RES",
        },
        macosx = {
            ["latest"] = { ref = "4.5.0" },
            ["4.5.0"] = {
                url = "https://github.com/Kitware/CMake/releases/download/v4.5.0/cmake-4.5.0-macos-universal.tar.gz",
                sha256 = {
                    aarch64 = "a645d69fd21e521759cc0c64e7c60462d43faf0c7214ac05f75c80f7c5037dde",
                },
            },
            ["4.4.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "666abd8a375c61affdc68bdebfa2124aee9aa08cd795f7568aef4fcabb75f2db",
                },
            },
            ["4.0.2"] = "XLINGS_RES",
        },
        windows = {
            ["latest"] = { ref = "4.5.0" },
            ["4.5.0"] = {
                url = "https://github.com/Kitware/CMake/releases/download/v4.5.0/cmake-4.5.0-windows-x86_64.zip",
                sha256 = {
                    x86_64 = "301b1728317ccd84e984b02e366a8293735bc5ac618757d3d8f58b578f062411",
                },
            },
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