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

    -- Keep pkg-config metadata in the active SubOS view. The files retain
    -- absolute payload prefixes, which point at the shared xim installation.
    --
    -- libdir is rewritten too, and that is not cosmetic: this artifact was
    -- built on a Debian-family host, so every .pc ships
    -- `libdir=${prefix}/lib/x86_64-linux-gnu` while the payload puts its
    -- libraries in a flat `lib/`. Rewriting only `prefix=` leaves
    -- `pkg-config --libs glib-2.0` emitting -L<payload>/lib/x86_64-linux-gnu,
    -- a directory that does not exist -- i.e. exactly the `cannot find
    -- -lglib-2.0` this recipe is supposed to end, for every consumer that
    -- asks pkg-config instead of relying on the sysroot lib search path.
    -- (pcre2 and libffi carry the same sed with no libdir clause; theirs is
    -- correct only because their upstream .pc already says ${prefix}/lib.)
    local sysroot_pc = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sysroot_pc)
    system.exec(string.format(
        "sh -c 'for pc in %s/lib/pkgconfig/*.pc; do [ -f \"$pc\" ] && sed -e \"s|^prefix=.*|prefix=%s|\" -e \"s|^libdir=.*|libdir=%s/lib|\" \"$pc\" > %s/$(basename \"$pc\"); done'",
        idir, idir, idir, sysroot_pc
    ))
    return true
end

function uninstall()
    xvm.remove(package.name)

    -- The library nodes go with xvm.remove(binding); the header symlinks do
    -- NOT. Measured on xlings 2026.8.22.4: install declares 274 header assets
    -- under <subos>/usr/include/glib-2.0, `xlings remove glib` reports the
    -- package removed, and all 274 symlinks are still there -- now pointing
    -- into a payload this subos no longer uses. So the hook keeps removing
    -- the tree. Drop these lines only after a client is confirmed to reclaim
    -- `xvm.files` assets; a green install proves nothing about that.
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
