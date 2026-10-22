package = {
    spec = "2",

    homepage = "https://www.gtk.org",
    name = "gtk3",
    description = "The GTK 3 toolkit libraries (libgtk-3, libgdk-3, libgailutil-3), with headers, pkg-config data and compiled GSettings schemas",

    licenses = {"LGPL-2.0-or-later"},
    repo = "https://gitlab.gnome.org/GNOME/gtk",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"gui", "lib"},
    keywords = {"gtk", "gtk3", "gui", "toolkit", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/gtk3/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/gtk3/releases/download/${version}/gtk3-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/gtk3/releases/download/${version}/gtk3-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/gtk3/releases/download/${version}/gtk3-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/gtk3/releases/download/${version}/gtk3-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): glib, pango, cairo, harfbuzz, fribidi, fontconfig, gdk-pixbuf, atk, atk-bridge, cups, epoxy, wayland, xkbcommon and eight X11 client libraries.
            deps = { "xim:glibc", "xim:glib@>=2.88", "xim:pango", "xim:cairo", "xim:harfbuzz",
                     "xim:fribidi", "xim:fontconfig", "xim:gdk-pixbuf", "xim:atk",
                     "xim:at-spi2-atk", "xim:libcups", "xim:libepoxy", "xim:wayland",
                     "xim:libxkbcommon", "xim:libX11", "xim:libXcomposite", "xim:libXcursor",
                     "xim:libXdamage", "xim:libXext", "xim:libXfixes", "xim:libXi",
                     "xim:libXinerama", "xim:libXrandr" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "3.24.43" },
            ["3.24.43"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/gtk3/releases/download/3.24.43/gtk3-3.24.43-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/gtk3/releases/download/3.24.43/gtk3-3.24.43-linux-x86_64.tar.gz",
                    },
                    sha256 = "4c9a765260333ddf67fe31b839f6464c4c9c5a295aa2fa50fe07df5d55d3e9b9",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/gtk3/releases/download/3.24.43/gtk3-3.24.43-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/gtk3/releases/download/3.24.43/gtk3-3.24.43-linux-aarch64.tar.gz",
                    },
                    sha256 = "390ffe88c255b6cb17f479f277b3e43327a7073e6aa7e81956ebd3a855e8d862",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     gtk3-3.24.43-h0359ba6_0.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: libgtk-3 and the input-method modules compile in their build
-- prefix for the module directory, data and locale paths. Those must follow the
-- payload, so the repack leaves them in place (--relocate) and install() points
-- them at the install directory through RELOCATE.json. .pc files -> prefix=/usr.
--
-- install() compiles share/glib-2.0/schemas into the payload and config() places
-- the result in <subos>/share/glib-2.0/schemas, which a consumer launched with
-- graphics.consumer_envs() already has on XDG_DATA_DIRS. Not shipped: the demo and
-- query tools in bin/, and the immodules.cache conda generates at link time, so
-- only GTK's built-in input method is active.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")
import("xim.pkgindex.relocate")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(package.name .. "-" .. pkginfo.version(), dir)
    relocate.apply(dir)
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    local schemas = dir .. "/share/glib-2.0/schemas"
    local compiler = pkginfo.dep_install_dir("xim:glib") .. "/bin/glib-compile-schemas"
    system.exec(string.format("%q --strict %q", compiler, schemas))
    return os.isfile(dir .. "/lib/libgtk-3.so.0") and os.isfile(schemas .. "/gschemas.compiled")
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers_tree(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    -- declare_headers is the per-child file-asset declarer (declare_pkgconfig
    -- uses it the same way); here it places the compiled schemas where
    -- XDG_DATA_DIRS=<subos>/share leads GLib
    sysroot.declare_headers(dir, "share/glib-2.0/schemas", "share/glib-2.0/schemas", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
