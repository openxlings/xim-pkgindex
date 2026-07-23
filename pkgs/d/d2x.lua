package = {
    spec = "1",

    -- base info
    name = "d2x",
    description = "xlings's d2x tool",

    authors = {"Sunrisepeak"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/d2learn/d2x",

    -- xim pkg info
    type = "package",

    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"d2x", "tool", "mcpp" },
    keywords = {"d2x", "tool", "mcpp" },

    programs = { "d2x" },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "2026.07.24.1" },
            ["2026.07.24.1"] = "XLINGS_RES",
            ["0.1.5"] = "XLINGS_RES",
            ["0.1.4"] = "XLINGS_RES",
            ["0.1.3"] = "XLINGS_RES",
            ["0.1.2"] = "XLINGS_RES",
            ["0.1.1"] = "XLINGS_RES",
        },
        linux = {
            deps = { "xim:glibc@2.39", "xim:openssl@3.1.5" },
            ["latest"] = { ref = "2026.07.24.1" },
            ["2026.07.24.1"] = "XLINGS_RES",
            ["0.1.5"] = "XLINGS_RES",
            ["0.1.4"] = "XLINGS_RES",
            ["0.1.3"] = "XLINGS_RES",
            ["0.1.2"] = "XLINGS_RES",
            ["0.1.1"] = "XLINGS_RES",
            ["0.1.0"] = "XLINGS_RES",
        },
        macosx = {
            ["latest"] = { ref = "2026.07.24.1" },
            ["2026.07.24.1"] = "XLINGS_RES",
            ["0.1.5"] = "XLINGS_RES",
            ["0.1.4"] = "XLINGS_RES",
            ["0.1.3"] = "XLINGS_RES",
        }
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
-- elfpatch import removed: predicate-driven auto-patch (post 2026-05-02
-- design) reads glibc.lua's exports.runtime.loader and rewrites our
-- INTERP / RPATH automatically. No install-hook elfpatch call needed.

function install()
    local d2xdir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(d2xdir, pkginfo.install_dir())

    return true
end

function config()
    xvm.add("d2x")
    return true
end

function uninstall()
    xvm.remove("d2x")
    return true
end