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
    name = "luban-desktop",
    namespace = "subos",
    description = "Luban Desktop: luban-core plus a ready desktop (xdesk classic) and the tools people reach for, shown in the Luban OS window",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "desktop", "xdesk", "wayland"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.16.1" },
            ["0.1.0"] = {},
            ["2026.10.13.1"] = {},
            ["2026.10.15.1"] = {},
            ["2026.10.16.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")
import("xim.pkgindex.luban_desktop")

local recipe_arch = (os.arch and os.arch())
local aarch64 = recipe_arch == "aarch64" or recipe_arch == "arm64"

local versions = {
    ["0.1.0"] = { manifest = [[
{
  "subos_kind": "rootfs",
  "from": "subos:luban-core@0.1.0",
  "packages": [
    "xim:mesa@25.0.7.2",
    "xim:wayland@1.23.1",
    "xim:libX11@1.8.10",
    "xim:fontconfig@2.15.0.1",
    "xim:freetype@2.13.2",
    "xim:alsa-lib@1.2.11"
  ],
  "workspace": {}
}
]] },
    -- The desktop that is ready to use: xdesk classic (aarch64: labwc, until
    -- xdesk is released there), the environment, its defaults.
    ["2026.10.13.1"] = {
        manifest = luban_desktop.manifest(aarch64 and "aarch64" or "x86_64", "subos:luban-core@2026.10.11.2"),
        files = luban_desktop.files(aarch64 and "labwc-desktop" or "xdesk-classic"),
    },
    -- On Luban Core 2026.10.15.1: gh beside git.
    ["2026.10.15.1"] = {
        manifest = luban_desktop.manifest(aarch64 and "aarch64" or "x86_64", "subos:luban-core@2026.10.15.1"),
        files = luban_desktop.files(aarch64 and "labwc-desktop" or "xdesk-classic"),
    },
    -- On Luban Core 2026.10.16.1 (terminfo, the not-found hint, mcpp's
    -- system configuration): a default cursor theme, and its checks.
    ["2026.10.16.1"] = {
        manifest = luban_desktop.manifest(aarch64 and "aarch64" or "x86_64", "subos:luban-core@2026.10.16.1", luban_desktop.since_2026_10_16),
        files = luban_desktop.files(aarch64 and "labwc-desktop" or "xdesk-classic", { luban.checks("desktop", luban_desktop.CHECKS) }),
    },
}

-- 0.1.0 names x86_64-only packages: an aarch64 reader refuses it rather than
-- make an environment half.
if aarch64 then
    package.xpm.linux["0.1.0"] = nil
    versions["0.1.0"] = nil
end

function install()
    return luban.edition({ id = "desktop", variant = "Desktop", versions = versions })
end
