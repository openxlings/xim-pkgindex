-- Private GTK closure for applications, not a replacement for the individual
-- GTK/X11 development packages. Sources and all component licenses are pinned in
-- tools/res/gtk4-runtime-4.24.2.json and preserved in BUILD-METADATA.json,
-- PROVENANCE.md and licenses/ inside each resource. Rebuild with
-- tools/res/gtk4_runtime.py; the bare repacker omits generated MIME data.
-- Manual updates: the complete two-architecture closure must be reviewed and
-- natively verified together, rather than updating its components independently.
package = {
    spec = "2",
    name = "gtk4-runtime",
    description = "Private GTK 4, text, image and GIO TLS runtime for Linux applications",
    homepage = "https://www.gtk.org",
    repo = "https://gitlab.gnome.org/GNOME/gtk",
    type = "package",
    archs = { "x86_64", "aarch64" },
    status = "stable",
    categories = { "runtime", "gui" },
    keywords = { "gtk4", "gnome", "runtime" },
    licenses = {
        "0BSD", "Apache-2.0", "BSD-3-Clause", "GPL-2.0-only OR FTL",
        "GPL-2.0-or-later", "GPL-3.0-only WITH GCC-exception-3.1", "HPND",
        "IJG AND BSD-3-Clause AND Zlib", "ISC", "LGPL-2.0-or-later",
        "LGPL-2.1-only", "LGPL-2.1-only OR MPL-1.1", "LGPL-2.1-or-later",
        "LGPL-3.0-or-later OR CC-BY-SA-3.0", "LicenseRef-libglvnd", "MIT",
        "MIT AND MIT-open-group AND HPND AND HPND-sell-variant AND ISC",
        "OFL-1.1", "Ubuntu-font-1.0", "Zlib", "blessing", "zlib-acknowledgement",
    },
    programs = {},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.38" },
                build = { "xim:patchelf@>=0.19.3" },
            },
            exports = { runtime = { libdirs = { "lib" } } },
            ["latest"] = { ref = "4.24.2" },
            ["4.24.2"] = {
                x86_64 = {
                    url = "https://github.com/FarnaHerry/xim-pkgindex/releases/download/gtk4-runtime-4.24.2/gtk4-runtime-4.24.2-linux-x86_64.tar.gz",
                    sha256 = "0754df48532383e75f3ccfe8f70aa787b2d4f16edcccf7209a5d6e65b7328c23",
                },
                aarch64 = {
                    url = "https://github.com/FarnaHerry/xim-pkgindex/releases/download/gtk4-runtime-4.24.2/gtk4-runtime-4.24.2-linux-aarch64.tar.gz",
                    sha256 = "1685a7dbc3dd5228d43c346374a8d91c56665c60f2209b6383ac6d2dbbea23da",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.relocate")
import("xim.pkgindex.selfcontain")

local required = {
    "lib/libgtk-4.so.1", "lib/libpango-1.0.so.0", "lib/libpangocairo-1.0.so.0",
    "lib/libpangoft2-1.0.so.0", "lib/libgdk_pixbuf-2.0.so.0",
    "lib/libcairo.so.2", "lib/libcairo-gobject.so.2", "lib/libgraphene-1.0.so.0",
    "lib/libglib-2.0.so.0", "lib/libgobject-2.0.so.0", "lib/libgio-2.0.so.0",
    "lib/libgmodule-2.0.so.0", "lib/libsoup-3.0.so.0", "lib/libvulkan.so.1",
    "lib/gio/modules/libgioopenssl.so",
    "lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader_svg.so",
    "bin/glib-compile-schemas", "bin/gio-querymodules", "bin/gdk-pixbuf-query-loaders",
    "bin/fc-cache", "fonts/DejaVuSans.ttf", "etc/fonts/fonts.conf",
    "share/mime/mime.cache", "BUILD-METADATA.json", "PROVENANCE.md", "RELOCATE.json",
}
local configured = {
    ".gtk4-runtime-ready", "share/glib-2.0/schemas/gschemas.compiled",
    "lib/gio/modules/giomodule.cache", "lib/gdk-pixbuf-2.0/2.10.0/loaders.cache",
}

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function stored_version()
    local store = pkginfo.install_dir():match("/([^/]+)/[^/]+/?$")
    local namespace = store and store:match("^(.-)%-x%-")
    assert(namespace, "cannot identify the installed runtime namespace")
    if namespace ~= "xim" then return namespace .. ":" .. pkginfo.version() end
    return pkginfo.version()
end

function installed()
    return payload.present(required) and payload.present(configured)
end

function install()
    local dir = pkginfo.install_dir()
    payload.unpack{ extracted = "gtk4-runtime-" .. pkginfo.version() }
    payload.require(required)
    relocate.apply(dir)
    assert(selfcontain.seal(dir, { "lib" }), "update xlings: GTK runtime requires ELF closure sealing")
    -- The declared glibc loader makes xlings seal every ELF after this hook,
    -- including the private bin/ and libexec/ tools, before config runs them.
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local bin = dir .. "/bin/"
    local gio = dir .. "/lib/gio/modules"
    local pixbuf = dir .. "/lib/gdk-pixbuf-2.0/2.10.0"
    local loaders = pixbuf .. "/loaders"
    local ready = dir .. "/.gtk4-runtime-ready"
    os.tryrm(ready)
    -- Cache tools run only after ELF relocation. Their cache/config overrides
    -- apply to these child processes, never the user's shell or subos settings.
    local commands = {
        quote(bin .. "glib-compile-schemas") .. " --strict " .. quote(dir .. "/share/glib-2.0/schemas"),
        quote(bin .. "gio-querymodules") .. " " .. quote(gio),
        "GDK_PIXBUF_MODULEDIR=" .. quote(loaders) .. " " .. quote(bin .. "gdk-pixbuf-query-loaders")
            .. " " .. quote(loaders) .. "/*.so > " .. quote(pixbuf .. "/loaders.cache.tmp"),
        "mv " .. quote(pixbuf .. "/loaders.cache.tmp") .. " " .. quote(pixbuf .. "/loaders.cache"),
        "mkdir -p " .. quote(dir .. "/var/cache/fontconfig"),
        "FONTCONFIG_FILE=" .. quote(dir .. "/etc/fonts/fonts.conf")
            .. " FONTCONFIG_PATH=" .. quote(dir .. "/etc/fonts")
            .. " XDG_CACHE_HOME=" .. quote(dir .. "/var/cache")
            .. " " .. quote(bin .. "fc-cache") .. " -f " .. quote(dir .. "/fonts"),
        "printf '%s\\n' '4.24.2' > " .. quote(ready),
    }
    system.exec(table.concat(commands, " && "))
    payload.require(configured)
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name, stored_version())
    return true
end
