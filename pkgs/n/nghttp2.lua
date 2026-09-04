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
            -- libsoup >= 3.2 requires libnghttp2.so.14 for its HTTP/2 support.
            --
            -- Built --enable-lib-only: the nghttp/nghttpd/h2load executables
            -- would pull libev, openssl and jansson into the closure for zero
            -- consumers in this index.
            deps = {
                "xim:glibc@>=2.38",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.70.0" },
            ["1.70.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/nghttp2/releases/download/1.70.0/nghttp2-1.70.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/nghttp2/releases/download/1.70.0/nghttp2-1.70.0-linux-x86_64.tar.gz",
                },
                sha256 = "4343e8ea88063ea13a1e43dc001ca5519b63c9dda9c19c54782d2dbf594e9d30",
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
