package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libxcb",
    description = "X protocol C-language Binding",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxcb",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxcb", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "libXau@>=1.0", "libXdmcp@>=1.1" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.17.0" },
            ["1.17.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libxcb/releases/download/1.17.0/libxcb-1.17.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libxcb/releases/download/1.17.0/libxcb-1.17.0-linux-x86_64.tar.gz",
                },
                sha256 = "561b2f8f6d1452f211cdb9023efc3ecde8c365f1eba181bd2d183357b85f484a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libxcb-1.17.0", dir)
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
