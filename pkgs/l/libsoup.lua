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
            -- The other library #749 named. 3.6.6 is the newest STABLE
            -- libsoup: GNOME uses odd minors for development series, so 3.7.x
            -- is not a candidate.
            --
            -- KNOWN LIMITATION - HTTPS. TLS in libsoup is a RUNTIME GIO
            -- module (glib-networking -> gnutls -> nettle/gmp/libtasn1/
            -- libidn2/libunistring), none of which is in this index. Inside a
            -- sealed subos plain HTTP works and HTTPS fails with "TLS support
            -- is not available". Packaging that chain is follow-up work and is
            -- tracked as such -- it is not a defect in this payload.
            --
            -- Build-time trims (options, not patches): gssapi, ntlm, brotli,
            -- introspection, vapi, docs, tests, sysprof all off.
            deps = {
                "xim:glibc@>=2.38",
                "xim:glib@>=2.88",
                "xim:sqlite@>=3.53",
                "xim:libpsl@>=0.23",
                "xim:zlib@>=1.3",
                "xim:nghttp2@>=1.70",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "3.6.6" },
            ["3.6.6"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libsoup/releases/download/3.6.6/libsoup-3.6.6-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libsoup/releases/download/3.6.6/libsoup-3.6.6-linux-x86_64.tar.gz",
                },
                sha256 = "3130630bc202dfde599b5a3608a7b48a64cf4e97225da1d1d5ad2ab080ca624c",
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
