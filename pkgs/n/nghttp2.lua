package = {
    spec = "2",
    homepage = "https://nghttp2.org",
    name = "nghttp2",
    description = "HTTP/2 C library (libnghttp2, the framing layer libsoup 3 links)",
    maintainers = {"Tatsuhiro Tsujikawa"},
    licenses = {"MIT"},
    repo = "https://github.com/nghttp2/nghttp2",
    docs = "https://nghttp2.org/documentation/",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "network"},
    keywords = {"http2", "http", "network", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- Built from upstream 1.67.1 source (cmake -DENABLE_LIB_ONLY=ON,
            -- shared only) against the xim glib 2.80.0 stack; hosted under
            -- FarnaHerry pending xlings-res adoption. lib-only means no
            -- nghttp/nghttpd/h2load executables -- the h2load suite would drag
            -- in libev/openssl/jansson for zero index consumers.
            ["latest"] = { ref = "1.67.1" },
            ["1.67.1"] = {
                url = "https://github.com/FarnaHerry/nghttp2/releases/download/1.67.1/nghttp2-1.67.1-linux-x86_64.tar.gz",
                sha256 = "ffde9bb054217340e6ef4399d99eaf81047f8d605530460d85f880b4a53f244b",
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
