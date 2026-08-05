package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "xcb-proto",
    description = "XML-XCB protocol descriptions (build-time)",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/proto/xcb-proto",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"xcb-proto", "graphics", "x11"},

    xpm = {
        linux = {
            deps = {},
            ["latest"] = { ref = "1.17.0" },
            ["1.17.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/xcb-proto/releases/download/1.17.0/xcb-proto-1.17.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/xcb-proto/releases/download/1.17.0/xcb-proto-1.17.0-linux-x86_64.tar.gz",
                },
                sha256 = "73bf364289efe8791bb4a8a3046cb2256a9953021797ee730a2678d429d3f2e4",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("xcb-proto-1.17.0", dir)
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
