package = {
    spec = "2",
    homepage = "https://libjpeg-turbo.org",
    name = "libjpeg-turbo",
    description = "High-speed JPEG codec (libjpeg API/ABI compatible, SIMD-accelerated)",
    maintainers = {"libjpeg-turbo contributors"},
    licenses = {"IJG", "BSD-3-Clause", "Zlib"},
    repo = "https://github.com/libjpeg-turbo/libjpeg-turbo",
    docs = "https://libjpeg-turbo.org/Documentation",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "graphics"},
    keywords = {"jpeg", "image", "codec", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- Built from upstream 3.1.2 source (cmake, -DWITH_JPEG8=0, shared
            -- only) against the xim glib 2.80.0 stack; hosted under
            -- FarnaHerry pending adoption into the xlings-res mirrors (the
            -- asset name follows the xlings-res convention, so adoption is a
            -- pure source swap). Ships libjpeg.so.62 (the jpeg6b-compatible
            -- ABI gdk-pixbuf links) plus libturbojpeg.so.0.
            ["latest"] = { ref = "3.1.2" },
            ["3.1.2"] = {
                url = "https://github.com/FarnaHerry/libjpeg-turbo/releases/download/3.1.2/libjpeg-turbo-3.1.2-linux-x86_64.tar.gz",
                sha256 = "1732d7301bfdf68b10a4e49a8034a636c9a38fc9c773ba5bd57f240b46d53933",
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
    -- Declared assets (headers/libs/pkgconfig) are reclaimed by xlings; see
    -- glib.lua for the rationale. Nothing by hand.
    return true
end
