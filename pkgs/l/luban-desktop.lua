-- Luban Desktop -- PREVIEW (xlings SubOS design part 2 §9; Luban OS design part 2
-- §2.3): not yet on the date versions, so `luban new` has no short name for it
-- (`luban new box luban-desktop` still makes one). `from` subos:luban-core@0.1.0,
-- so its root is that edition's plus what this one declares; a package or a
-- file both carry is this one's. Nothing to download -- install() writes the template.
--
--   xlings subos new mybox --rootfs --from subos:luban-desktop
package = {
    spec = "1",
    name = "luban-desktop",
    namespace = "subos",
    description = "Luban Desktop: luban-core plus the graphics stack (Mesa, Wayland, X11), fonts and audio",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64"},
    status = "preview",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "desktop", "graphics", "mesa"},

    xpm = {
        linux = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {},
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
}

function install()
    return luban.edition({ id = "desktop", variant = "Desktop", versions = versions })
end
