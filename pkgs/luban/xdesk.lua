package = {
    spec = "1",

    name = "xdesk",
    namespace = "luban",
    description = "xdesk, Luban's own desktop: workspaces on WuXian, one infinite plane -- each tiled or stacked; the GPU when there is one",

    homepage = "https://github.com/openxlings/xlings",
    repo = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    -- luban-desktop: offered where a desktop is chosen (design 2026-10-18 §6.4).
    categories = {"desktop", "wayland", "luban", "luban-desktop"},
    keywords = {"xdesk", "wayland", "compositor", "desktop", "wuxian", "workspaces", "luban"},

    -- What Luban shows of it (xlings design 2026-10-19 §5.4; xpkg spec
    -- "extensions"): Luban's own desktop, not on the T1-T4 axis.
    extensions = {
        luban = {
            title = { en = "xdesk", zh = "xdesk" },
            summary = { en = "Luban's own desktop: workspaces on WuXian, tiled or stacked",
                        zh = "Luban 自己的桌面：WuXian 上的工作区，平铺或层叠" },
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
            -- luban:audio and luban:falkon: a desktop's sound and its browser (xlings design 2026-10-20 §20).
            -- xim:graphics: xdesk 2026.10.21.1 composes with GLES when the
            -- system's GPU can (xlings design 2026-10-20 WuXian §7.4).
            deps = { "xim:xdesk@2026.10.21.1", "luban:foot", "luban:cursors", "luban:audio", "luban:falkon", "xim:graphics@>=0.1" },
            ["latest"] = { ref = "2026.10.21.1" },
            -- 1: luban:cursors became a dependency. 2: xdesk 2026.10.19.2.
            -- 3 (and 2026.10.19.2's 1): luban:audio and luban:falkon.
            -- 4 (2026.10.19.2's 2): xdesk 2026.10.20.1 -- its switchers,
            -- settings, keys and displays (xlings design 2026-10-20).
            -- 5 (2026.10.19.2's 3, 2026.10.20.1's 1): xdesk 2026.10.21.1 --
            -- WuXian's workspaces, the GPU, the vector pointer -- and the
            -- graphics stack (xlings design 2026-10-20 WuXian).
            ["2026.10.18.1"] = { revision = 5 },
            ["2026.10.19.2"] = { revision = 3 },
            ["2026.10.20.1"] = { revision = 1 },
            ["2026.10.21.1"] = {},
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
