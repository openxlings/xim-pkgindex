package = {
    spec = "2",

    homepage = "https://www.hadrons.org/software/libmd/",
    name = "libmd",
    description = "Message digest functions (MD2/MD4/MD5, SHA-1/2/3, RIPEMD) from BSD systems",

    authors = {"Guillem Jover and contributors"},
    licenses = {"BSD-2-Clause"},
    repo = "https://www.hadrons.org/software/libmd/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"crypto", "lib"},
    keywords = {"libmd", "md5", "sha1", "sha256", "digest", "lib"},

    xpm = {
        linux = {
            deps = { "xim:glibc" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.2.0" },
            ["1.2.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libmd/releases/download/1.2.0/libmd-1.2.0-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libmd/releases/download/1.2.0/libmd-1.2.0-linux-x86_64.tar.gz",
                    },
                    sha256 = "840ce0bb4be3f299bbe4d2ceac1f16fb2a29842bb21f590fb64daa35c055ed67",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libmd/releases/download/1.2.0/libmd-1.2.0-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libmd/releases/download/1.2.0/libmd-1.2.0-linux-aarch64.tar.gz",
                    },
                    sha256 = "841d983e86cb6dcb9a8955c0cbf638d83958cffd1a81de86d1ebf12ac80eb909",
                },
            },
        },
    },
}

-- Relocatable payload repacked from the conda-forge libmd package (1.2.0,
-- linux-64 and linux-aarch64 builds), built against a glibc 2.17 baseline.
-- `licenses` records conda-forge's own about.json value (BSD-2-Clause);
-- upstream's own liblmd.pc `License:` field is more granular ("BSD-3-Clause
-- and BSD-2-Clause and ISC and Beerware", reflecting the several BSD
-- implementations libmd assembles), noted here rather than guessed into
-- the `licenses` set.
--
-- Payload contents: lib/*.so* (a static archive, libmd.a, ships alongside
-- upstream but is out of scope for this payload), include/ (ten flat
-- top-level headers -- md2.h, md4.h, md5.h, ripemd.h, rmd160.h, sha1.h,
-- sha2.h, sha256.h, sha3.h, sha512.h, sha.h -- a package-owned namespace,
-- so config() uses declare_headers rather than the _tree variant), lib/
-- pkgconfig/libmd.pc, licenses/, and PROVENANCE.md. No bin/: libmd ships
-- no command-line tools.
--
-- RPATH, measured with readelf -d: lib/libmd.so.0 already carried
-- RPATH=$ORIGIN. Reapplied explicitly with patchelf --force-rpath
-- (DT_RPATH, not DT_RUNPATH). DT_NEEDED is libc.so.6 only.
--
-- .pc file carries the conda-forge build machine's placeholder-padded
-- prefix; rewritten here to `prefix=/usr` with ${prefix}-relative
-- libdir/includedir.
--
-- PLACEHOLDER AUDIT: no shipped file embeds the build-prefix placeholder
-- pattern (checked with grep over the whole assembled payload).

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libmd-" .. pkginfo.version(), dir)

    selfcontain.seal(dir)

    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name, { type = "group" })

    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)

    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
