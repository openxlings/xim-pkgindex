package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXext",
    description = "X11 miscellaneous extensions library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXext",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxext", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "libX11@>=1.8" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.3.6" },
            ["1.3.6"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXext/releases/download/1.3.6/libXext-1.3.6-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXext/releases/download/1.3.6/libXext-1.3.6-linux-x86_64.tar.gz",
                },
                sha256 = "d7593a61cf640612f0b9af2a2b789913fef8f5717decdee8af0e487859d49f5d",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXext-1.3.6", dir)
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
