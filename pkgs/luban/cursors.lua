-- The same files on every system: one version table, which each platform
-- names (a platform-level `ref` is not read by xlings before 2026.10.16.2).
local versions = {
    ["latest"] = { ref = "2026.10.21.1" },
    -- Drawn from vectors at 24, 30, 36, 48, 60 and 72 px (density 1 to 3),
    -- released with xlings (xlings design 2026-10-20 WuXian §8): the window
    -- draws the same shapes itself, so no PNGs for it.
    ["2026.10.21.1"] = {
        url = {
            GLOBAL = "https://github.com/xlings-res/luban-cursors/releases/download/2026.10.21.1/luban-cursors-2026.10.21.1.tar.gz",
            CN     = "https://gitcode.com/xlings-res/luban-cursors/releases/download/2026.10.21.1/luban-cursors-2026.10.21.1.tar.gz",
        },
        sha256 = "2b7ef6d4d68cfafcbff3d49cb839c990a6719e11216b6712fe71a47313967471",
    },
    -- The arrow's tail one column over every two rows (xlings design 2026-10-20 §14.2).
    ["2026.10.20"] = {
        url = {
            GLOBAL = "https://github.com/xlings-res/luban-cursors/releases/download/2026.10.20/luban-cursors-2026.10.20.tar.gz",
            CN     = "https://gitcode.com/xlings-res/luban-cursors/releases/download/2026.10.20/luban-cursors-2026.10.20.tar.gz",
        },
        sha256 = "f38a49b58cd4531ed7574c7b6127db64f8d4388d97d0dbfa649955dddcbbfaa2",
    },
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
    description = "The Luban pointer theme: drawn from vectors at every density, the same on every system and in every Luban program",

    homepage = "https://github.com/openxlings/xlings/tree/main/luban/os/window/cursors",
    licenses = {"Apache-2.0"},

    type = "package",
    -- Data: the same files on every system and machine.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "theme", "luban"},
    keywords = {"cursor", "xcursor", "pointer", "theme", "vector", "luban"},

    -- The Luban pointer theme: every shape opensal names (CSS names), drawn
    -- from vector shapes (luban/os/window/cursors/luban.path in xlings, by
    -- cursorkit's cursor-make; released with xlings from 2026.10.21.1):
    --   share/icons/Luban/cursors   Xcursor files, the X11 names as links
    --   share/icons/default         inherits Luban: what a client naming no
    --                               theme gets (only this package writes it)
    -- The versions before (2026.10.19, 2026.10.20: pixel art made in this
    -- index) also carry share/luban/cursors, PNGs a Luban OS window of then read.
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
