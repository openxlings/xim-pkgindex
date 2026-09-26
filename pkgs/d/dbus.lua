package = {
    spec = "2",

    homepage = "https://www.freedesktop.org/wiki/Software/dbus/",
    name = "dbus",
    description = "libdbus-1, the D-Bus client library, with its headers and pkg-config metadata",

    authors = {"The D-Bus developers"},
    licenses = {"AFL-2.1", "GPL-2.0-or-later"},
    repo = "https://gitlab.freedesktop.org/dbus/dbus",
    docs = "https://dbus.freedesktop.org/doc/api/html/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ipc", "lib"},
    keywords = {"dbus", "libdbus", "ipc", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- libdbus-1.so.3 needs libc.so.6 and libpthread.so.0 only, at
            -- GLIBC_2.17 at most (measured with readelf -d and objdump -T).
            deps = { "xim:glibc" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.16.2" },
            ["1.16.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/dbus/releases/download/1.16.2/dbus-1.16.2-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/dbus/releases/download/1.16.2/dbus-1.16.2-linux-x86_64.tar.gz",
                    },
                    sha256 = "7c02c56a39f5247b43d404ffa5d774f334b334a136b8bf1174d5ac9e6e63f909",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/dbus/releases/download/1.16.2/dbus-1.16.2-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/dbus/releases/download/1.16.2/dbus-1.16.2-linux-aarch64.tar.gz",
                    },
                    sha256 = "67162484c714591c43b2b3c03bb86a41baee8e4029ed80f6d7f45767aed43b50",
                },
            },
        },
    },
}

-- The client library only, repacked from the conda-forge `dbus` package
-- (1.16.2, linux-64 and linux-aarch64 builds, glibc 2.17 baseline); the daemon
-- and the command-line tools are not included. Qt's QtDBus, and through it
-- QtGui, loads libdbus-1.so.3.
--
-- Payload: lib/libdbus-1.so{,.3,.3.38.3}, lib/dbus-1.0/include/dbus/
-- dbus-arch-deps.h (the architecture header, which upstream installs under
-- libdir), include/dbus-1.0/dbus/*.h, lib/pkgconfig/dbus-1.pc and
-- share/licenses/dbus/.
--
-- PLACEHOLDER AUDIT. conda-forge embeds its padded build prefix in two strings
-- of the library, which conda rewrites at install time: the default system
-- bus address and the machine-id path. The repack makes the same rewrite with
-- the prefix `/`, NUL-padded, so the library reads
-- `unix:path=/var/run/dbus/system_bus_socket` and `/var/lib/dbus/machine-id`
-- (then `/etc/machine-id`), as a distribution's libdbus does. The release
-- notes of xlings-res/dbus name the source archives and their sha256.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("dbus-" .. pkginfo.version(), dir)
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers_tree(dir, "include/dbus-1.0", "usr/include/dbus-1.0", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
