package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXxf86vm",
    description = "X11 XFree86 video mode extension library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXxf86vm",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxxf86vm", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "xim:libXext@>=1.3" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.1.6" },
            ["1.1.6"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXxf86vm/releases/download/1.1.6/libXxf86vm-1.1.6-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXxf86vm/releases/download/1.1.6/libXxf86vm-1.1.6-linux-x86_64.tar.gz",
                },
                sha256 = "916046759e93059d8ec042009d55de5c488e63573677b76b7e919876ead9a5bb",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXxf86vm-1.1.6", dir)
    return true
end

function config()
    xvm.add(package.name)

    -- Headers into the subos sysroot, so a compiler in this subos can find
    -- them. Declared rather than copied: xlings removes them with the package.
    if xvm.files then
        xvm.files{ src = "include", dst = "usr/include",
                   binding = package.name .. "@" .. pkginfo.version() }
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
