package = {
    spec = "3",

    homepage = "https://github.com/AOMediaCodec/libavif",
    name = "libavif",
    description = "libavif, the AVIF image library, with its headers (libavif.so.13)",

    authors = {"Alliance for Open Media"},
    licenses = {"BSD-2-Clause"},
    repo = "https://github.com/AOMediaCodec/libavif",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"image", "lib"},
    keywords = {"libavif", "avif", "image", "av1", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            strip = 1,
            -- libavif.so.13 names libaom.so.3 and libc (readelf -d); libaom comes from xim:aom.
            deps = { "xim:glibc", "xim:aom@3.3.0" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.9.3" },
            ["0.9.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libavif/releases/download/0.9.3/libavif-0.9.3-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libavif/releases/download/0.9.3/libavif-0.9.3-linux-x86_64.tar.gz",
                    },
                    sha256 = "f3e3f8de78d7f9120a2a08118ef3ce13c8e399f93befc55e782e79f1602995c1",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libavif/releases/download/0.9.3/libavif-0.9.3-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libavif/releases/download/0.9.3/libavif-0.9.3-linux-aarch64.tar.gz",
                    },
                    sha256 = "835b18df7c4674fefcb082d07e8588ddeeffc262d52008192261015989206409",
                },
            },
        },
    },
}

-- Repacked from conda-forge (libavif 0.9.3, builds `h166bdaf_1` for linux-64 and `h4e544f5_1` for
-- linux-aarch64, glibc 2.17 baseline): libavif.so.13, the header, pkg-config metadata and the licence.
-- 0.9.3 is deliberate: its SONAME libavif.so.13 is the one Playwright's WebKit build links against
-- (`libavif13` of Ubuntu 22.04). NOT auto-updated: a newer libavif has a different SONAME.
-- The release notes of xlings-res/libavif name the source archives and their sha256.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers_tree(dir, "include/avif", "usr/include/avif", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
