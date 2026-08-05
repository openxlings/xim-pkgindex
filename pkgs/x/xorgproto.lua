package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "xorgproto",
    description = "X Window System protocol headers (build-time)",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/proto/xorgproto",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"xorgproto", "graphics", "x11"},

    xpm = {
        linux = {
            deps = {},
            ["latest"] = { ref = "2024.1" },
            ["2024.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/xorgproto/releases/download/2024.1/xorgproto-2024.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/xorgproto/releases/download/2024.1/xorgproto-2024.1-linux-x86_64.tar.gz",
                },
                sha256 = "c2c08991786272d1f27b0e1156ac9dc16e1505c98e8bb090a76ddac69eb91901",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("xorgproto-2024.1", dir)
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
