package = {
    spec = "2",

    homepage = "https://github.com/SELinuxProject/selinux",
    name = "libselinux",
    description = "SELinux userspace library (libselinux.so.1)",

    authors = {"The SELinux Project"},
    licenses = {"LicenseRef-public-domain", "LGPL-2.1-or-later"},
    repo = "https://github.com/SELinuxProject/selinux",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"lib", "system"},
    keywords = {"libselinux", "selinux", "lib"},

    xpm = {
        linux = {
            -- pcre2 is a real runtime dependency: libselinux.so.1 names
            -- libpcre2-8.so.0 in DT_NEEDED. libsepol is NOT here -- it is
            -- linked statically (-l:libsepol.a), which is why this stack
            -- needs no libsepol package.
            deps = { "xim:glibc@>=2.38", "xim:pcre2@10.42" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "3.11" },
            ["3.11"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libselinux/releases/download/3.11/libselinux-3.11-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libselinux/releases/download/3.11/libselinux-3.11-linux-x86_64.tar.gz",
                },
                sha256 = "7902c5d5c70df855d0b435382d322276911b8aa9c7ea78eb394af47ec201e975",
            },
        },
    },
}

-- What needs this is GLib: libgio-2.0.so.0 names libselinux.so.1 in its
-- DT_NEEDED, so before this package existed, `-lgio-2.0` inside a closed
-- SubOS failed with 6 undefined references to *@LIBSELINUX_1.0 and the only
-- way to link gio was to reach for the host's copy.
--
-- The library works on a kernel without SELinux: is_selinux_enabled() returns
-- 0 and the rest degrades accordingly. Installing it does not turn anything
-- on; it makes the symbol resolvable.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libselinux-" .. pkginfo.version(), dir)

    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    -- The binding root has to exist before anything binds to it: xvm refuses
    -- a registration whose binding names a node the recipe never registered
    -- ("registration binding root is not an exact batch node").
    xvm.add(package.name)

    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

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

    -- Nothing by hand. xlings reclaims declared assets on every path that
    -- gives a release up -- full uninstall, detach, a re-registration that
    -- stops declaring a destination, and a `use` down to a smaller asset set
    -- (openxlings/xlings#423, fixed in 2026.8.26.1). The hand-written mirror
    -- that used to live here is gone; the numbers that justify its removal,
    -- and what an older client does without it, are on
    -- `sysroot.declare_headers` in libs/sysroot.lua.
    return true
end
