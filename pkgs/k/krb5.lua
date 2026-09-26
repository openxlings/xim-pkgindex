package = {
    spec = "2",

    homepage = "https://web.mit.edu/kerberos/",
    name = "krb5",
    description = "The MIT Kerberos client libraries (libgssapi_krb5, libkrb5, libk5crypto, libcom_err, libkrb5support), with their headers",

    authors = {"MIT Kerberos Consortium"},
    licenses = {"MIT"},
    repo = "https://github.com/krb5/krb5",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "lib"},
    keywords = {"krb5", "kerberos", "gssapi", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- The libraries need libc.so.6, libresolv.so.2, libdl.so.2, libkeyutils.so.1 (xim:keyutils) and libcrypto.so.3 at OPENSSL_3.0.0 (xim:openssl);
            -- GLIBC_2.17 at most (readelf -d, objdump -T).
            deps = { "xim:glibc", "xim:keyutils", "xim:openssl" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.22.2" },
            ["1.22.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/krb5/releases/download/1.22.2/krb5-1.22.2-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/krb5/releases/download/1.22.2/krb5-1.22.2-linux-x86_64.tar.gz",
                    },
                    sha256 = "f66a46bff36a31a11eb80d57d7e6f6b1d6273cc09148ca11aa5527e6c0515b08",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/krb5/releases/download/1.22.2/krb5-1.22.2-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/krb5/releases/download/1.22.2/krb5-1.22.2-linux-aarch64.tar.gz",
                    },
                    sha256 = "00d7ad4b08364cb3097b8956a2fa15456a8e47dac942e0ef86ff3b605805d6fc",
                },
            },
        },
    },
}

-- Repacked from conda-forge (1.22.2, linux-64 and linux-aarch64 builds, glibc
-- 2.17 baseline): the shared libraries, headers, pkg-config metadata and
-- licences. Qt's QtNetwork loads libgssapi_krb5.so.2 for Negotiate (Kerberos) HTTP authentication. The release notes of xlings-res/krb5 name the source
-- archives and their sha256.

-- PLACEHOLDER AUDIT. conda-forge embeds its padded build prefix in the path
-- strings of libkrb5 and libgssapi_krb5 -- the configuration search path, the
-- plugin directories -- which conda rewrites at install time. The repack makes
-- the same rewrite with the prefix `/`, NUL-padded, so the libraries read
-- `/etc/krb5.conf` as a distribution's do. The KDC, admin and RPC libraries,
-- the plugins and the command-line tools are not included.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("krb5-" .. pkginfo.version(), dir)
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers_tree(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
