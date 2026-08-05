package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXau",
    description = "X11 authorisation protocol library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXau",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxau", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "xim:xorgproto@>=2024" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.0.11" },
            ["1.0.11"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXau/releases/download/1.0.11/libXau-1.0.11-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXau/releases/download/1.0.11/libXau-1.0.11-linux-x86_64.tar.gz",
                },
                sha256 = "07df5c69c4e1c9480e0f0e98f18bcb0d9e25990e994f8f77540fb69f6b55dfb5",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXau-1.0.11", dir)
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
