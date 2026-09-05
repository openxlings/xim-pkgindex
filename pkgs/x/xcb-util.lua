package = {
    spec = "2",

    homepage = "https://xcb.freedesktop.org/",
    name = "xcb-util",
    description = "Core XCB utility functions: atoms cache, connection context, auxiliary helpers, and event handling",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxcb-util",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"xcb-util", "xcb", "x11", "atoms"},

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
                        GLOBAL = "https://github.com/xlings-res/xcb-util/releases/download/0.4.1/xcb-util-0.4.1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xcb-util/releases/download/0.4.1/xcb-util-0.4.1-linux-x86_64.tar.gz",
                    },
                    sha256 = "7563674b72f95a92434bda908a34a830f188d14c309faba6fd74788b684a811a",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xcb-util/releases/download/0.4.1/xcb-util-0.4.1-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xcb-util/releases/download/0.4.1/xcb-util-0.4.1-linux-aarch64.tar.gz",
                    },
                    sha256 = "9e1ce822d42a22695f73f7cee1a9427f2a1f58a552911b1a064eb90ff2687fa8",
                },
            },
        },
    },
}

-- Relocatable payload repacked from the conda-forge xcb-util package
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
    os.mv("xcb-util-" .. pkginfo.version(), dir)

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
