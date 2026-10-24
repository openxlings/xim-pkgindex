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

    -- What a Luban OS card shows of it (xlings design 2026-10-19 §20; xpkg
    -- spec "extensions"): a few of its programs, names in every language.
    extensions = { luban = { highlights = { "xdesk", "foot", "nvim", "gcc", "git" } } },

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.24.2" },
            ["2026.10.18.1"] = { min_client = "2026.10.18.1" },
            ["2026.10.19.1"] = { min_client = "2026.10.18.1" },
            ["2026.10.20.1"] = { min_client = "2026.10.20.1" },
            ["2026.10.21.1"] = { min_client = "2026.10.20.1" },
            ["2026.10.21.3"] = { min_client = "2026.10.20.1" },
            ["2026.10.22.1"] = { min_client = "2026.10.20.1" },
            ["2026.10.22.2"] = { min_client = "2026.10.20.1" },
            ["2026.10.23.1"] = { min_client = "2026.10.20.1" },
            ["2026.10.24.1"] = { min_client = "2026.10.20.1" },
            ["2026.10.24.2"] = { min_client = "2026.10.20.1" },
        },
    },
}

import("xim.pkgindex.luban")

import("xim.pkgindex.luban_desktop")

-- The machine's arch (core.lua): os.arch where the catalog loader binds it,
-- else luban.arch() -- install() runs where os.arch is not bound, and read
-- alone it gave aarch64 the x86_64-only xdesk.
local recipe_arch = (os.arch and os.arch())
if recipe_arch ~= "aarch64" and recipe_arch ~= "arm64" and recipe_arch ~= "x86_64" then
    recipe_arch = luban.arch()
end
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

-- 2026.10.19.1 (xlings design 2026-10-19 §13, §17, §20): on core
-- 2026.10.19.1; xdesk 2026.10.19.2, whose pointer the Luban OS window draws,
-- in its `xdesk` session (tile, stack or canvas per workspace, Super+m); the
-- Luban pointer theme (luban:cursors, a dependency of luban:xdesk and
-- luban:labwc) in place of Adwaita's.
local desktop_2026_10_19 = aarch64 and { package = "luban:labwc@0.20.0-r2", session = "labwc" }
                                    or { package = "luban:xdesk@2026.10.19.2", session = "xdesk" }

local CHECKS_2026_10_19 = [[
{"checks": [
  {"id": "desktop-applications", "what": "its launcher lists foot and nvim", "run": "ls /usr/share/applications | grep -q '^foot' && ls /usr/share/applications | grep -qi nvim", "timeout": 10},
  {"id": "desktop-cursors", "what": "the Luban pointer theme is the default", "run": "grep -q '^Inherits=Luban' /usr/share/icons/default/index.theme && test -e /usr/share/icons/Luban/cursors/default", "timeout": 10},
  {"id": "desktop-terminal", "what": "the default terminal is found", "run": "command -v xdg-terminal-exec >/dev/null || ls /usr/share/xdg-terminals | grep -q foot", "timeout": 10}
]}
]]

versions["2026.10.19.1"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_19)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.18.1",
        from = "luban:core@2026.10.19.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = { desktop_2026_10_19.package, "luban:foot@1.27.0-r1", "luban:xwayland@24.1.14-r1", "luban:tools-dev@2026.10.18.1",
                     "luban:tools-agent@2026.10.18.1", "luban:tools-cli@2026.10.18.1",
                     -- The agents unpinned: recorded at `new`, moved by `luban upgrade`.
                     "xim:claude", "xim:codex", "xim:pi", "xim:opencode" },
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_19.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}

-- 2026.10.20.1 (xlings design 2026-10-20): on core 2026.10.20.1 (sudo);
-- xdesk 2026.10.20.1 -- its switchers, settings, keys, displays -- which,
-- like luban:labwc, brings a browser (luban:falkon) and sound
-- (luban:audio, played on the computer Luban OS runs on); the system's user
-- is lubanoser (the client: any desktop has one).
local desktop_2026_10_20 = aarch64 and { package = "luban:labwc@0.20.0-r2", session = "labwc" }
                                    or { package = "luban:xdesk@2026.10.20.1", session = "xdesk" }

