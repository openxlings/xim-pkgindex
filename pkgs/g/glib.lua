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
            ["latest"] = { ref = "2.80.0" },
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
    local srcdir = pkginfo.name() .. "-" .. pkginfo.version() .. "-linux-x86_64"
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())

    selfcontain.seal(pkginfo.install_dir())
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

    -- Register every linker-facing soname at its exact release version. This
    -- materializes <subos>/lib entries for GNU ld as well as lld.
    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    -- pkg-config metadata, DECLARED like the headers rather than copied.
    -- install() already made the payload's own .pc files correct, so there is
    -- nothing left to rewrite per subos -- the asset is the payload file, and
    -- the names in lib/pkgconfig are ours, so the non-recursive helper is the
    -- right one. The fallback keeps clients without `xvm.files` working
    -- exactly as before.
    if not sysroot.declare_headers(idir, "lib/pkgconfig",
                                   "usr/lib/pkgconfig", binding) then
        local sysroot_pc = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
        os.mkdir(sysroot_pc)
        system.exec(string.format(
            "sh -c 'for pc in %s/lib/pkgconfig/*.pc; do [ -f \"$pc\" ] && cp -f \"$pc\" %s/; done'",
            idir, sysroot_pc))
    end
    return true
end

function uninstall()
    xvm.remove(package.name)

    -- Redundant on xlings 2026.8.26.1, which reclaims declared assets by
    -- itself (openxlings/xlings#423); the whole difference on anything
    -- older, which does not. A recipe cannot tell which one it is on --
    -- there is no capability to probe and no client version in the sandbox --
    -- so this stays until the minimum supported client is past 2026.8.26.1.
    -- The measurement, and why `[ -e ]` must not be the check, are on
    -- `sysroot.declare_headers` in libs/sysroot.lua.
    --
    -- This package is where the numbers were taken: 274 header assets, 5
    -- pkg-config assets, 15 lib nodes. 2026.8.26.1 leaves 0 behind with these
    -- lines deleted; 2026.8.22.4 leaves 279.
    --
    -- glibconfig.h lives inside glib-2.0/ in this artifact (not in
    -- lib/glib-2.0/include as on a distro), so the one tree covers it.
    local sysroot_dir = system.subos_sysrootdir()
    system.exec(string.format(
        "sh -c 'rm -rf %s/usr/include/glib-2.0; rm -f %s/usr/lib/pkgconfig/glib-2.0.pc %s/usr/lib/pkgconfig/gobject-2.0.pc %s/usr/lib/pkgconfig/gio-2.0.pc %s/usr/lib/pkgconfig/gmodule-2.0.pc %s/usr/lib/pkgconfig/gthread-2.0.pc'",
        sysroot_dir, sysroot_dir, sysroot_dir, sysroot_dir, sysroot_dir, sysroot_dir
    ))
    return true
end
