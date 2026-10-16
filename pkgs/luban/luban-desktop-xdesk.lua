-- Luban Desktop (xdesk canvas): luban-desktop's environment on xdesk's
-- canvas profile -- windows placed on an infinite canvas, panned, zoomed and
-- seen all at once (xlings: Luban OS desktop part 2). To explore; the
-- classic profile (luban-desktop) is the recommended one.
--
-- Below, luban-desktop's notes, which hold for it too.
--
-- Luban Desktop: luban-core plus a desktop that is ready to use (xlings:
-- Luban OS desktop part 2) -- xdesk's classic profile (windows side by side,
-- a panel, a launcher), the tools people reach for (node, python, uv, bun,
-- ripgrep, fd, fzf, jq, tmux, htop; claude, codex, pi, opencode, dsh), and
-- their defaults (git, registries near you). It runs as a machine
-- (usr/share/luban/settings.json: the edition's defaults behind `luban
-- config`) and starts xdesk-classic; labwc is there as another session. The
-- canvas profile is luban-desktop-xdesk.
--
--   luban new box --edition desktop      # then: luban-os, or luban enter box
--
-- 0.1.0 was the preview (a graphics stack, no session) and is kept as it was
-- published; `from` makes each root its base edition's plus what it declares.
-- Nothing to download -- install() writes the template.
package = {
    spec = "1",
    name = "luban-desktop-xdesk",
    namespace = "subos",
    description = "Luban Desktop (xdesk canvas): the desktop environment on an infinite canvas, shown in the Luban OS window",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    -- x86_64 until xdesk is released for aarch64 (the quick start says so there).
    archs = {"x86_64"},
    status = "dev",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "desktop", "xdesk", "wayland"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.16.2" },
            ["2026.10.13.1"] = {},
            ["2026.10.15.1"] = {},
            ["2026.10.16.1"] = {},
            ["2026.10.16.2"] = {},
        },
    },
}

import("xim.pkgindex.luban")
import("xim.pkgindex.luban_desktop")

local versions = {
    -- luban-desktop's environment and defaults, starting xdesk-canvas.
    ["2026.10.13.1"] = {
        manifest = luban_desktop.manifest("x86_64", "subos:luban-core@2026.10.11.2"),
        files = luban_desktop.files("xdesk-canvas"),
    },
    -- On Luban Core 2026.10.15.1: gh beside git.
    ["2026.10.15.1"] = {
        manifest = luban_desktop.manifest("x86_64", "subos:luban-core@2026.10.15.1"),
        files = luban_desktop.files("xdesk-canvas"),
    },
    -- On Luban Core 2026.10.16.1 (terminfo, the not-found hint, mcpp's
    -- system configuration): a default cursor theme, and its checks.
    ["2026.10.16.1"] = {
        manifest = luban_desktop.manifest("x86_64", "subos:luban-core@2026.10.16.1", luban_desktop.since_2026_10_16),
        files = luban_desktop.files("xdesk-canvas", { luban.checks("desktop-xdesk", luban_desktop.CHECKS) }),
    },
    -- On Luban Core 2026.10.16.2 (mcpp 2026.10.16.3).
    ["2026.10.16.2"] = {
        manifest = luban_desktop.manifest("x86_64", "subos:luban-core@2026.10.16.2", luban_desktop.since_2026_10_16),
        files = luban_desktop.files("xdesk-canvas", { luban.checks("desktop-xdesk", luban_desktop.CHECKS) }),
    },
}

function install()
    return luban.edition({ id = "desktop-xdesk", variant = "Desktop (xdesk canvas)", versions = versions })
end
