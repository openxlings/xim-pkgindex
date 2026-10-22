package = {
    spec = "2",

    homepage = "https://systemd.io",
    name = "libudev",
    description = "The udev device-database client library (libudev) from systemd",

    licenses = {"LGPL-2.1-or-later"},
    repo = "https://github.com/systemd/systemd",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"system", "lib"},
    keywords = {"udev", "libudev", "systemd", "lib"},

    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/libudev/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libudev/releases/download/${version}/libudev-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libudev/releases/download/${version}/libudev-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libudev/releases/download/${version}/libudev-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libudev/releases/download/${version}/libudev-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libcap.
            deps = { "xim:glibc", "xim:libcap" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "257.4" },
            ["257.4"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libudev/releases/download/257.4/libudev-257.4-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libudev/releases/download/257.4/libudev-257.4-linux-x86_64.tar.gz",
                    },
                    sha256 = "c0c3dc174cdba93ad23011853e5dc07e0ede9a13b8f13145d94b2057672f064c",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libudev/releases/download/257.4/libudev-257.4-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libudev/releases/download/257.4/libudev-257.4-linux-aarch64.tar.gz",
                    },
                    sha256 = "64c3579732c660bb0fe60ae3e041721cde31935bf6556586174bae7e7036e47e",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     libudev1-257.4-hbe16f8c_1.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: libudev.so.1 names the hwdb at /usr/lib/udev/hwdb.bin; the device database belongs
-- to the host, so the repack maps it there (--host). Runtime library only.
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
    return os.isfile(dir .. "/lib/libudev.so.1")
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
