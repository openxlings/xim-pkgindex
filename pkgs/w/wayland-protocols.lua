package = {
    spec = "2",

    homepage = "https://wayland.freedesktop.org",
    name = "wayland-protocols",
    description = "Wayland protocol extension definitions (build-time)",

    authors = {"Wayland contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/wayland/wayland-protocols",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"wayland-protocols", "graphics", "gl"},

    xpm = {
        linux = {
            deps = {},
            ["latest"] = { ref = "1.38" },
            ["1.38"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/wayland-protocols/releases/download/1.38/wayland-protocols-1.38-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/wayland-protocols/releases/download/1.38/wayland-protocols-1.38-linux-x86_64.tar.gz",
                },
                sha256 = "41df27e9b1ad57d7bbf5ed47eade4f71495ddd132417590c0c39185c5559ac0c",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("wayland-protocols-1.38", dir)
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
