package = {
    spec = "2",
    homepage = "https://github.com/anholt/libepoxy",
    name = "libepoxy",
    description = "Library for handling OpenGL function pointer management",
    maintainers = {"Eric Anholt", "Emmanuele Bassi"},
    licenses = {"MIT"},
    repo = "https://github.com/anholt/libepoxy",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "graphics", "opengl"},
    keywords = {"epoxy", "opengl", "gl", "egl", "glx", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- GTK 4's GL renderer talks to the driver through epoxy rather
            -- than dlopen-ing libGL itself. Built with glx and egl on, against
            -- the index's libglvnd -- epoxy dispatches at runtime, so the
            -- vendor library it ends up calling is still whatever the host's
            -- GPU stack provides via libglvnd.
            deps = {
                "xim:glibc@>=2.38",
                "xim:libglvnd@>=1.7",
                "xim:libX11@>=1.8",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.5.10" },
            ["1.5.10"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libepoxy/releases/download/1.5.10/libepoxy-1.5.10-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libepoxy/releases/download/1.5.10/libepoxy-1.5.10-linux-x86_64.tar.gz",
                },
                sha256 = "238b011baa5ed7b2f7118c0b04c22c20872a41c480a566a882bc4c4b115f6fdb",
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
