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
            ["latest"] = { ref = "2026.10.21.3" },
            ["2026.10.18.1"] = { min_client = "2026.10.18.1" },
            ["2026.10.19.1"] = { min_client = "2026.10.18.1" },
            ["2026.10.20.1"] = { min_client = "2026.10.20.1" },
            ["2026.10.21.1"] = { min_client = "2026.10.20.1" },
            ["2026.10.21.3"] = { min_client = "2026.10.20.1" },
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

function install()
    return luban.edition({ id = "desktop", variant = "Desktop", versions = versions })
end
