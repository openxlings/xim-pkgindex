package = {
    spec = "2",
    homepage = "https://ebassi.github.io/graphene/",
    name = "graphene",
    description = "Thin layer of graphic data types (points, vectors, matrices) with SIMD support",
    maintainers = {"Emmanuele Bassi"},
    licenses = {"MIT"},
    repo = "https://github.com/ebassi/graphene",
    docs = "https://ebassi.github.io/graphene/docs/",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "graphics"},
    keywords = {"graphene", "simd", "math", "gtk", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- GTK 4 requires graphene >= 1.10 and uses it for every point,
            -- rect and matrix in the render node tree. Built with the gobject
            -- half enabled (graphene-gobject-1.0.pc), which is the half gtk4
            -- actually asks for.
            deps = {
                "xim:glibc@>=2.38",
                "xim:glib@>=2.88",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.10.8" },
            ["1.10.8"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/graphene/releases/download/1.10.8/graphene-1.10.8-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/graphene/releases/download/1.10.8/graphene-1.10.8-linux-x86_64.tar.gz",
                },
                sha256 = "f57d7059b2bba93dfb2a7b77e974bdd1943f3d461d917430ee2734f1f85427cb",
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
