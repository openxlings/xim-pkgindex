package = {
    spec = "2",

    homepage = "https://github.com/tpm2-software/tpm2-tss",
    name = "tpm2-tss",
    description = "The TPM2 Software Stack libraries (libtss2-esys, -sys, -mu, -tcti-device)",

    licenses = {"BSD-2-Clause"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"security", "lib"},
    keywords = {"tpm2", "tss", "tpm", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/tpm2-tss/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/tpm2-tss/releases/download/${version}/tpm2-tss-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/tpm2-tss/releases/download/${version}/tpm2-tss-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/tpm2-tss/releases/download/${version}/tpm2-tss-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/tpm2-tss/releases/download/${version}/tpm2-tss-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libcrypto (OpenSSL 3).
            deps = { "xim:glibc", "xim:openssl" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "4.1.3" },
            ["4.1.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/tpm2-tss/releases/download/4.1.3/tpm2-tss-4.1.3-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/tpm2-tss/releases/download/4.1.3/tpm2-tss-4.1.3-linux-x86_64.tar.gz",
                    },
                    sha256 = "93734f033e42067b972c5663306d48ca6a3360247c2ce84ec025afde85288c08",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/tpm2-tss/releases/download/4.1.3/tpm2-tss-4.1.3-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/tpm2-tss/releases/download/4.1.3/tpm2-tss-4.1.3-linux-aarch64.tar.gz",
                    },
                    sha256 = "aeaa697d07fb477ad6d9ff4ca705dbc7f3f81b2eef24ee5bbe2073b1a47c6a7f",
                },
            },
        },
    },
}

-- Repacked from Debian by .agents/tools/repack/repack.py, x86_64 from
--     libtss2-esys-3.0.2-0t64_4.1.3-1.2_amd64.deb
--     libtss2-mu-4.0.1-0t64_4.1.3-1.2_amd64.deb
--     libtss2-sys1t64_4.1.3-1.2_amd64.deb
--     libtss2-tcti-device0t64_4.1.3-1.2_amd64.deb
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: none; Debian builds with --prefix=/usr.
--
-- Runtime libraries only, from Debian 13's tpm2-tss 4.1.3-1.2 (four binary
-- packages merged into one payload); snapshot.debian.org keeps those URLs permanent.

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
    return os.isfile(dir .. "/lib/libtss2-esys.so.0")
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
