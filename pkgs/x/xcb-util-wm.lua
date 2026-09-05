package = {
    spec = "2",

    homepage = "https://xcb.freedesktop.org/",
    name = "xcb-util-wm",
    description = "EWMH and ICCCM client/window-manager helper libraries (libxcb-ewmh, libxcb-icccm)",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxcb-wm",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"xcb-util-wm", "xcb", "x11", "ewmh", "icccm"},

    xpm = {
        linux = {
            -- xim:glibc is declared directly (every payload's own
            -- libc.so.6 need), even though it also arrives transitively
            -- through xim:libxcb's own deps.
            deps = { "xim:glibc", "xim:libxcb@>=1.17.0" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.4.2" },
            ["0.4.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xcb-util-wm/releases/download/0.4.2/xcb-util-wm-0.4.2-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xcb-util-wm/releases/download/0.4.2/xcb-util-wm-0.4.2-linux-x86_64.tar.gz",
                    },
                    sha256 = "8518d61481406cb577c2092f82655d5d682d9782497fa7db12507d9efe2e0dd5",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xcb-util-wm/releases/download/0.4.2/xcb-util-wm-0.4.2-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xcb-util-wm/releases/download/0.4.2/xcb-util-wm-0.4.2-linux-aarch64.tar.gz",
                    },
                    sha256 = "af985772beae687dbfade92784669f405923736624e2d07ac98c8cc826d56b96",
                },
            },
        },
    },
}

-- Relocatable payload repacked from the conda-forge xcb-util-wm package
-- (0.4.2, linux-64 and linux-aarch64 builds), built against a glibc 2.17
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
    os.mv("xcb-util-wm-" .. pkginfo.version(), dir)

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
