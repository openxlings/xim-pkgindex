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

    -- What Luban shows of it (xlings design 2026-10-19 §5.4; xpkg spec
    -- "extensions"): T1, the lightest traditional desktop.
    extensions = {
        luban = {
            checks = {
                { id = "compositor-runs", what = "it starts", run = "luban-compositor --version", timeout = 20 },
            },
            tier = 1,
            title = { en = "Compositor", zh = "Compositor" },
            summary = { en = "Windows only, no desktop: the Luban OS window is the shell",
                        zh = "只有窗口、没有桌面：Luban OS 窗口就是外壳" },
        },
    },

    -- The T1 desktop (xlings: 2026-10-18 Luban OS distribution design §7):
    -- several windows, no panel and no background program -- the Luban OS
    -- window starts programs and lists windows (X-Luban-Shell=none). It
    -- also runs one program alone, ending with it, filling the output
    -- (X-Luban-App-Exec, labwc -S): `luban run --display window` (T0). A composite (design §4.6): luban:labwc's programs, this session and its
    -- configuration, written here; nothing to download.
    programs = {"luban-compositor"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- New with this package: bare (labwc.lua says why).
            deps = { "luban:labwc" },
            ["latest"] = { ref = "2026.10.18.1" },
            -- 1: its checks written where a system's self-check reads them (xlings design 2026-10-21 §6.1).
            ["2026.10.18.1"] = { revision = 1 },
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
# `--app`: one program alone (`luban run --display window`), filling the
# output undecorated -- the window it is shown in is its window.
here=$(readlink -f "$0"); here=${here%/bin/*}
config="$here/etc/xdg/labwc"
if [ "${1:-}" = --app ]; then shift; config="$here/etc/xdg/labwc-app"; fi
exec labwc -C "$config" "$@"
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
    { "etc/xdg/labwc-app/rc.xml", [[
<?xml version="1.0"?>
<!-- luban:compositor, one program alone: its windows fill the output, undecorated. -->
<labwc_config>
  <core>
    <decoration>server</decoration>
  </core>
  <windowRules>
    <windowRule identifier="*" serverDecoration="no"><action name="Maximize" /></windowRule>
  </windowRules>
  <keyboard>
    <default />
  </keyboard>
  <mouse>
    <default />
  </mouse>
</labwc_config>
]] },
    { "etc/xdg/labwc-app/environment", "XKB_DEFAULT_LAYOUT=us\n" },
    { "share/wayland-sessions/compositor.desktop", [[
[Desktop Entry]
Type=Application
Name=Compositor
Comment=Windows without a desktop: the Luban OS window is the shell
Exec=luban-compositor
DesktopNames=labwc;wlroots
X-Opensal-Interfaces=surface pointer keyboard mode
X-Luban-Shell=none
X-Luban-App-Exec=luban-compositor --app -S
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
    return luban_component.config(package.programs, { "share/wayland-sessions" }, package.extensions.luban.checks)
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
