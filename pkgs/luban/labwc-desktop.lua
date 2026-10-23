package = {
    spec = "1",

    name = "labwc-desktop",
    description = "The traditional Luban desktop: labwc with a panel, a launcher, a terminal and fonts (relocatable)",

    homepage = "https://labwc.github.io",
    repo = "https://github.com/labwc/labwc",
    licenses = {"GPL-2.0-only", "MIT", "GPL-2.0-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "wayland"},
    keywords = {"labwc", "wlroots", "wayland", "desktop", "luban", "foot", "fuzzel", "yambar"},

    -- The session the `desktop` edition starts (xlings: Luban OS architecture
    -- design §9.3): labwc, a panel (yambar), a launcher (fuzzel), a terminal
    -- (foot), a background (swaybg), screenshots (grim), Xwayland, DejaVu and
    -- WenQuanYi Zen Hei. One tree with its own musl loader and libraries
    -- (tools/res/build.sh labwc-desktop), so it runs on any root and needs
    -- nothing of it but the kernel. The session is declared the freedesktop
    -- way, share/wayland-sessions/labwc-desktop.desktop, placed in the SubOS's
    -- share; the Luban OS window shows it through opensal-wlr. Its defaults
    -- are in etc/xdg (a user's ~/.config/labwc, foot, fuzzel win).
    programs = {"labwc", "foot", "fuzzel", "yambar", "swaybg", "grim", "Xwayland", "xkbcomp"},
    xvm_enable = true,

    -- How it is checked (xlings design 2026-10-21 §6.1): luban status --check runs
    -- `run` and `launcher`; a desktop session (luban-os-ci L3) the rest.
    extensions = { luban = { checks = {
        { id = "labwc-desktop-runs", what = "its compositor starts", run = "labwc --version", timeout = 20 },
        { id = "labwc-desktop-terminal", what = "its terminal starts", run = "foot --version", timeout = 20 },
    } },


        autoupdate = {
            source = "https://github.com/xlings-res/labwc-desktop/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/labwc-desktop/releases/download/${version}-r1/labwc-desktop-${version}-r1-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/labwc-desktop/releases/download/${version}-r1/labwc-desktop-${version}-r1-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/labwc-desktop/releases/download/${version}-r1/labwc-desktop-${version}-r1-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/labwc-desktop/releases/download/${version}-r1/labwc-desktop-${version}-r1-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
            tag = "${version}-r1",
            verify = "sha256-sidecar",
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "0.7.2" },
            ["0.7.2"] = {
                -- The factory's build r1 (tools/res/build.sh labwc-desktop
                -- 0.7.2-r1): its libraries private (libexec/lib), and no ELF
                -- names a loader outside the tree.
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/labwc-desktop/releases/download/0.7.2-r1/labwc-desktop-0.7.2-r1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/labwc-desktop/releases/download/0.7.2-r1/labwc-desktop-0.7.2-r1-linux-x86_64.tar.gz",
                    },
                    sha256 = "2e20a3cf3b79e0440a1a67ef4252b1aa32104aa49e322f921482eceed21a5bcc",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/labwc-desktop/releases/download/0.7.2-r1/labwc-desktop-0.7.2-r1-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/labwc-desktop/releases/download/0.7.2-r1/labwc-desktop-0.7.2-r1-linux-aarch64.tar.gz",
                    },
                    sha256 = "9599005361ca1f90f93d6bcbd1dd1f7d92514ac4b69cd103d4c8be729319acb8",
                },
                -- Revision 1: install() mends the payload (see there).
                revision = 1,
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- labwc 0.7.2 looks for menu.xml in the first configuration directory it can
-- open and stops there when the file is not in it (src/menu/menu.c, fixed
-- upstream since): with an empty ~/.config the desktop's own menu is never
-- read, and the background menu is labwc's two built-in items. Until the
-- session moves to a newer labwc, the wrapper names this tree's configuration
-- when the user has none of their own; a user's ~/.config/labwc still wins.
local CONFIG_DIR = [[[ -d "${XDG_CONFIG_HOME:-$HOME/.config}/labwc" ] || set -- -C "$here/etc/xdg/labwc" "$@"
]]

-- The background menu: the build's, plus closing the desktop and powering
-- the machine off (tools/res/luban/labwc-desktop/etc/xdg/labwc/menu.xml, which the
-- next build carries itself).
local MENU = [[<?xml version="1.0"?>
<!-- The desktop's menu (a click on the background). "Shut down" powers the
     machine off; in a sandbox there is nothing to power off and it does nothing. -->
<openbox_menu>
  <menu id="root-menu" label="">
    <item label="Terminal"><action name="Execute" command="foot" /></item>
    <item label="Applications"><action name="Execute" command="fuzzel" /></item>
    <separator />
    <item label="Reconfigure"><action name="Reconfigure" /></item>
    <separator />
    <item label="Close desktop"><action name="Exit" /></item>
    <item label="Shut down"><action name="Execute" command="poweroff" /></item>
  </menu>
</openbox_menu>
]]

local function mend(dir)
    local wrapper = path.join(dir, "bin", "labwc")
    local text = io.readfile(wrapper)
    if not text:find('-C "$here/etc/xdg/labwc"', 1, true) then
        local at = text:find("\nexec ", 1, true)
        if not at then return false end
        io.writefile(wrapper, text:sub(1, at) .. CONFIG_DIR .. text:sub(at + 1))
    end
    io.writefile(path.join(dir, "etc", "xdg", "labwc", "menu.xml"), MENU)
    return true
end

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return mend(dir) and os.isfile(path.join(dir, "bin", "labwc"))
       and os.isfile(path.join(dir, "share", "wayland-sessions", "labwc-desktop.desktop"))
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    xvm.add(package.name)
    for _, p in ipairs(package.programs) do
        xvm.add(p, { bindir = bindir, binding = binding })
    end
    -- The session, where a desktop's manager (and the Luban OS window) looks.
    if xvm.files then
        xvm.files{ src = "share/wayland-sessions", dst = "share/wayland-sessions", binding = binding }
    end
    return true
end

function uninstall()
    for _, p in ipairs(package.programs) do xvm.remove(p) end
    xvm.remove(package.name)
    return true
end
