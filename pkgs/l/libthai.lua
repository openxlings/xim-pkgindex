package = {
    spec = "2",
    homepage = "https://github.com/tlwg/libthai",
    name = "libthai",
    description = "Thai language support library (word breaking, collation, character classification)",
    maintainers = {"Theppitak Karoonboonyanan"},
    licenses = {"LGPL-2.1"},
    repo = "https://github.com/tlwg/libthai",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "text", "i18n"},
    keywords = {"thai", "text", "i18n", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- NOT a new capability -- a missing one. The PUBLISHED pango payload
            -- already needs this: `libpango-1.0.so.0` names `libthai.so.0` in
            -- its DT_NEEDED, and until now nothing in the index provided it, so
            -- pango has been resolving it from the host's /usr/lib. Measured
            -- across every installed xim payload, it was the ONLY unresolved
            -- soname in the whole stack.
            --
            -- Its .pc is also the first of pango's four Requires.private that
            -- pkg-config could not find, which is why `pkg-config --cflags
            -- pango` -- and therefore gtk4's configure -- failed before this.
            deps = {
                "xim:glibc@>=2.38",
                "xim:libdatrie@>=0.2.14",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.1.30" },
            ["0.1.30"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libthai/releases/download/0.1.30/libthai-0.1.30-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libthai/releases/download/0.1.30/libthai-0.1.30-linux-x86_64.tar.gz",
                },
                sha256 = "18c89e627c24f8bc256be61db8348110ae071564387ea1dea9c98edbbdc7298a",
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
    sysroot.adopt_payload()

    selfcontain.seal(pkginfo.install_dir())
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    sysroot.declare_pkgconfig(idir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
