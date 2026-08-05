package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "xtrans",
    description = "X transport layer macros and headers (build-time)",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/xtrans",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"xtrans", "graphics", "x11"},

    xpm = {
        linux = {
            deps = {},
            ["latest"] = { ref = "1.5.2" },
            ["1.5.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/xtrans/releases/download/1.5.2/xtrans-1.5.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/xtrans/releases/download/1.5.2/xtrans-1.5.2-linux-x86_64.tar.gz",
                },
                sha256 = "c05a3fe4fd9aa17b2599a016b13c9209ab9fd7d4e0fc660fe3cdea3469d30fc5",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("xtrans-1.5.2", dir)
    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
