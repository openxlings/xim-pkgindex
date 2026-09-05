package = {
    spec = "2",

    homepage = "https://xcb.freedesktop.org/",
    name = "xcb-util-keysyms",
    description = "Standard X key constants and keycode/keysym conversion utilities",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxcb-keysyms",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"xcb-util-keysyms", "xcb", "x11", "keysyms"},

    xpm = {
        linux = {
            -- xim:glibc is declared directly (every payload's own
            -- libc.so.6 need), even though it also arrives transitively
            -- through xim:libxcb's own deps.
            deps = { "xim:glibc", "xim:libxcb@>=1.17.0" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.4.1" },
            ["0.4.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xcb-util-keysyms/releases/download/0.4.1/xcb-util-keysyms-0.4.1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xcb-util-keysyms/releases/download/0.4.1/xcb-util-keysyms-0.4.1-linux-x86_64.tar.gz",
                    },
                    sha256 = "8bb62fef4bd0916405d1f91f752eb9165ae4d3bbead010e5ed36540f87e2ef8e",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xcb-util-keysyms/releases/download/0.4.1/xcb-util-keysyms-0.4.1-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xcb-util-keysyms/releases/download/0.4.1/xcb-util-keysyms-0.4.1-linux-aarch64.tar.gz",
                    },
                    sha256 = "db2da6ba11e6de72385411dc9920bb82e93dfb5fd965217a854a72e3fb178918",
                },
            },
        },
    },
}

-- Relocatable payload repacked from the conda-forge xcb-util-keysyms package
-- (0.4.1, linux-64 and linux-aarch64 builds), built against a glibc 2.17
-- baseline. Payload contents: lib/*.so* (shared libraries, no static
-- archives), include/xcb/*.h, lib/pkgconfig/*.pc, licenses/, and
-- PROVENANCE.md. No bin/: this package ships no command-line tools.
--
-- include/xcb/ is a namespace shared with libxcb, xcb-proto, and every
-- other xcb-util-* package (see pkgs/l/libxcb.lua's comment on
-- declare_headers_tree), so config() declares headers at the leaf rather
-- than as one directory asset.
--
-- .pc files carry the conda-forge build machine's placeholder-padded
-- prefix; rewritten here to `prefix=/usr` with ${prefix}-relative
-- libdir/includedir, the shape sysroot.relocate_pkgconfig expects.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("xcb-util-keysyms-" .. pkginfo.version(), dir)

    -- Stamp this payload's own dependency closure onto its libraries, so
    -- they resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(dir)

    -- The payload's .pc files were never published; see
    -- sysroot.declare_pkgconfig. Relocate here, declare in config().
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name, { type = "group" })

    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())

    -- include/xcb/ is shared with libxcb and the other xcb-util-*
    -- packages; _tree declares at the leaf so each package's headers
    -- land beside the others' instead of one replacing the whole
    -- directory. See libs/sysroot.lua and pkgs/l/libxcb.lua.
    if not sysroot.declare_headers_tree(pkginfo.install_dir(), "include",
                                        "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(pkginfo.install_dir(), "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end
    sysroot.declare_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig", binding)

    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
