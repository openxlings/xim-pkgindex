package = {
    spec = "2",
    homepage = "https://gitlab.gnome.org/GNOME/glib",
    name = "glib",
    description = "Low-level core library (GLib/GObject/GIO)",
    maintainers = {"The GNOME Project"},
    licenses = {"LGPL-2.1"},
    repo = "https://gitlab.gnome.org/GNOME/glib",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "gnome"},
    keywords = {"glib", "gobject", "gio", "lib"},
    -- Only 2.88.3 has a bin/; 2.80.0 shipped none of these. config()
    -- registers what the installed payload actually contains, so one
    -- recipe stays correct for both.
    programs = {"gapplication", "gdbus", "gdbus-codegen", "gio", "gio-querymodules", "glib-compile-resources", "glib-compile-schemas", "glib-genmarshal", "glib-gettextize", "glib-mkenums", "gobject-query", "gresource", "gsettings", "gtester", "gtester-report"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {
                "xim:glibc@>=2.38",
                -- libgio-2.0.so.0 names libmount.so.1 and libselinux.so.1 in
                -- its DT_NEEDED. Without these two, `-lgio-2.0` in a closed
                -- SubOS fails with 30 undefined references (mnt_*@MOUNT_2.19,
                -- *@LIBSELINUX_1.0) and the only way to link gio was to fall
                -- back to the host.
                "xim:util-linux@>=2.40",
                "xim:libselinux@>=3.11",
                "xim:libffi@3.4.4",
                "xim:zlib@1.3.1",
                "xim:pcre2@10.42",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- 2.88.3 is a COMPLETE glib; 2.80.0 is not, and the difference is
            -- why it is here. The published 2.80.0 payload is a partial
            -- extraction of a Debian build -- an include/ and a lib/ -- and it
            -- is missing three things the GNOME stack needs:
            --
            --   * gmodule-no-export-2.0.pc, which its own gmodule-2.0.pc names
            --     in Requires. pkg-config resolves Requires transitively before
            --     it answers anything, so gmodule-2.0, gio-2.0, gdk-pixbuf-2.0
            --     and libsoup-3.0 all fail to resolve against it.
            --   * bin/ — so glib-2.0.pc's glib_genmarshal and glib_mkenums
            --     variables name files that do not exist. meson does not treat
            --     that as absent: it raises "tool variable ... contains
            --     erroneous value" and stops.
            --   * include/gio-unix-2.0/ — the .so exports the symbols, only the
            --     headers were missing.
            --
            -- install() below repairs the first two in place so 2.80.0 keeps
            -- working for anyone pinned to it. 2.88.3 needs no repair: it was
            -- built from upstream's release tarball by
            -- `.agents/tools/graphics/build-gtk4-stack.sh` and ships all three.
            --
            -- Added ALONGSIDE 2.80.0 rather than replacing its bytes. A
            -- same-version republish changes the sha256 under every home that
            -- already resolved the old one, and breaks main until the recipe
            -- lands with it.
            ["latest"] = { ref = "2.88.3" },
            ["2.88.3"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/glib/releases/download/2.88.3/glib-2.88.3-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/glib/releases/download/2.88.3/glib-2.88.3-linux-x86_64.tar.gz",
                },
                sha256 = "0d0c462b71320fe710f4c8e46982a035d7b40758f3a970b041fe7745e6695153",
            },
            ["2.80.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/glib/releases/download/2.80.0/glib-2.80.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/glib/releases/download/2.80.0/glib-2.80.0-linux-x86_64.tar.gz",
                },
                sha256 = "acc0a845d0591d3cf178d0ca140254563024dd087d34e19b324f21799180ccb6",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    sysroot.adopt_payload()

    selfcontain.seal(pkginfo.install_dir())
    -- The payload ships gmodule-2.0.pc but NOT the gmodule-no-export-2.0.pc it
    -- names in `Requires:`. Upstream splits gmodule in two -- the -no-export
    -- half carries `-lgmodule-2.0`, the plain one adds only
    -- `-Wl,--export-dynamic` on top of it -- and this Debian-family artifact
    -- shipped one half of that pair.
    --
    -- pkg-config resolves `Requires:` transitively before it answers anything,
    -- so the missing file does not degrade gracefully. Measured against this
    -- exact payload, with only the index's own .pc on the search path:
    --
    --     pkg-config --cflags gmodule-2.0     -> Package 'gmodule-no-export-2.0'
    --     pkg-config --cflags gio-2.0         ->   ... not found
    --     pkg-config --cflags gdk-pixbuf-2.0  ->   (reached via gio-2.0)
    --     pkg-config --cflags libsoup-3.0     ->   (Requires:, not private)
    --
    -- That is every GNOME consumer in the index, not just gmodule's. GTK 4
    -- takes gmodule-2.0 as a HARD dependency (gtk meson.build: `gmodule_dep =
    -- dependency('gmodule-2.0', version: glib_req)`, with no `required:
    -- false`), so without this file gtk4 cannot be configured at all.
    --
    -- Regenerated rather than republished: the payload already has
    -- libgmodule-2.0.so, so only the metadata was missing, and a recipe-side
    -- fix reaches every home on the next install without a same-version byte
    -- swap of an already-published asset.
    --
    -- Written with /usr placeholders and left for relocate_pkgconfig below,
    -- so this file goes through the same rewrite AND the same fail-closed
    -- existence check as the ones that came in the tarball, instead of being
    -- a second hand-built answer nothing verifies.
    -- Guarded on absence, so this is a no-op for 2.88.3, which ships the
    -- real file from its own build.
    local pcdir = path.join(pkginfo.install_dir(), "lib", "pkgconfig")
    local noexport = path.join(pcdir, "gmodule-no-export-2.0.pc")
    if os.isdir(pcdir) and not os.isfile(noexport) then
        io.writefile(noexport, string.format([[
prefix=/usr
includedir=${prefix}/include
libdir=${prefix}/lib

gmodule_supported=true

Name: GModule
Description: Dynamic module loader for GLib
Version: %s
Requires: glib-2.0
Libs: -L${libdir} -lgmodule-2.0
Libs.private: -ldl
Cflags: -I${includedir}/glib-2.0 -I${libdir}/glib-2.0/include
]], pkginfo.version()))
    end

    -- The .pc files in this artifact were written by a Debian-family
    -- --prefix=/usr build: `libdir=${prefix}/lib/x86_64-linux-gnu` against a
    -- payload with a flat lib/. Fixing them in the payload is what lets
    -- config() declare them instead of copying a rewritten duplicate.
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")

    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- The tools. Their absence is what made this payload unusable for
    -- building GNOME software: glib-2.0.pc names glib_genmarshal and
    -- glib_mkenums, meson reads those variables, and a path that is not there
    -- is a hard error rather than a fallback.
    --
    -- Guarded per file rather than per version: 2.80.0 has no bin/ at all,
    -- and a version test here would have to be updated for every payload that
    -- follows.
    local bindir = path.join(idir, "bin")
    if os.isdir(bindir) then
        for _, tool in ipairs(package.programs or {}) do
            if os.isfile(path.join(bindir, tool)) then
                xvm.add(tool, { bindir = bindir })
            end
        end
    end

    -- Register every linker-facing soname at its exact release version. This
    -- materializes <subos>/lib entries for GNU ld as well as lld.
    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    -- pkg-config metadata. install() already made the payload's own .pc files
    -- correct, so there is nothing left to rewrite per subos; the declare-vs-copy
    -- split lives in sysroot.declare_pkgconfig.
    sysroot.declare_pkgconfig(idir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    for _, tool in ipairs(package.programs or {}) do
        xvm.remove(tool)
    end
    xvm.remove(package.name)

    -- Nothing by hand. xlings reclaims declared assets on every path that
    -- gives a release up -- full uninstall, detach, a re-registration that
    -- stops declaring a destination, and a `use` down to a smaller asset set
    -- (openxlings/xlings#423, fixed in 2026.8.26.1). The hand-written mirror
    -- that used to live here is gone; the numbers that justify its removal,
    -- and what an older client does without it, are on
    -- `sysroot.declare_headers` in libs/sysroot.lua.
    return true
end
