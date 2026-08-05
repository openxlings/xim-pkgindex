package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libX11",
    description = "Core X11 client library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libX11",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libx11", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "libxcb@>=1.17", "xorgproto@>=2024" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.8.10" },
            ["1.8.10"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libX11/releases/download/1.8.10/libX11-1.8.10-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libX11/releases/download/1.8.10/libX11-1.8.10-linux-x86_64.tar.gz",
                },
                sha256 = "03d9242551aef99f920ec1ce7aaa36227b9034f7f9b1d8d3ea44b21759f0bbe5",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libX11-1.8.10", dir)
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
