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
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "bin", "labwc"))
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
