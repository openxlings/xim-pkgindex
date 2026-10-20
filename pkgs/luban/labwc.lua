package = {
    spec = "1",

    name = "labwc",
    namespace = "luban",
    description = "The labwc desktop: labwc with a panel, a launcher and a background -- light, no GPU needed",

    homepage = "https://labwc.github.io",
    repo = "https://github.com/labwc/labwc",
    licenses = {"GPL-2.0-only", "MIT"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    -- luban-desktop: offered where a desktop is chosen (xlings: 2026-10-18
    -- Luban OS distribution design §6.4).
    categories = {"desktop", "wayland", "luban", "luban-desktop"},
    keywords = {"labwc", "wlroots", "wayland", "desktop", "luban", "yambar", "fuzzel"},

    -- What Luban shows of it (xlings design 2026-10-19 §5.4; xpkg spec
    -- "extensions"): T2.
    extensions = {
        luban = {
            tier = 2,
            title = { en = "labwc", zh = "labwc" },
            summary = { en = "Light: a panel, a launcher and a background", zh = "轻量：面板、启动器和背景" },
        },
    },

    -- The T2 desktop (design §7): labwc, a panel (yambar), a launcher
    -- (fuzzel), a background (swaybg), screenshots (grim). The session is
    -- share/wayland-sessions/labwc.desktop (X-Luban-Shell=own; it was
    -- labwc-desktop, X-Luban-Aliases says so); its defaults are in
    -- etc/xdg and reach its programs only through its own wrappers, a user's
    -- ~/.config winning. The terminal is the default one (luban:foot here),
    -- found through xdg-terminal-exec; X11 programs run on luban:xwayland.
    --
    -- Form: a bundle (design §4.6) -- Alpine 3.24's labwc 0.20 and its
    -- programs on wlroots 0.20 built with pixman alone, the musl loader and
    -- 87 libraries private in libexec/labwc (tools/res/build.sh labwc):
    -- 31 MB, where Alpine's wlroots would bring mesa and LLVM (273 MB).
    -- Chosen because it works as one, few things reuse its parts, and a
    -- machine has no GPU to use; the name and the session stay if it is ever
    -- made of atomic packages instead.
    programs = {"labwc", "yambar", "fuzzel", "swaybg", "grim", "xdg-terminal-exec"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- New in this index with this package, so bare: CI registers a
            -- changed recipe under `local`, where a `luban:` prefix would
            -- not resolve (graphics.lua says more). Namespaced once published.
            -- The pointer theme every official desktop has (xlings design
            -- 2026-10-19 §13): lxqt, kde and compositor get it through this.
            deps = { "luban:foot", "luban:xwayland", "xim:luban-fonts", "xim:xkeyboard-config", "luban:cursors" },
            ["latest"] = { ref = "0.20.0-r2" },
            ["0.20.0-r2"] = {
                -- 1: luban:cursors became a dependency (a new install gets the
                -- theme; one made before stays usable).
                revision = 1,
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "0e71ecb3c89c134da99aac6c54f61cf6b65e6994c1d8412d3834ab6d7eeddfcf",
                    aarch64 = "f1e93ab50956b2b58563f09fdf56585295ac96fb1735b5f4118130f41d1d0660",
                },
            },
        },
    },
}

import("xim.pkgindex.luban_component")

function install()
    return luban_component.install({ "bin/labwc", "share/wayland-sessions/labwc.desktop" })
end

function config()
    return luban_component.config(package.programs, { "share/wayland-sessions", "share/luban/checks.d" })
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
