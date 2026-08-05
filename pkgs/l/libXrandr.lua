package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXrandr",
    description = "X Resize, Rotate and Reflect extension library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXrandr",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxrandr", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "libXext@>=1.3", "libXrender@>=0.9" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.5.4" },
            ["1.5.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXrandr/releases/download/1.5.4/libXrandr-1.5.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXrandr/releases/download/1.5.4/libXrandr-1.5.4-linux-x86_64.tar.gz",
                },
                sha256 = "ddb17e5c345aa4f28127ccea61d8489b709d53f744ae05755c7808a813a8540a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXrandr-1.5.4", dir)
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
