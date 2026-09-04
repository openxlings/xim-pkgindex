package = {
    spec = "2",
    homepage = "http://www.simplesystems.org/libtiff/",
    name = "libtiff",
    description = "TIFF library and utilities (libtiff, libtiffxx and the tiff* tools)",
    maintainers = {"libtiff contributors"},
    licenses = {"libtiff"},
    repo = "https://gitlab.com/libtiff/libtiff",
    docs = "https://libtiff.gitlab.io/libtiff/",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "graphics", "image"},
    keywords = {"tiff", "image", "codec", "lib"},
    programs = {"tiffinfo", "tiffcp", "tiffdump", "tiffset", "tiffsplit", "tiffcmp",
                "tiff2pdf", "tiff2ps", "tiff2rgba", "tiff2bw", "tiffcrop", "tiffdither",
                "tiffmedian", "fax2ps", "fax2tiff", "pal2rgb", "ppm2tiff", "raw2tiff"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- Measured DT_NEEDED of libtiff.so.6: libjpeg.so.62, libz.so.1,
            -- libm, libc. Nothing else, because every optional codec is off.
            deps = {
                "xim:glibc@>=2.38",
                "xim:libjpeg-turbo@>=3.2",
                "xim:zlib@>=1.3",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- GTK 4 loads TIFF textures itself rather than through
            -- gdk-pixbuf: `tiff_dep = dependency('libtiff-4', 'tiff')` at
            -- gtk/meson.build:418, with no `required: false`. So this is not
            -- an optional extra for the gtk4 stack -- without it gtk4 cannot
            -- be configured at all.
            --
            -- webp, lzma, zstd, jbig, lerc and libdeflate are all disabled.
            -- Each would add a package to the closure for a format nothing in
            -- this index asks for; zlib and libjpeg are the two that stay,
            -- and both are already here.
            ["latest"] = { ref = "4.7.2" },
            ["4.7.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libtiff/releases/download/4.7.2/libtiff-4.7.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libtiff/releases/download/4.7.2/libtiff-4.7.2-linux-x86_64.tar.gz",
                },
                sha256 = "49a3d202893498370e11c6c8e506524e65554bb8e9fa6bda74338f66c0550288",
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
