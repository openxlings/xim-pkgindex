package = {
    spec = "2",

    homepage = "https://gitlab.gnome.org/GNOME/at-spi2-core",
    name = "at-spi2-core",
    description = "The AT-SPI accessibility client library (libatspi), with headers and pkg-config data",

    licenses = {"LGPL-2.1-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"gui", "lib"},
    keywords = {"at-spi", "atspi", "accessibility", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/at-spi2-core/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/at-spi2-core/releases/download/${version}/at-spi2-core-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/at-spi2-core/releases/download/${version}/at-spi2-core-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/at-spi2-core/releases/download/${version}/at-spi2-core-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/at-spi2-core/releases/download/${version}/at-spi2-core-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libdbus-1, libglib-2.0, libgobject-2.0, libX11, libXi.
            deps = { "xim:glibc", "xim:glib", "xim:dbus", "xim:libX11", "xim:libXi" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.40.3" },
            ["2.40.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/at-spi2-core/releases/download/2.40.3/at-spi2-core-2.40.3-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/at-spi2-core/releases/download/2.40.3/at-spi2-core-2.40.3-linux-x86_64.tar.gz",
                    },
                    sha256 = "f171355c3dd7bfee09aa6e9a241c263b6bef4ef6a8ab5fe6e82aeecf0d0729cf",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/at-spi2-core/releases/download/2.40.3/at-spi2-core-2.40.3-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/at-spi2-core/releases/download/2.40.3/at-spi2-core-2.40.3-linux-aarch64.tar.gz",
                    },
                    sha256 = "754535af43cd9d9f10f006f533c5314982197a308cef0ef058d57e5e3d471848",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     at-spi2-core-2.40.3-h0630a04_0.tar.bz2
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: only the .pc files carried one; rewritten to prefix=/usr.
--
-- Not shipped: the accessibility bus launcher (libexec/) and the D-Bus
-- service files that start it. The desktop session provides the a11y bus;
-- this payload is the client library that talks to it.

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
    return os.isfile(dir .. "/lib/libatspi.so.0")
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
