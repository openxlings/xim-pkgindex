package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libxshmfence",
    description = "Shared-memory fences for DRI3",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxshmfence",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxshmfence", "graphics", "x11"},

    xpm = {
        linux = {
            deps = {},
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.3.2" },
            ["1.3.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libxshmfence/releases/download/1.3.2/libxshmfence-1.3.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libxshmfence/releases/download/1.3.2/libxshmfence-1.3.2-linux-x86_64.tar.gz",
                },
                sha256 = "dce29073e3225e2001ecba00b115cfee9062b85ef4e15a454db3b671454fdc9f",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libxshmfence-1.3.2", dir)
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
