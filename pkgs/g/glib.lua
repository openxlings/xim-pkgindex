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
    local sysroot_pc = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
    os.mkdir(sysroot_pc)
    system.exec(string.format(
        "sh -c 'for pc in %s/lib/pkgconfig/*.pc; do [ -f \"$pc\" ] && sed \"s|^prefix=.*|prefix=%s|\" \"$pc\" > %s/$(basename \"$pc\"); done'",
        idir, idir, sysroot_pc
    ))
    return true
end

function uninstall()
    xvm.remove(package.name)
    local sysroot = system.subos_sysrootdir()
    system.exec(string.format(
        "sh -c 'rm -rf %s/usr/include/glib-2.0; rm -f %s/usr/lib/pkgconfig/glib-2.0.pc %s/usr/lib/pkgconfig/gobject-2.0.pc %s/usr/lib/pkgconfig/gio-2.0.pc %s/usr/lib/pkgconfig/gmodule-2.0.pc %s/usr/lib/pkgconfig/gthread-2.0.pc'",
        sysroot, sysroot, sysroot, sysroot, sysroot, sysroot
    ))
    return true
end
