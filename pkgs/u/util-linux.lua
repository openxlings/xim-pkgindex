package = {
    spec = "2",

    homepage = "https://github.com/util-linux/util-linux",
    name = "util-linux",
    description = "util-linux shared libraries: libmount, libblkid, libuuid",

    authors = {"Karel Zak and the util-linux contributors"},
    licenses = {"LGPL-2.1-or-later", "BSD-3-Clause"},
    repo = "https://github.com/util-linux/util-linux",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"lib", "system"},
    keywords = {"libmount", "libblkid", "libuuid", "util-linux", "lib"},

    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.38" },
            -- elfpatch reads this from each dependency and writes the
            -- consumer's RPATH, which is what makes the stack resolve without
            -- anyone setting LD_LIBRARY_PATH.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.40.2" },
            ["2.40.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/util-linux/releases/download/2.40.2/util-linux-2.40.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/util-linux/releases/download/2.40.2/util-linux-2.40.2-linux-x86_64.tar.gz",
                },
                sha256 = "f449a2f3c518c94058bbbfff9d8230a1b82293b0586954a730bf988734c0e551",
            },
        },
    },
}

-- The libraries only, no programs.
--
-- What needs this is GLib: libgio-2.0.so.0 names libmount.so.1 in its
-- DT_NEEDED, so before this package existed, `-lgio-2.0` inside a closed
-- SubOS failed with 24 undefined references to mnt_*@MOUNT_2.19 and the only
-- way to link gio was to reach for the host's copy. libblkid ships with it
-- because libmount names it in turn, and libuuid because util-linux's build
-- does not separate it.
--
-- The programs (mount, lsblk, fdisk, ...) are deliberately not built: they
-- pull in systemd, udev and PAM, none of which is in this index, and nothing
-- here consumes them.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("util-linux-" .. pkginfo.version(), dir)

    -- Stamp this payload's own dependency closure onto its libraries, so they
    -- resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(dir)

    -- The .pc files were written by a --prefix=/usr build and say
    -- `libdir=/usr/lib` outright -- no ${prefix} to inherit a rewrite.
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

    -- _tree, not declare_headers: these headers land in `usr/include` next to
    -- glibc's 130, and a directory asset is placed by rename(2) -- declaring
    -- the shared parent would replace what another package put there.
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

    -- Named individually: `usr/include` is shared with glibc and every
    -- other package in the sysroot.
    -- Redundant on xlings 2026.8.26.1, which reclaims declared assets by
    -- itself (openxlings/xlings#423); the whole difference on anything
    -- older, which does not. A recipe cannot tell which one it is on --
    -- there is no capability to probe and no client version in the sandbox --
    -- so this stays until the minimum supported client is past 2026.8.26.1.
    -- The measurement, and why `[ -e ]` must not be the check, are on
    -- `sysroot.declare_headers` in libs/sysroot.lua.
    local sysroot_dir = system.subos_sysrootdir()
    system.exec(string.format(
        "sh -c 'rm -rf %s/usr/include/libmount %s/usr/include/blkid %s/usr/include/uuid; "
        .. "rm -f %s/usr/lib/pkgconfig/mount.pc %s/usr/lib/pkgconfig/blkid.pc "
        .. "%s/usr/lib/pkgconfig/uuid.pc'",
        sysroot_dir, sysroot_dir, sysroot_dir,
        sysroot_dir, sysroot_dir, sysroot_dir
    ))
    return true
end
