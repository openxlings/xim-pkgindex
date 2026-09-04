package = {
    spec = "2",
    homepage = "https://gitlab.freedesktop.org/xorg/lib/libxdamage",
    name = "libXdamage",
    description = "X11 damaged region extension library",
    maintainers = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxdamage",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "x11"},
    keywords = {"xdamage", "x11", "damage", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- The one X11 client library GTK 4's X11 backend needs that this
            -- index did not have. Measured on the host's own libgtk-4.so.1:
            -- `libXdamage.so.1` sits in its DT_NEEDED beside libXi, libXext,
            -- libXcursor, libXfixes, libXrandr and libXinerama -- and those six
            -- were already packaged.
            deps = {
                "xim:glibc@>=2.38",
                "xim:libX11@>=1.8",
                "xim:libXfixes@>=6.0",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.1.7" },
            ["1.1.7"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXdamage/releases/download/1.1.7/libXdamage-1.1.7-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXdamage/releases/download/1.1.7/libXdamage-1.1.7-linux-x86_64.tar.gz",
                },
                sha256 = "f69db67d3c39090a27a69ad5af5ade951c0dc9099ae624be58600c6ab626d9bb",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    sysroot.adopt_payload()

    selfcontain.seal(pkginfo.install_dir())
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    sysroot.declare_pkgconfig(idir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