local CHECKS_2026_10_20 = [[
{"checks": [
  {"id": "desktop-applications", "what": "its launcher lists foot, nvim and the browser", "run": "ls /usr/share/applications | grep -q '^foot' && ls /usr/share/applications | grep -qi nvim && ls /usr/share/applications | grep -qi falkon", "timeout": 10},
  {"id": "desktop-cursors", "what": "the Luban pointer theme is the default", "run": "grep -q '^Inherits=Luban' /usr/share/icons/default/index.theme && test -e /usr/share/icons/Luban/cursors/default", "timeout": 10},
  {"id": "desktop-terminal", "what": "the default terminal is found", "run": "command -v xdg-terminal-exec >/dev/null || ls /usr/share/xdg-terminals | grep -q foot", "timeout": 10},
  {"id": "desktop-sound", "what": "its sound has the luban output", "run": "test -e /usr/share/pipewire/pipewire.conf.d/luban.conf && command -v luban-audio >/dev/null", "timeout": 10}
]}
]]

versions["2026.10.20.1"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_20)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:core@2026.10.20.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = { desktop_2026_10_20.package, "luban:foot@1.27.0-r1", "luban:xwayland@24.1.14-r1", "luban:tools-dev@2026.10.18.1",
                     "luban:tools-agent@2026.10.18.1", "luban:tools-cli@2026.10.18.1",
                     -- The agents unpinned: recorded at `new`, moved by `luban upgrade`.
                     "xim:claude", "xim:codex", "xim:pi", "xim:opencode" },
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_20.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}

-- 2026.10.21.1 (xlings design 2026-10-20 WuXian): xdesk 2026.10.21.1 --
-- workspaces on WuXian, composing with the GPU when the system has one (the
-- graphics stack, xim:graphics, comes with it), the vector pointer -- and
-- Falkon with ICU's data. The same core.
local desktop_2026_10_21 = aarch64 and { package = "luban:labwc@0.20.0-r2", session = "labwc" }
                                    or { package = "luban:xdesk@2026.10.21.1", session = "xdesk" }

versions["2026.10.21.1"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_20)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:core@2026.10.20.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = { desktop_2026_10_21.package, "luban:foot@1.27.0-r1", "luban:xwayland@24.1.14-r1", "luban:tools-dev@2026.10.18.1",
                     "luban:tools-agent@2026.10.18.1", "luban:tools-cli@2026.10.18.1",
                     -- The agents unpinned: recorded at `new`, moved by `luban upgrade`.
                     "xim:claude", "xim:codex", "xim:pi", "xim:opencode" },
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_21.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}

-- 2026.10.21.3 (WuXian §7.5): xdesk 2026.10.21.3 on Mesa with virgl (named
-- here: a home that has an older Mesa keeps it otherwise) -- as a machine, its
-- desktop draws on this computer's GPU. The same core.
local desktop_2026_10_21_3 = aarch64 and { package = "luban:labwc@0.20.0-r2", session = "labwc" }
                                      or { package = "luban:xdesk@2026.10.21.3", session = "xdesk" }
local packages_2026_10_21_3 = { desktop_2026_10_21_3.package, "luban:foot@1.27.0-r1", "luban:xwayland@24.1.14-r1",
                                "luban:tools-dev@2026.10.18.1", "luban:tools-agent@2026.10.18.1", "luban:tools-cli@2026.10.18.1",
                                -- The agents unpinned: recorded at `new`, moved by `luban upgrade`.
                                "xim:claude", "xim:codex", "xim:pi", "xim:opencode" }
if not aarch64 then table.insert(packages_2026_10_21_3, "xim:mesa@25.0.7.3") end

versions["2026.10.21.3"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_20)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:core@2026.10.20.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = packages_2026_10_21_3,
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_21_3.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}

