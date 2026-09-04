package = {
    spec = "2",
    homepage = "https://www.gtk.org",
    name = "gtk4",
    description = "GTK 4 — cross-platform widget toolkit for graphical user interfaces",
    maintainers = {"The GNOME Project"},
    licenses = {"LGPL-2.1"},
    repo = "https://gitlab.gnome.org/GNOME/gtk",
    docs = "https://docs.gtk.org/gtk4/",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "gui", "gnome"},
    keywords = {"gtk", "gtk4", "gui", "widget", "toolkit", "gnome"},
    programs = {"gtk4-builder-tool", "gtk4-encode-symbolic-svg", "gtk4-image-tool",
                "gtk4-launch", "gtk4-path-tool", "gtk4-query-settings",
                "gtk4-rendernode-tool", "gtk4-update-icon-cache"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- The third and last of the libraries #749 recorded as missing
            -- under huxerui, and the reason the other twelve packages in this
            -- change exist.
            --
            -- WHY 4.16 AND NOT 4.18+
            --
            -- Not caution -- arithmetic. GTK 4.18 raised its floors to
            -- pango >= 1.56, cairo >= 1.18.2 and harfbuzz >= 8.4 (its
            -- meson.build states each), and this index publishes pango 1.52.1
            -- and harfbuzz 8.3.0. 4.16.13 is the newest release whose declared
            -- requirements this index actually meets. Moving past it means
            -- republishing pango and harfbuzz as well, which is a larger
            -- change than adding gtk4 and belongs in its own PR.
            --
            -- Backends: x11 and wayland both on. vulkan, gstreamer media and
            -- cups printing are off -- the first is optional for 4.16's
            -- renderer and the other two have no packaged dependency here.
            -- The measured DT_NEEDED closure of libgtk-4.so.1, mapped to
            -- providers. Enumerated with readelf on the built payload, not
            -- copied from a wiki page:
            --
            --   glib stack   libglib-2.0 libgobject-2.0 libgio-2.0 libgmodule-2.0
            --   text         libpango-1.0 libpangocairo-1.0 libpangoft2-1.0
            --                libharfbuzz libharfbuzz-subset libfribidi libfontconfig
            --   2D           libcairo libcairo-gobject libcairo-script-interpreter
            --   images       libgdk_pixbuf-2.0 libpng16 libtiff libjpeg
            --   GL / math    libepoxy libgraphene-1.0
            --   X11          libX11 libXi libXext libXcursor libXdamage
            --                libXfixes libXrandr libXinerama
            --   wayland      libwayland-client libwayland-egl libxkbcommon
            --   base         libc libm (glibc)
            --
            -- freetype and zlib are deliberately absent: nothing in this
            -- payload names them directly. pango and libtiff do, and both
            -- declare them.
            --
            -- The floors on cairo and harfbuzz are not decoration: 1.18.0 has
            -- no libcairo-gobject and 8.3.0 has no libharfbuzz-subset, and
            -- both appear in the list above.
            deps = {
                "xim:glibc@>=2.38",
                "xim:glib@>=2.88",
                "xim:cairo@>=1.18.4",
                "xim:pango@>=1.52",
                "xim:harfbuzz@>=14.4",
                "xim:fribidi@>=1.0",
                "xim:fontconfig@>=2.15",
                "xim:gdk-pixbuf@>=2.44",
                "xim:graphene@>=1.10",
                "xim:libepoxy@>=1.5",
                "xim:libpng@>=1.6",
                "xim:libtiff@>=4.7",
                "xim:libjpeg-turbo@>=3.2",
                "xim:libX11@>=1.8",
                "xim:libXext@>=1.3",
                "xim:libXi@>=1.8",
                "xim:libXcursor@>=1.2",
                "xim:libXdamage@>=1.1",
                "xim:libXfixes@>=6.0",
                "xim:libXrandr@>=1.5",
                "xim:libXinerama@>=1.1",
                "xim:libxkbcommon@>=1.7",
                "xim:wayland@>=1.23",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "4.16.13" },
            ["4.16.13"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/gtk4/releases/download/4.16.13/gtk4-4.16.13-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/gtk4/releases/download/4.16.13/gtk4-4.16.13-linux-x86_64.tar.gz",
                },
                sha256 = "d0231c393bdec7a4df5fde2b4657a9e666051f4e17ceb5d41360a3e2099c73f2",
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
    for _, tool in ipairs(package.programs or {}) do
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
    for _, tool in ipairs(package.programs or {}) do
        xvm.remove(tool)
    end
    xvm.remove(package.name)
    return true
end
