package = {
    spec = "2",

    homepage = "https://gitlab.freedesktop.org/glvnd/libglvnd",
    name = "libglvnd",
    description = "The GL Vendor-Neutral Dispatch library",

    authors = {"NVIDIA Corporation", "libglvnd contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/glvnd/libglvnd",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libglvnd", "graphics", "gl"},

    xpm = {
        linux = {
            deps = { "libX11@>=1.8", "libXext@>=1.3" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.7.0" },
            ["1.7.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libglvnd/releases/download/1.7.0/libglvnd-1.7.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libglvnd/releases/download/1.7.0/libglvnd-1.7.0-linux-x86_64.tar.gz",
                },
                sha256 = "07366016ef25ec20436df65bf94f0dee758d41ec34d0723056690d5c899bf8c8",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libglvnd-1.7.0", dir)
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
