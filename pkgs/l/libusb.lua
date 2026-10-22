package = {
    spec = "2",

    homepage = "https://libusb.info",
    name = "libusb",
    description = "The USB device access library (libusb-1.0), with headers and pkg-config data",

    licenses = {"LGPL-2.1-or-later"},
    repo = "https://github.com/libusb/libusb",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"system", "lib"},
    keywords = {"usb", "libusb", "lib"},

    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/libusb/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libusb/releases/download/${version}/libusb-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libusb/releases/download/${version}/libusb-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libusb/releases/download/${version}/libusb-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libusb/releases/download/${version}/libusb-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libudev.
            deps = { "xim:glibc", "xim:libudev" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.0.29" },
            ["1.0.29"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libusb/releases/download/1.0.29/libusb-1.0.29-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libusb/releases/download/1.0.29/libusb-1.0.29-linux-x86_64.tar.gz",
                    },
                    sha256 = "771ab36014906a522018c9780ff5cb5f3acc10cfd7b039fef9354a7a7c35a4f3",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libusb/releases/download/1.0.29/libusb-1.0.29-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libusb/releases/download/1.0.29/libusb-1.0.29-linux-aarch64.tar.gz",
                    },
                    sha256 = "a75ad8c8556f59d0a6fbbfb073071ad629030aca2f1cbb238e6ea4149056f0b2",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     libusb-1.0.29-h73b1eb8_0.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: only the .pc files carried one; rewritten to prefix=/usr.

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
    return os.isfile(dir .. "/lib/libusb-1.0.so.0")
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
