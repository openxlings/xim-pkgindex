package = {
    spec = "2",

    homepage = "https://gitlab.gnome.org/GNOME/at-spi2-atk",
    name = "at-spi2-atk",
    description = "The ATK to AT-SPI bridge (libatk-bridge-2.0), with headers and pkg-config data",

    licenses = {"LGPL-2.1-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"gui", "lib"},
    keywords = {"at-spi", "atk-bridge", "accessibility", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/at-spi2-atk/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/at-spi2-atk/releases/download/${version}/at-spi2-atk-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/at-spi2-atk/releases/download/${version}/at-spi2-atk-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/at-spi2-atk/releases/download/${version}/at-spi2-atk-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/at-spi2-atk/releases/download/${version}/at-spi2-atk-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libatk-1.0, libatspi, libdbus-1, libglib-2.0, libgmodule-2.0, libgobject-2.0.
            deps = { "xim:glibc", "xim:glib", "xim:dbus", "xim:atk", "xim:at-spi2-core" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.38.0" },
            ["2.38.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/at-spi2-atk/releases/download/2.38.0/at-spi2-atk-2.38.0-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/at-spi2-atk/releases/download/2.38.0/at-spi2-atk-2.38.0-linux-x86_64.tar.gz",
                    },
                    sha256 = "c48ef0733263331a1ac627b8aa89348a8f5deed85a20fe821ee5c93c6fe0660b",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/at-spi2-atk/releases/download/2.38.0/at-spi2-atk-2.38.0-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/at-spi2-atk/releases/download/2.38.0/at-spi2-atk-2.38.0-linux-aarch64.tar.gz",
                    },
                    sha256 = "629c899da07aa9d714cf4ddec341acd03b2ee6d4e577a8a577a314f4ec309671",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     at-spi2-atk-2.38.0-h0630a04_3.tar.bz2
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
    return os.isfile(dir .. "/lib/libatk-bridge-2.0.so.0")
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
