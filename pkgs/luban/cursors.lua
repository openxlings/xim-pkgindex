-- The same files on every system: one version table, which each platform
-- names (a platform-level `ref` is not read by xlings before 2026.10.16.2).
local versions = {
    ["latest"] = { ref = "2026.10.19" },
    ["2026.10.19"] = {
        url = {
            GLOBAL = "https://github.com/xlings-res/luban-cursors/releases/download/2026.10.19/luban-cursors-2026.10.19.tar.gz",
            CN     = "https://gitcode.com/xlings-res/luban-cursors/releases/download/2026.10.19/luban-cursors-2026.10.19.tar.gz",
        },
        sha256 = "f72d99e50a550d02ee8bc59b072ddfc25aa4e38d7d86f679036a312cbd965a97",
    },
}

package = {
    spec = "1",

    name = "cursors",
    namespace = "luban",
    description = "The Luban pointer theme: pixel art, 24 px logical, the same on every system and in every Luban program",

    homepage = "https://github.com/openxlings/xim-pkgindex/tree/main/tools/res/cursors",
    licenses = {"Apache-2.0"},

    type = "package",
    -- Data: the same files on every system and machine.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "theme", "luban"},
    keywords = {"cursor", "xcursor", "pointer", "theme", "pixel", "luban"},

    -- The Luban pointer theme (xlings design 2026-10-19 §15.2): every shape
    -- opensal names (CSS names), drawn on a 12x12 grid and scaled by whole
    -- multiples -- 24, 48, 72 px for density 1, 2, 3. One source,
    -- tools/res/cursors/luban.cursors in this index, made into:
    --   share/icons/Luban/cursors   Xcursor files, the X11 names as links
    --   share/icons/default         inherits Luban: what a client naming no
    --                               theme gets (only this package writes it)
    --   share/luban/cursors         PNGs and cursors.json: the Luban OS
    --                               window draws its pointer from them
    xpm = {
        linux = versions,
        macosx = versions,
        windows = versions,
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = path.join(path.directory(pkginfo.install_file()), "luban-cursors-" .. pkginfo.version())
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "share", "icons", "Luban", "cursors", "default"))
        and os.isfile(path.join(dir, "share", "icons", "default", "index.theme"))
        and os.isfile(path.join(dir, "share", "luban", "cursors", "cursors.json"))
end

-- Data, not a program: the package name is registered so a home knows it has
-- it (a group: it names no program, so it has no shim).
function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
