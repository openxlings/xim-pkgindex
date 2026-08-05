package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXcursor",
    description = "X cursor management library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXcursor",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxcursor", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "xim:libXrender@>=0.9", "xim:libXfixes@>=6.0" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.2.3" },
            ["1.2.3"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXcursor/releases/download/1.2.3/libXcursor-1.2.3-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXcursor/releases/download/1.2.3/libXcursor-1.2.3-linux-x86_64.tar.gz",
                },
                sha256 = "b85ad01f2ba44265921fd0f5133254b5bd4068e7dfc29368c8b96ad93b332bba",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXcursor-1.2.3", dir)
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