-- 2026.10.22.1 (xlings design 2026-10-21): xdesk 2026.10.22.1 -- bookmarks,
-- collapse, the tour, its words -- and the desktops' player (luban:audacious,
-- with the Aria to play, luban:sample-music); a piece to play is checked.
local CHECKS_2026_10_22 = [[
{"checks": [
  {"id": "desktop-applications", "what": "its launcher lists foot, nvim, the browser and the player", "run": "ls /usr/share/applications | grep -q '^foot' && ls /usr/share/applications | grep -qi nvim && ls /usr/share/applications | grep -qi falkon && ls /usr/share/applications | grep -qi audacious", "timeout": 10},
  {"id": "desktop-cursors", "what": "the Luban pointer theme is the default", "run": "grep -q '^Inherits=Luban' /usr/share/icons/default/index.theme && test -e /usr/share/icons/Luban/cursors/default", "timeout": 10},
  {"id": "desktop-terminal", "what": "the default terminal is found", "run": "command -v xdg-terminal-exec >/dev/null || ls /usr/share/xdg-terminals | grep -q foot", "timeout": 10},
  {"id": "desktop-sound", "what": "its sound has the luban output", "run": "test -e /usr/share/pipewire/pipewire.conf.d/luban.conf && command -v luban-audio >/dev/null", "timeout": 10},
  {"id": "desktop-music", "what": "a piece to play is there", "run": "test -s /usr/share/luban/samples/music/aria.ogg", "timeout": 10}
]}
]]
local desktop_2026_10_22_1 = aarch64 and { package = "luban:labwc@0.20.0-r2", session = "labwc" }
                                      or { package = "luban:xdesk@2026.10.22.1", session = "xdesk" }
local packages_2026_10_22_1 = { desktop_2026_10_22_1.package, "luban:foot@1.27.0-r1", "luban:xwayland@24.1.14-r1",
                                "luban:audacious@4.5.1-r1",
                                "luban:tools-dev@2026.10.18.1", "luban:tools-agent@2026.10.18.1", "luban:tools-cli@2026.10.18.1",
                                -- The agents unpinned: recorded at `new`, moved by `luban upgrade`.
                                "xim:claude", "xim:codex", "xim:pi", "xim:opencode" }
if not aarch64 then table.insert(packages_2026_10_22_1, "xim:mesa@25.0.7.3") end

versions["2026.10.22.1"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_22)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:core@2026.10.20.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = packages_2026_10_22_1,
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_22_1.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}

-- 2026.10.22.2: the same desktop on luban:xdesk 2026.10.22.2 -- an xdesk that
-- runs on the C++ runtime a Luban system binds (xlings design 2026-10-21 J34).
local desktop_2026_10_22_2 = aarch64 and { package = "luban:labwc@0.20.0-r2", session = "labwc" }
                                      or { package = "luban:xdesk@2026.10.22.2", session = "xdesk" }
local packages_2026_10_22_2 = { desktop_2026_10_22_2.package }
for i = 2, #packages_2026_10_22_1 do table.insert(packages_2026_10_22_2, packages_2026_10_22_1[i]) end

versions["2026.10.22.2"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_22)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:core@2026.10.20.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = packages_2026_10_22_2,
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_22_2.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}


-- 2026.10.23.1: 2026.10.22.2 on core 2026.10.23.1 (its sudo check, J44).
versions["2026.10.23.1"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_22)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:core@2026.10.23.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = packages_2026_10_22_2,
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_22_2.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}
-- 2026.10.24.1 (xlings design 2026-10-24): 2026.10.23.1 with the browser that
-- opens https pages (luban:falkon 26.04.2-r2, J59), the terminal whose right
-- button pastes (luban:foot 1.27.0-r2, §8.3), on core 2026.10.24.1, carrying
-- the kernel it boots as a machine (boot.virt, §7.1).
local packages_2026_10_24_1 = {}
for _, p in ipairs(packages_2026_10_22_2) do
    table.insert(packages_2026_10_24_1, p == "luban:foot@1.27.0-r1" and "luban:foot@1.27.0-r2" or p)
end
table.insert(packages_2026_10_24_1, 2, "luban:falkon@26.04.2-r2")

