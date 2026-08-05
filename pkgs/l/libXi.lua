package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXi",
    description = "X Input Extension client library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXi",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxi", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "xim:libXext@>=1.3", "xim:libXfixes@>=6.0" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.8.2" },
            ["1.8.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXi/releases/download/1.8.2/libXi-1.8.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXi/releases/download/1.8.2/libXi-1.8.2-linux-x86_64.tar.gz",
                },
                sha256 = "3f297ef4c3519797570f3420c4ce08c0b085efa80d6c04c97eea586990c19ee5",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXi-1.8.2", dir)
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
