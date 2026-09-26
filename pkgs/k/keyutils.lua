package = {
    spec = "2",

    homepage = "https://people.redhat.com/~dhowells/keyutils/",
    name = "keyutils",
    description = "libkeyutils, the Linux key management library, with its header",

    authors = {"David Howells"},
    licenses = {"GPL-2.0-or-later", "LGPL-2.1-or-later"},
    repo = "https://git.kernel.org/pub/scm/linux/kernel/git/dhowells/keyutils.git",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "lib"},
    keywords = {"keyutils", "libkeyutils", "keyring", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- The libraries need libc.so.6;
            -- GLIBC_2.17 at most (readelf -d, objdump -T).
            deps = { "xim:glibc" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.6.3" },
            ["1.6.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/keyutils/releases/download/1.6.3/keyutils-1.6.3-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/keyutils/releases/download/1.6.3/keyutils-1.6.3-linux-x86_64.tar.gz",
                    },
                    sha256 = "5fca91f196d80ef0d21d7d734208d9aa37105f4876d593846746fb91e00856c3",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/keyutils/releases/download/1.6.3/keyutils-1.6.3-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/keyutils/releases/download/1.6.3/keyutils-1.6.3-linux-aarch64.tar.gz",
                    },
                    sha256 = "fc565d405ae5ea3f75426b17c6cab99f746ce13ef9939c6cb9e1e7a652be003c",
                },
            },
        },
    },
}

-- Repacked from conda-forge (1.6.3, linux-64 and linux-aarch64 builds, glibc
-- 2.17 baseline): the shared libraries, headers, pkg-config metadata and
-- licences. MIT Kerberos (xim:krb5) loads libkeyutils.so.1 for its keyring credential cache. The release notes of xlings-res/keyutils name the source
-- archives and their sha256.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("keyutils-" .. pkginfo.version(), dir)
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
