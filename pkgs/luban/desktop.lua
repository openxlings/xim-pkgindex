-- Luban Desktop (xlings: 2026-10-18 Luban OS distribution design §6.1): core, a desktop (xdesk; labwc on aarch64 until xdesk is released there), the terminal and X11 programs, and the tools people reach for.
--
-- Luban's editions are in the luban: namespace from 2026.10.18.1; subos:luban-desktop is
-- frozen (its published versions stay) and `luban upgrade` moves a system
-- made from it here (`replaces`). What it presets is in its manifest's
-- `luban.settings` and the root's usr/share/luban/settings.json.
-- A published version's output never changes (tests/fixtures/luban-published.json).
package = {
    spec = "2",
    name = "desktop",
    namespace = "luban",
    description = "Luban Desktop: core, the xdesk desktop, a terminal, X11 programs and the everyday tools -- ready to use",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "desktop", "xdesk", "wayland"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.18.1" },
            ["2026.10.18.1"] = { min_client = "2026.10.18.1" },
        },
    },
}

import("xim.pkgindex.luban")

import("xim.pkgindex.luban_desktop")

local recipe_arch = (os.arch and os.arch())
local aarch64 = recipe_arch == "aarch64" or recipe_arch == "arm64"

-- Its composition (design §6.1): core + a desktop + luban:foot + luban:xwayland
-- + the tool sets. A desktop is chosen at `luban new --desktop`, not by edition.
local desktop = aarch64 and { package = "luban:labwc@0.20.0-r2", session = "labwc" }
                         or { package = "luban:xdesk@2026.10.18.1", session = "xdesk-classic" }

local CHECKS = [[
{"checks": [
  {"id": "desktop-applications", "what": "its launcher lists foot and nvim", "run": "ls /usr/share/applications | grep -q '^foot' && ls /usr/share/applications | grep -qi nvim", "timeout": 10},
  {"id": "desktop-cursors", "what": "a cursor theme is the default", "run": "grep -q '^Inherits=' /usr/share/icons/default/index.theme && test -e /usr/share/icons/Adwaita/cursors/left_ptr", "timeout": 10},
  {"id": "desktop-terminal", "what": "the default terminal is found", "run": "command -v xdg-terminal-exec >/dev/null || ls /usr/share/xdg-terminals | grep -q foot", "timeout": 10}
]}
]]

local versions = {
    ["2026.10.18.1"] = {
        files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS)),
        manifest = {
            subos_kind = "rootfs",
            min_client = "2026.10.18.1",
            from = "luban:core@2026.10.18.1",
            replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
            abi = { kernel = "linux", libc = "gnu" },
            packages = { desktop.package, "luban:foot@1.27.0-r1", "luban:xwayland@24.1.14-r1", "luban:tools-dev@2026.10.18.1",
                         "luban:tools-agent@2026.10.18.1", "luban:tools-cli@2026.10.18.1", "xim:adwaita-cursors@49.0",
                         -- The agents unpinned: recorded at `new`, moved by `luban upgrade`.
                         "xim:claude", "xim:codex", "xim:pi", "xim:opencode" },
            luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop.session, login_shell = "/usr/bin/fish" } },
            workspace = {},
        },
    },
}

function install()
    return luban.edition({ id = "desktop", variant = "Desktop", versions = versions })
end
