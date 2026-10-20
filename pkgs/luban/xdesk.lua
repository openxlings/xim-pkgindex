package = {
    spec = "1",

    name = "xdesk",
    namespace = "luban",
    description = "xdesk, Luban's own desktop: classic (windows side by side, a panel) and canvas (an infinite canvas) -- no GPU needed",

    homepage = "https://github.com/openxlings/xlings",
    repo = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    -- luban-desktop: offered where a desktop is chosen (design 2026-10-18 §6.4).
    categories = {"desktop", "wayland", "luban", "luban-desktop"},
    keywords = {"xdesk", "wayland", "compositor", "desktop", "canvas", "luban"},

    -- What Luban shows of it (xlings design 2026-10-19 §5.4; xpkg spec
    -- "extensions"): Luban's own desktop, not on the T1-T4 axis.
    extensions = {
        luban = {
            title = { en = "xdesk", zh = "xdesk" },
            summary = { en = "Luban's own desktop: tiling, stacking and an infinite canvas",
                        zh = "Luban 自己的桌面：平铺、层叠与无限画布" },
        },
    },

    -- The desktop edition's (design §6.1): xim:xdesk -- the program,
    -- released with xlings, its sessions xdesk (from 2026.10.19.2: tile,
    -- stack or canvas per workspace), xdesk-classic and xdesk-canvas --
    -- with the terminal it starts (luban:foot, the default terminal).
    -- Form: a composite (design §4.6): its deps, nothing of its own.
    xpm = {
        linux = {
            -- luban:cursors: the pointer theme (xlings design 2026-10-19 §13).
            -- A platform's deps are every version's: 2026.10.18.1 brings
            -- xdesk 2026.10.19.2 too (the one whose pointer is drawn).
            deps = { "xim:xdesk@2026.10.19.2", "luban:foot", "luban:cursors" },
            ["latest"] = { ref = "2026.10.19.2" },
            -- 1: luban:cursors became a dependency. 2: xdesk 2026.10.19.2.
            ["2026.10.18.1"] = { revision = 2 },
            ["2026.10.19.2"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