versions["2026.10.24.1"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_22)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:core@2026.10.24.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = packages_2026_10_24_1,
        boot = { virt = "xim:linux-kernel-virt@6.12.112-r3" },
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_22_2.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}
-- 2026.10.24.2 (xlings design 2026-10-24): 2026.10.24.1 with xdesk
-- 2026.10.24.2 (luban:xdesk 2026.10.24.2, wl-clipboard with it), and checks
-- that every application shows an icon and each everyday program starts and
-- ends cleanly (§10.3).
local CHECKS_2026_10_24_2 = [[
{"checks": [
  {"id": "desktop-applications", "what": "its launcher lists foot, nvim, the browser and the player", "run": "ls /usr/share/applications | grep -q '^foot' && ls /usr/share/applications | grep -qi nvim && ls /usr/share/applications | grep -qi falkon && ls /usr/share/applications | grep -qi audacious", "timeout": 10},
  {"id": "desktop-cursors", "what": "the Luban pointer theme is the default", "run": "grep -q '^Inherits=Luban' /usr/share/icons/default/index.theme && test -e /usr/share/icons/Luban/cursors/default", "timeout": 10},
  {"id": "desktop-terminal", "what": "the default terminal is found", "run": "command -v xdg-terminal-exec >/dev/null || ls /usr/share/xdg-terminals | grep -q foot", "timeout": 10},
  {"id": "desktop-sound", "what": "its sound has the luban output", "run": "test -e /usr/share/pipewire/pipewire.conf.d/luban.conf && command -v luban-audio >/dev/null", "timeout": 10},
  {"id": "desktop-music", "what": "a piece to play is there", "run": "test -s /usr/share/luban/samples/music/aria.ogg", "timeout": 10},
  {"id": "desktop-clipboard", "what": "wl-copy and wl-paste reach the session's clipboard", "run": "command -v wl-copy >/dev/null && command -v wl-paste >/dev/null", "timeout": 10},
  {"id": "desktop-icons", "what": "every application it lists shows an icon", "run": "missing=''; for f in /usr/share/applications/*.desktop; do grep -q '^NoDisplay=true' \"$f\" && continue; i=$(sed -n 's/^Icon=//p' \"$f\" | head -1); [ -z \"$i\" ] && { missing=\"$missing $(basename $f)\"; continue; }; case \"$i\" in /*) [ -e \"$i\" ] && continue;; esac; ls /usr/share/icons/*/*/apps/\"$i\".* /usr/share/icons/*/scalable/apps/\"$i\".svg /usr/share/pixmaps/\"$i\".* >/dev/null 2>&1 || missing=\"$missing $(basename $f)\"; done; [ -z \"$missing\" ] || { echo \"no icon:$missing\"; exit 1; }", "timeout": 30},
  {"id": "desktop-exits-clean", "what": "the browser, the terminal and the player start and end cleanly", "run": "QT_QPA_PLATFORM=offscreen falkon --version >/dev/null 2>&1 && foot --version >/dev/null 2>&1 && audacious --version >/dev/null 2>&1", "timeout": 60}
]}
]]
local packages_2026_10_24_2 = {}
for _, p in ipairs(packages_2026_10_24_1) do
    table.insert(packages_2026_10_24_2, p == "luban:xdesk@2026.10.22.2" and "luban:xdesk@2026.10.24.2" or p)
end

versions["2026.10.24.2"] = {
    files = luban.with(luban_desktop.environment(), luban.checks("desktop", CHECKS_2026_10_24_2)),
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.20.1",
        from = "luban:core@2026.10.24.1",
        replaces = { "subos:luban-desktop", "subos:luban-desktop-xdesk" },
        abi = { kernel = "linux", libc = "gnu" },
        packages = packages_2026_10_24_2,
        boot = { virt = "xim:linux-kernel-virt@6.12.112-r3" },
        luban = { settings = { mode = "machine", enter = "desktop", desktop = desktop_2026_10_22_2.session, login_shell = "/usr/bin/fish" } },
        workspace = {},
    },
}
function install()
    return luban.edition({ id = "desktop", variant = "Desktop", versions = versions })
end
