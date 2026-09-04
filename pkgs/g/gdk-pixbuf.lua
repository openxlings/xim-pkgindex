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
    programs = {"gdk-pixbuf-query-loaders", "gdk-pixbuf-pixdata", "gdk-pixbuf-thumbnailer", "gdk-pixbuf-csource"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- One of the two libraries #749 named as missing under huxerui.
            --
            -- -Dbuiltin_loaders=all links every enabled loader (png, jpeg,
            -- gif, ico, ani, pnm, xpm, xbm, tga, bmp, ...) INTO
            -- libgdk_pixbuf itself: no lib/gdk-pixbuf-2.0/2.10.0/loaders/
            -- modules and no loaders.cache, which matters because that cache
            -- file records absolute build-host paths and would be wrong on
            -- every machine but the one that generated it.
            --
            -- Deliberate trims, all upstream options rather than patches:
            --   glycin=disabled   the Rust image stack is not in this index,
            --                     and 2.44 wraps the option in
            --                     enable_auto_if(linux) -- so on Linux `auto`
            --                     means REQUIRED and meson stops dead.
            --   gio_sniffing=false  builtin format signatures instead of GIO
            --                     content-type probing (shared-mime-info is
            --                     not packaged)
            --   introspection/man/tests/docs off.
            -- Measured DT_NEEDED of libgdk_pixbuf-2.0.so.0, not a guess:
            --   glib stack: libglib-2.0 / libgobject-2.0 / libgmodule-2.0 / libgio-2.0
            --   codecs (builtin loaders): libpng16.so.16, libjpeg.so.62,
            --                              libtiff.so.6
            --   base: libc, libm (glibc)
            -- zlib is deliberately absent: libpng and libtiff both need it and
            -- both declare it, and nothing in this payload names it directly.
            deps = {
                "xim:glibc@>=2.38",
                "xim:glib@>=2.88",
                "xim:libpng@>=1.6",
                "xim:libjpeg-turbo@>=3.2",
                "xim:libtiff@>=4.7",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.44.8" },
            ["2.44.8"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/gdk-pixbuf/releases/download/2.44.8/gdk-pixbuf-2.44.8-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/gdk-pixbuf/releases/download/2.44.8/gdk-pixbuf-2.44.8-linux-x86_64.tar.gz",
                },
                sha256 = "6d67043d56f72400433d45926b410207223348e4e7b0c5dc41698b2c7392b70e",
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

    -- share/thumbnailers/*.thumbnailer is generated from --prefix and ships
    -- absolute host paths:
    --
    --     TryExec=/usr/bin/gdk-pixbuf-thumbnailer
    --     Exec=/usr/bin/gdk-pixbuf-thumbnailer -s %s %u %o
    --
    -- Nothing inside a sealed subos reads a .thumbnailer -- it is a desktop
    -- environment's file format -- so this is not a startup failure waiting
    -- to happen. It is still a shipped file naming a path that belongs to the
    -- host, in a payload whose whole claim is that it names none, and the
    -- install-time path is known here. Point it at the binary we actually
    -- installed rather than deleting the file and the feature with it.
    local thumbdir = path.join(pkginfo.install_dir(), "share", "thumbnailers")
    if os.isdir(thumbdir) then
        system.exec(string.format(
            "sh -c 'for t in %s/*.thumbnailer; do [ -f \"$t\" ] && "
            .. "sed -i \"s|/usr/bin/|%s/bin/|g\" \"$t\"; done'",
            thumbdir, pkginfo.install_dir()))
    end

    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)
    for _, tool in ipairs({"gdk-pixbuf-query-loaders",
                           "gdk-pixbuf-pixdata",
                           "gdk-pixbuf-thumbnailer",
                           "gdk-pixbuf-csource"}) do
        xvm.add(tool, { bindir = path.join(idir, "bin") })
    end


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
    xvm.remove("gdk-pixbuf-query-loaders")
    xvm.remove("gdk-pixbuf-pixdata")
    xvm.remove("gdk-pixbuf-thumbnailer")
    xvm.remove("gdk-pixbuf-csource")
    xvm.remove(package.name)
    return true
end
