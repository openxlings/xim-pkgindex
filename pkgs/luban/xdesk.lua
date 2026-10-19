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

    -- The desktop edition's (design §6.1): xim:xdesk -- the program,
    -- released with xlings, its sessions xdesk-classic and xdesk-canvas --
    -- with the terminal it starts (luban:foot, the default terminal).
    -- Form: a composite (design §4.6): its deps, nothing of its own.
    xpm = {
        linux = {
            deps = { "xim:xdesk@2026.10.18.1", "luban:foot" },
            ["latest"] = { ref = "2026.10.18.1" },
            ["2026.10.18.1"] = {},
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
