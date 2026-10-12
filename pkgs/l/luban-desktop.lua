-- Luban Desktop: luban-core plus the traditional desktop (xlings: Luban OS
-- architecture design §9.3) -- labwc with a panel, a launcher and a terminal
-- (xim:labwc-desktop, one relocatable tree), shown in the Luban OS window
-- through opensal-wlr. It runs as a machine (usr/share/luban/settings.json:
-- the edition's defaults behind `luban config`), and starts that session.
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
    description = "Luban Desktop: luban-core plus a desktop (labwc, a panel, a launcher, a terminal), shown in the Luban OS window",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "desktop", "graphics", "mesa"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.13.1" },
            ["0.1.0"] = {},
            ["2026.10.13.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")

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
    -- The desktop session and what it runs as; the client that knows both
    -- (a machine's display, the edition's defaults) is 2026.10.13.1.
    ["2026.10.13.1"] = {
        manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.13.1",
  "from": "subos:luban-core@2026.10.11.2",
  "abi": { "kernel": "linux", "libc": "gnu" },
  "packages": [
    "xim:labwc-desktop@0.7.2"
  ],
  "workspace": {}
}
]],
        files = { { "usr/share/luban/settings.json", '{ "mode": "machine", "desktop": "labwc-desktop" }\n' } },
    },
}

-- 0.1.0 names x86_64-only packages: an aarch64 reader refuses it rather than
-- make an environment half.
local recipe_arch = (os.arch and os.arch())
if recipe_arch == "aarch64" or recipe_arch == "arm64" then
    package.xpm.linux["0.1.0"] = nil
    versions["0.1.0"] = nil
end

function install()
    return luban.edition({ id = "desktop", variant = "Desktop", versions = versions })
end
