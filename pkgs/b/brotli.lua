package = {
    spec = "2",

    homepage = "https://github.com/google/brotli",
    name = "brotli",
    description = "libbrotlicommon, libbrotlidec and libbrotlienc, the Brotli compression libraries, with their headers",

    authors = {"Google"},
    licenses = {"MIT"},
    repo = "https://github.com/google/brotli",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compression", "lib"},
    keywords = {"brotli", "libbrotli", "compression", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- The libraries need libc.so.6 (libbrotlidec and libbrotlienc also name libbrotlicommon.so.1, in this payload);
            -- GLIBC_2.17 at most (readelf -d, objdump -T).
            deps = { "xim:glibc" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.2.0" },
            ["1.2.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/brotli/releases/download/1.2.0/brotli-1.2.0-r1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/brotli/releases/download/1.2.0/brotli-1.2.0-r1-linux-x86_64.tar.gz",
                    },
                    sha256 = "0b20a7cc550db8f1d2487df6a0194a91fe06ed799bb348d1d9fe197e5027de6c",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/brotli/releases/download/1.2.0/brotli-1.2.0-r1-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/brotli/releases/download/1.2.0/brotli-1.2.0-r1-linux-aarch64.tar.gz",
                    },
                    sha256 = "07f52426c97dbf9c4faf27403be3e198a8ddf4094062f8de5e658aeb2ee3c0b4",
                },
            },
        },
    },
}

-- Repacked from conda-forge (1.2.0, linux-64 and linux-aarch64 builds, glibc
-- 2.17 baseline): the shared libraries, headers, pkg-config metadata and
-- licences. Qt's QtNetwork loads libbrotlidec.so.1 to decode Brotli-compressed HTTP responses. The release notes of xlings-res/brotli name the source
-- archives and their sha256.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("brotli-" .. pkginfo.version(), dir)
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers_tree(dir, "include/brotli", "usr/include/brotli", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
