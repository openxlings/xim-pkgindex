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
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("xorgproto-2024.1", dir)
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Headers into the subos sysroot, so a compiler in this subos can build
    -- against this package, not only run it. Declared rather than copied, so
    -- xlings removes them with the package.
    --
    -- _tree, not declare_headers: eight packages in this stack contribute to
    -- one `X11/`, and declaring that directory places it as a single asset --
    -- rename(2) over the sysroot's copy, so the last install wins and the
    -- other seven vanish. See libs/sysroot.lua for why neither of the
    -- non-recursive helpers can express a shared namespace.
    if not sysroot.declare_headers_tree(pkginfo.install_dir(), "include",
                                        "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(pkginfo.install_dir(), "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
