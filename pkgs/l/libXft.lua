package = {
    spec = "2",
    homepage = "https://gitlab.freedesktop.org/xorg/lib/libxft",
    name = "libXft",
    description = "X FreeType client-side font library",
    maintainers = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxft",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "x11", "font"},
    keywords = {"xft", "x11", "font", "freetype", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- Packaged for the same reason as libthai: pango's published .pc
            -- names `xft >= 2.0.0` in Requires.private, pkg-config resolves
            -- Requires.private before it answers anything, and nothing in this
            -- index provided it -- so `pkg-config --cflags pango` failed and
            -- took gtk4's configure with it.
            --
            -- Note that pango's own payload does NOT link libXft (checked with
            -- readelf: libpango-1.0.so.0 names glib, gobject, gio, fribidi,
            -- libthai and harfbuzz, and no X library at all). Supplying what
            -- upstream's metadata asks for is still the better answer than
            -- editing that metadata to say it does not.
            deps = {
                "xim:glibc@>=2.38",
                "xim:libX11@>=1.8",
                "xim:libXrender@>=0.9",
                "xim:freetype@>=2.13",
                "xim:fontconfig@>=2.15",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.3.9" },
            ["2.3.9"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXft/releases/download/2.3.9/libXft-2.3.9-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXft/releases/download/2.3.9/libXft-2.3.9-linux-x86_64.tar.gz",
                },
                sha256 = "1ed4776e4dd641baf74921a71cc8296b67d66ee5c498baf7041628c87d6080f6",
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
