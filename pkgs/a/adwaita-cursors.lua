package = {
    spec = "1",

    name = "adwaita-cursors",
    description = "GNOME's Adwaita cursor theme (24 to 96 pixels), the default cursor theme of a Luban desktop",

    homepage = "https://gitlab.gnome.org/GNOME/adwaita-icon-theme",
    repo = "https://gitlab.gnome.org/GNOME/adwaita-icon-theme",
    licenses = {"LGPL-3.0-only", "CC-BY-SA-3.0"},

    type = "package",
    -- Data: the same files whichever machine reads them.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "theme"},
    keywords = {"cursor", "xcursor", "adwaita", "theme", "wayland", "luban"},

    -- The cursors a desktop draws (xlings design 2026-10-16 L §10): the
    -- Xcursor files of adwaita-icon-theme's Adwaita/cursors at the version
    -- named, in share/icons/Adwaita/cursors; the X11 names an X client asks
    -- for (left_ptr, xterm, hand2, watch, ...) are links to the CSS names it
    -- ships; and share/icons/default inherits Adwaita, the theme a client
    -- that names none gets (tools/res/build.sh adwaita-cursors). Windows'
    -- .cur and .ani files are left out.
    xpm = {
        linux = {
            ["latest"] = { ref = "49.0" },
            ["49.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/adwaita-cursors/releases/download/49.0/adwaita-cursors-49.0.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/adwaita-cursors/releases/download/49.0/adwaita-cursors-49.0.tar.gz",
                },
                sha256 = "79038d203015ae78e29f84277be556216b490ce0c8586ed0783e0ce97e893e94",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = path.join(path.directory(pkginfo.install_file()), "adwaita-cursors-" .. pkginfo.version())
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "share", "icons", "Adwaita", "cursors", "default"))
        and os.isfile(path.join(dir, "share", "icons", "default", "index.theme"))
end

-- Data, not a program: the package name is registered so a home knows it has
-- it (a group: it names no program, so it has no shim).
function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
