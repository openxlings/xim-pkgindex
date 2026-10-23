package = {
    spec = "2",

    homepage = "https://firefox-source-docs.mozilla.org/security/nss/",
    name = "nss",
    description = "Network Security Services (libnss3, libssl3, libsmime3, softoken and the built-in root CAs), with headers and pkg-config data",

    licenses = {"MPL-2.0"},
    repo = "https://hg.mozilla.org/projects/nss",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"security", "lib"},
    keywords = {"nss", "tls", "mozilla", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/nss/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/nss/releases/download/${version}/nss-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/nss/releases/download/${version}/nss-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/nss/releases/download/${version}/nss-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/nss/releases/download/${version}/nss-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
            verify = "sha256-sidecar",
        },
    },

    xpm = {
        linux = {
            -- DT_NEEDED outside the payload (readelf -d): libnspr4, libplc4, libplds4, libsqlite3.
            deps = { "xim:glibc", "xim:nspr", "xim:sqlite" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "3.118" },
            ["3.118"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/nss/releases/download/3.118/nss-3.118-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/nss/releases/download/3.118/nss-3.118-linux-x86_64.tar.gz",
                    },
                    sha256 = "2c746858f7ba392fb26dc44e6e3998c70d8c1a2d6b36373eef53710f4fc13248",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/nss/releases/download/3.118/nss-3.118-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/nss/releases/download/3.118/nss-3.118-linux-aarch64.tar.gz",
                    },
                    sha256 = "46c60b4c388641673d866dacfc99b1fe9090492710a15aa5530e30af92a805be",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     nss-3.118-h445c969_0.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: only the .pc files carried one; rewritten to prefix=/usr.
--
-- NSS loads its PKCS#11 modules (libsoftokn3, libnssckbi, libfreebl) by name through
-- NSPR; declare_libs puts them in the subos library view that the sealed RUNPATH
-- ends with, which is where those lookups resolve.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(package.name .. "-" .. pkginfo.version(), dir)
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return os.isfile(dir .. "/lib/libnss3.so")
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
