package = {
    spec = "2",
    homepage = "https://gitlab.gnome.org/GNOME/gdk-pixbuf",
    name = "gdk-pixbuf",
    description = "Image loading and pixel-buffer manipulation library (the GDK pixel buffer, GTK stack)",
    maintainers = {"The GNOME Project"},
    licenses = {"LGPL-2.1"},
    repo = "https://gitlab.gnome.org/GNOME/gdk-pixbuf",
    docs = "https://docs.gtk.org/gdk-pixbuf/",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "graphics", "gnome"},
    keywords = {"gdk-pixbuf", "image", "pixbuf", "gtk", "lib"},
    programs = {"gdk-pixbuf-query-loaders", "gdk-pixbuf-pixdata", "gdk-pixbuf-thumbnailer"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- DT_NEEDED of libgdk_pixbuf-2.0.so.0, measured on the payload:
            --   glib stack: libglib-2.0/libgobject-2.0/libgmodule-2.0/libgio-2.0
            --   image codecs (builtin loaders): libpng16.so.16, libjpeg.so.62
            --   base: libc/libm (glibc)
            deps = {
                "xim:glibc@>=2.38",
                "xim:glib@>=2.80",
                "xim:libpng@>=1.6",
                "xim:libjpeg-turbo@>=3.1",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- Built from upstream 2.42.12 source against the xim glib 2.80.0
            -- stack; hosted under FarnaHerry pending xlings-res adoption.
            --
            -- -Dbuiltin_loaders=all links every enabled loader (png, jpeg,
            -- gif, ico, ani, pnm, xpm, xbm, tga) INTO libgdk_pixbuf itself:
            -- no lib/gdk-pixbuf-2.0/2.10.0/loaders/ modules, no loaders.cache,
            -- nothing to query at runtime -- exactly what a sealed subos
            -- wants, since the cache file bakes absolute build-host paths.
            --
            -- Deliberate trims (each is a feature toggle, not a patch):
            --   tiff=disabled     libtiff is not in the index yet
            --   gio_sniffing=false  builtin format signatures instead of GIO
            --                     content-type probing (shared-mime-info is
            --                     not packaged)
            --   introspection/man/tests off.
            ["latest"] = { ref = "2.42.12" },
            ["2.42.12"] = {
                url = "https://github.com/FarnaHerry/gdk-pixbuf/releases/download/2.42.12/gdk-pixbuf-2.42.12-linux-x86_64.tar.gz",
                sha256 = "e3d6ee4de712119674b9907697eb54c6b6f00c95268eb21b99cdb186d7a95aa1",
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
    local srcdir = pkginfo.name() .. "-" .. pkginfo.version() .. "-linux-x86_64"
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())

    selfcontain.seal(pkginfo.install_dir())
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)
    for _, tool in ipairs({"gdk-pixbuf-query-loaders", "gdk-pixbuf-pixdata",
                           "gdk-pixbuf-thumbnailer"}) do
        xvm.add(tool, { bindir = path.join(idir, "bin") })
    end

    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    if not sysroot.declare_headers(idir, "lib/pkgconfig",
                                   "usr/lib/pkgconfig", binding) then
        local sysroot_pc = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
        os.mkdir(sysroot_pc)
        system.exec(string.format(
            "sh -c 'for pc in %s/lib/pkgconfig/*.pc; do [ -f \"$pc\" ] && cp -f \"$pc\" %s/; done'",
            idir, sysroot_pc))
    end
    return true
end

function uninstall()
    xvm.remove("gdk-pixbuf-query-loaders")
    xvm.remove("gdk-pixbuf-pixdata")
    xvm.remove("gdk-pixbuf-thumbnailer")
    xvm.remove(package.name)
    return true
end
