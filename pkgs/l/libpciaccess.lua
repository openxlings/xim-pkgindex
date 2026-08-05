package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libpciaccess",
    description = "Generic PCI device access library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libpciaccess",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libpciaccess", "graphics", "gl"},

    xpm = {
        linux = {
            deps = { "xim:zlib@>=1.2" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.18.1" },
            ["0.18.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libpciaccess/releases/download/0.18.1/libpciaccess-0.18.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libpciaccess/releases/download/0.18.1/libpciaccess-0.18.1-linux-x86_64.tar.gz",
                },
                sha256 = "cf45c0441095e92ed8927f0496a9fe1e4ddb1bb606ec61535e9f81e580c6dade",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libpciaccess-0.18.1", dir)
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
