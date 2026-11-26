package = {
    spec = "2",

    homepage = "https://aomedia.googlesource.com/aom",
    name = "aom",
    description = "libaom, the AV1 video codec library of the Alliance for Open Media, with its headers",

    authors = {"Alliance for Open Media"},
    licenses = {"BSD-2-Clause"},
    repo = "https://aomedia.googlesource.com/aom",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"codec", "lib"},
    keywords = {"aom", "libaom", "av1", "codec", "video", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- libaom.so.3 needs libc, libm and libpthread (readelf -d), GLIBC_2.17 at most.
            deps = { "xim:glibc" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "3.3.0" },
            ["3.3.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/aom/releases/download/3.3.0/aom-3.3.0-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/aom/releases/download/3.3.0/aom-3.3.0-linux-x86_64.tar.gz",
                    },
                    sha256 = "2eb47777d1a620508f336779749be0940bc2fb503e6c38247c982c7911d87d0e",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/aom/releases/download/3.3.0/aom-3.3.0-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/aom/releases/download/3.3.0/aom-3.3.0-linux-aarch64.tar.gz",
                    },
                    sha256 = "b066169cc051bc5750ea62c125574164834913e43e70e4436e09985a71a1a6f4",
                },
            },
        },
    },
}

-- Repacked from conda-forge (aom 3.3.0, builds `h27087fc_1` for linux-64 and `headf329_1` for
-- linux-aarch64, glibc 2.17 baseline): libaom.so.3, the headers, pkg-config metadata and the licence.
-- Used by libavif 0.9.3. NOT auto-updated: libavif 0.9.3 is built against aom 3.3.x (conda-forge pins
-- `aom >=3.3.0,<3.4.0a0`), and a newer libaom.so.3 minor is a different ABI contract, so a bump is a reviewed change.
-- The release notes of xlings-res/aom name the source archives and their sha256.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("aom-" .. pkginfo.version(), dir)
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers_tree(dir, "include/aom", "usr/include/aom", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
