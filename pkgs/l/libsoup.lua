package = {
    spec = "2",
    homepage = "https://gitlab.gnome.org/GNOME/libsoup",
    name = "libsoup",
    description = "HTTP client/server library for GLib (libsoup-3.0, GTK/GNOME stack)",
    maintainers = {"The GNOME Project"},
    licenses = {"LGPL-2.1"},
    repo = "https://gitlab.gnome.org/GNOME/libsoup",
    docs = "https://libsoup.gnome.org/libsoup-3.0/",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "network", "gnome"},
    keywords = {"libsoup", "http", "soup", "gnome", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- DT_NEEDED of libsoup-3.0.so.0, measured on the payload:
            --   glib stack: libglib-2.0/libgobject-2.0/libgio-2.0
            --   xim deps:   libsqlite3.so.0, libpsl.so.5, libz.so.1,
            --               libnghttp2.so.14
            --   base:       libc (glibc)
            deps = {
                "xim:glibc@>=2.38",
                "xim:glib@>=2.80",
                "xim:sqlite@>=3.53",
                "xim:libpsl@>=0.21",
                "xim:zlib@>=1.3",
                "xim:nghttp2@>=1.67",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- Built from upstream 3.6.6 source against the xim glib 2.80.0
            -- stack; hosted under FarnaHerry pending xlings-res adoption.
            --
            -- KNOWN LIMITATION — HTTPS: TLS in libsoup is a RUNTIME GIO
            -- module (glib-networking → gnutls → nettle/gmp/libtasn1/…),
            -- none of which is in this index yet. Inside a sealed subos,
            -- plain HTTP works; HTTPS fails with "TLS support is not
            -- available". Packaging the glib-networking chain is follow-up
            -- work. Build-time feature trims (not patches): gssapi, ntlm,
            -- brotli, introspection, vapi, docs, tests, sysprof all off.
            ["latest"] = { ref = "3.6.6" },
            ["3.6.6"] = {
                url = "https://github.com/FarnaHerry/libsoup/releases/download/3.6.6/libsoup-3.6.6-linux-x86_64.tar.gz",
                sha256 = "553aefdc5ad8abeba7a1e4de3dd9b22afe11415e53c0b3e88bdd078b4854702b",
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
    xvm.remove(package.name)
    return true
end
