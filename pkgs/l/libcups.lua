package = {
    spec = "2",

    homepage = "https://openprinting.github.io/cups/",
    name = "libcups",
    description = "The CUPS printing client libraries (libcups, libcupsimage), with headers",

    licenses = {"Apache-2.0"},
    repo = "https://github.com/OpenPrinting/cups",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"system", "lib"},
    keywords = {"cups", "printing", "lib"},

    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/libcups/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libcups/releases/download/${version}/libcups-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libcups/releases/download/${version}/libcups-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libcups/releases/download/${version}/libcups-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libcups/releases/download/${version}/libcups-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libgssapi_krb5, libkrb5, libk5crypto, libcom_err, libz.
            deps = { "xim:glibc", "xim:krb5", "xim:zlib" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.3.3" },
            ["2.3.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libcups/releases/download/2.3.3/libcups-2.3.3-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libcups/releases/download/2.3.3/libcups-2.3.3-linux-x86_64.tar.gz",
                    },
                    sha256 = "9e6106988f9e350cfea54ee668314e265baab30c8ce0633dce1500d0fdde9d3e",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libcups/releases/download/2.3.3/libcups-2.3.3-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libcups/releases/download/2.3.3/libcups-2.3.3-linux-aarch64.tar.gz",
                    },
                    sha256 = "eb0e5cee16da226ee41dd34566371a8dd940356a7fe90389f059aa302659ecfa",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     libcups-2.3.3-h7a8fb5f_6.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: libcups.so.2 names the HOST's print system: /etc/cups, /var/run/cups/cups.sock,
-- /usr/lib/cups, /usr/share/cups. The repack maps those onto the host paths (--host), so
-- the library reads the machine's client.conf and talks to its cupsd. The server-side
-- helpers under lib/cups/ are not shipped.
-- .pc files, if any, -> prefix=/usr.

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
    return os.isfile(dir .. "/lib/libcups.so.2")
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
