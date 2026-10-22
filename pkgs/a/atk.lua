package = {
    spec = "2",

    homepage = "https://gitlab.gnome.org/GNOME/atk",
    name = "atk",
    description = "The ATK accessibility toolkit library (libatk-1.0), with headers and pkg-config data",

    licenses = {"LGPL-2.0-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"gui", "lib"},
    keywords = {"atk", "accessibility", "gnome", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/atk/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/atk/releases/download/${version}/atk-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/atk/releases/download/${version}/atk-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/atk/releases/download/${version}/atk-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/atk/releases/download/${version}/atk-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libglib-2.0, libgobject-2.0.
            deps = { "xim:glibc", "xim:glib" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.38.0" },
            ["2.38.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/atk/releases/download/2.38.0/atk-2.38.0-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/atk/releases/download/2.38.0/atk-2.38.0-linux-x86_64.tar.gz",
                    },
                    sha256 = "7710bb6a701af67e3809e5ae9cd630c346b41b537c66cc60bc85cd6bb9a89076",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/atk/releases/download/2.38.0/atk-2.38.0-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/atk/releases/download/2.38.0/atk-2.38.0-linux-aarch64.tar.gz",
                    },
                    sha256 = "0b9363895126c71c1dbe3b4c2655ed30064eb588d4e0ea33cf0e701b8a5d3fce",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     atk-1.0-2.38.0-h04ea711_2.conda
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
    return os.isfile(dir .. "/lib/libatk-1.0.so.0")
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
