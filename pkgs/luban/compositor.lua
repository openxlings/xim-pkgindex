package = {
    spec = "1",

    name = "compositor",
    namespace = "luban",
    description = "Windows without a desktop: labwc alone, the Luban OS window being the shell (launcher, window list)",

    homepage = "https://github.com/openxlings/xim-pkgindex",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "wayland", "luban", "luban-desktop"},
    keywords = {"compositor", "labwc", "wayland", "luban", "minimal"},

    -- The T1 desktop (xlings: 2026-10-18 Luban OS distribution design §7):
    -- several windows, no panel and no background program -- the Luban OS
    -- window starts programs and lists windows (X-Luban-Shell=none). It
    -- also runs one program alone, ending with it (X-Luban-App-Exec, labwc
    -- -S): `luban run --display window` (T0). A composite (design §4.6): luban:labwc's programs, this session and its
    -- configuration, written here; nothing to download.
    programs = {"luban-compositor"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- New with this package: bare (labwc.lua says why).
            deps = { "labwc" },
            ["latest"] = { ref = "2026.10.18.1" },
            ["2026.10.18.1"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.pkgindex.luban_component")

local FILES = {
    { "bin/luban-compositor", [[
#!/bin/sh
# luban:compositor's session: labwc with this package's configuration -- no
# panel, no background; a user's own ~/.config/labwc is not read here.
here=$(readlink -f "$0"); here=${here%/bin/*}
exec labwc -C "$here/etc/xdg/labwc" "$@"
]], "755" },
    { "etc/xdg/labwc/rc.xml", [[
<?xml version="1.0"?>
<!-- luban:compositor: windows, no desktop. -->
<labwc_config>
  <core>
    <decoration>server</decoration>
  </core>
  <keyboard>
    <default />
    <keybind key="W-Return"><action name="Execute" command="xdg-terminal-exec" /></keybind>
    <keybind key="W-q"><action name="Close" /></keybind>
  </keyboard>
  <mouse>
    <default />
  </mouse>
</labwc_config>
]] },
    { "etc/xdg/labwc/menu.xml", [[
<?xml version="1.0"?>
<openbox_menu>
  <menu id="root-menu" label="">
    <item label="Terminal"><action name="Execute" command="xdg-terminal-exec" /></item>
    <separator />
    <item label="Close"><action name="Exit" /></item>
  </menu>
</openbox_menu>
]] },
    { "etc/xdg/labwc/environment", "XKB_DEFAULT_LAYOUT=us\n" },
    { "share/wayland-sessions/compositor.desktop", [[
[Desktop Entry]
Type=Application
Name=Compositor
Comment=Windows without a desktop: the Luban OS window is the shell
Exec=luban-compositor
DesktopNames=labwc;wlroots
X-Opensal-Interfaces=surface pointer keyboard mode
X-Luban-Shell=none
X-Luban-App-Exec=luban-compositor -S
]] },
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    for _, f in ipairs(FILES) do
        local file = path.join(dir, f[1])
        os.mkdir(path.directory(file))
        io.writefile(file, f[2])
        if f[3] then system.exec("chmod " .. f[3] .. " '" .. file .. "'") end
    end
    return os.isfile(path.join(dir, "bin", "luban-compositor"))
end

function config()
    return luban_component.config(package.programs, { "share/wayland-sessions" })
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
