-- Luban Desktop (xlings SubOS design part 2 §9): `from` subos:luban-core@0.1.0, so its root
-- is that edition's plus what this one declares; a package or a file both
-- carry is this one's. Nothing to download -- install() writes the template.
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
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "desktop", "graphics", "mesa"},

    xpm = {
        linux = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")

local function write(rel, content)
    local file = path.join(pkginfo.install_dir(), rel)
    os.mkdir(path.directory(file))
    local f = io.open(file, "wb")
    f:write(content)
    f:close()
end

local manifest = [[
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
]]

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    write(".xlings.json", manifest)
    write("usr/share/factory/etc/os-release", [[
NAME="Luban"
ID=luban
VARIANT="Desktop"
VARIANT_ID=desktop
VERSION_ID=0.1.0
PRETTY_NAME="Luban Desktop 0.1.0"
HOME_URL="https://github.com/openxlings/xlings"
]])
    log.info("luban-desktop template at %s", pkginfo.install_dir())
    return true
end
