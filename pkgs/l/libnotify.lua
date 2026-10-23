package = {
    spec = "2",

    homepage = "https://gitlab.gnome.org/GNOME/libnotify",
    name = "libnotify",
    description = "The desktop notification client library (libnotify)",

    licenses = {"LGPL-2.1-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"gui", "lib"},
    keywords = {"notify", "notification", "desktop", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/libnotify/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libnotify/releases/download/${version}/libnotify-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libnotify/releases/download/${version}/libnotify-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libnotify/releases/download/${version}/libnotify-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libnotify/releases/download/${version}/libnotify-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libgdk_pixbuf-2.0, libgio-2.0, libglib-2.0, libgobject-2.0.
            deps = { "xim:glibc", "xim:glib", "xim:gdk-pixbuf" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.8.6" },
            ["0.8.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libnotify/releases/download/0.8.6/libnotify-0.8.6-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libnotify/releases/download/0.8.6/libnotify-0.8.6-linux-x86_64.tar.gz",
                    },
                    sha256 = "3861f83f9d6de59ba0e3f42cffed96b370f3883a6323041422cdc16131ee50a3",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libnotify/releases/download/0.8.6/libnotify-0.8.6-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libnotify/releases/download/0.8.6/libnotify-0.8.6-linux-aarch64.tar.gz",
                    },
                    sha256 = "eb9a6ec389d1158412fde0bee57c711db73f057ce07ea4942bc1751a02971eb8",
                },
            },
        },
    },
}

-- Repacked from Debian by .agents/tools/repack/repack.py, x86_64 from
--     libnotify4_0.8.6-1_amd64.deb
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: none; Debian builds with --prefix=/usr.
--
-- Runtime library only (Debian libnotify4); Electron applications dlopen it.

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
    return os.isfile(dir .. "/lib/libnotify.so.4")
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
