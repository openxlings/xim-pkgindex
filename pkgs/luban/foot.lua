package = {
    spec = "1",

    name = "foot",
    namespace = "luban",
    description = "A fast, lightweight Wayland terminal (foot), as the Luban desktops' default terminal",

    homepage = "https://codeberg.org/dnkl/foot",
    repo = "https://codeberg.org/dnkl/foot",
    licenses = {"MIT"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"terminal", "wayland", "luban"},
    keywords = {"foot", "terminal", "wayland", "luban"},

    -- Form: a small bundle (xlings: 2026-10-18 Luban OS distribution design
    -- §4.6) -- Alpine 3.24's foot with its musl loader and the 21 libraries
    -- it links, private in libexec/foot (tools/res/build.sh foot). Chosen
    -- because it is small (8 MB), runs only on a Wayland desktop, and every
    -- desktop shares one: it is found through the default-terminal convention
    -- (share/xdg-terminals/foot.desktop), not by name. Its fonts are the
    -- system's (xim:luban-fonts in a Luban system).
    programs = {"foot", "footclient"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xim:luban-fonts" },
            ["latest"] = { ref = "1.27.0-r2" },
            -- r2: the right button pastes the clipboard, Ctrl+right extends a
            -- selection (etc/xdg/foot/foot.ini; xlings design 2026-10-24 §8.3).
            ["1.27.0-r2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bc49da4ad308ae7795b3c5013e5aa95b6019a0fa5c734b903165ecf800669dbc",
                    aarch64 = "0e37040d28f4dc4556bc9e609c70cc9f747d1804fe71cf4522641c952921b3d9",
                },
            },
            ["1.27.0-r1"] = {
                -- 1: its loader searches only its tree (xlings design 2026-10-21 J12).
                revision = 1,
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "b3f887a75117e076448ae4d99b18768c42b86b9754b65c34486968ca5c7bc13d",
                    aarch64 = "18c169f87739580794fb9ac610e929473a29b0c44a507bd7debfab2de68052f7",
                },
            },
        },
    },
}

import("xim.pkgindex.luban_component")

function install()
    return luban_component.install({ "bin/foot", "share/xdg-terminals/foot.desktop" })
end

function config()
    return luban_component.config(package.programs,
        { "share/xdg-terminals", "share/applications", "share/terminfo", "share/luban/checks.d" })
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
