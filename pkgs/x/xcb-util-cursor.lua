package = {
    spec = "2",

    homepage = "https://xcb.freedesktop.org/",
    name = "xcb-util-cursor",
    description = "XCB cursor utility library, a port of Xlib's libXcursor functions",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxcb-cursor",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"xcb-util-cursor", "xcb", "x11", "cursor"},

    xpm = {
        linux = {
            -- xim:glibc is declared directly (every payload's own
            -- libc.so.6 need), even though it also arrives transitively
            -- through xim:libxcb's own deps.
            deps = { "xim:glibc", "xim:libxcb@>=1.17.0", "xim:xcb-util-image@>=0.4.0", "xim:xcb-util-renderutil@>=0.3.10" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.1.6" },
            ["0.1.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xcb-util-cursor/releases/download/0.1.6/xcb-util-cursor-0.1.6-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xcb-util-cursor/releases/download/0.1.6/xcb-util-cursor-0.1.6-linux-x86_64.tar.gz",
                    },
                    sha256 = "6ef223c31b8fb44a4e3f28b12d7e1ad9d00613dc19fd265bb79642d00d5ceaad",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xcb-util-cursor/releases/download/0.1.6/xcb-util-cursor-0.1.6-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xcb-util-cursor/releases/download/0.1.6/xcb-util-cursor-0.1.6-linux-aarch64.tar.gz",
                    },
                    sha256 = "c7fd1b1e9054131816a235adbc946d408eceb22fd68faf3170d0e4f35de13a0d",
                },
            },
        },
    },
}

-- Relocatable payload repacked from the conda-forge xcb-util-cursor package
-- (0.1.6, linux-64 and linux-aarch64 builds), built against a glibc 2.17
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
--
-- libxcb-cursor.so.0 also carries DT_NEEDED libxcb-render.so.0 and
-- libxcb-shm.so.0, both part of the libxcb payload rather than a
-- separate xim package -- see pkgs/l/libxcb.lua's shipped lib/.
--
-- RELOCATION CAVEAT, measured on the shipped .so (both architectures):
-- libxcb-cursor.so.0.0.0 embeds a compiled-in fallback theme search
-- path --
--
--     ~/.local/share/icons:~/.icons:<build-prefix>/share/icons:<build-prefix>/share/pixmaps
--
-- where <build-prefix> is the conda-forge build machine's placeholder-
-- padded prefix. This string is not a `.pc` file; it is data inside
-- the ELF's rodata, concatenated with the two legitimate `~/...`
-- entries ahead of it, so it cannot be rewritten in place without
-- corrupting the surrounding string. The two build-prefix entries
-- name a directory that exists on no installation host and are
-- therefore inert: cursor theme lookup still tries the two `~/...`
-- entries, and any consumer that cares can still set XCURSOR_PATH.
-- This payload ships nothing under share/icons or share/pixmaps.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("xcb-util-cursor-" .. pkginfo.version(), dir)

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
