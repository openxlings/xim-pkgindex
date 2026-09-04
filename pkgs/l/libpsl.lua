package = {
    spec = "2",
    homepage = "https://github.com/rockdaboot/libpsl",
    name = "libpsl",
    description = "C library for the Public Suffix List (libpsl + psl CLI)",
    maintainers = {"Tim Rühsen"},
    licenses = {"MIT"},
    repo = "https://github.com/rockdaboot/libpsl",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "network"},
    keywords = {"psl", "public-suffix", "domain", "lib"},
    programs = {"psl"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- Built from upstream 0.21.5 source (meson, -Druntime=no
            -- -Dbuiltin=true) against the xim glib 2.80.0 stack; hosted under
            -- FarnaHerry pending xlings-res adoption. runtime=no drops the
            -- libidn2/libunistring chain: IDNA conversion is unavailable, but
            -- the built-in PSL data and every ASCII-domain query libsoup
            -- performs are unaffected.
            ["latest"] = { ref = "0.21.5" },
            ["0.21.5"] = {
                url = "https://github.com/FarnaHerry/libpsl/releases/download/0.21.5/libpsl-0.21.5-linux-x86_64.tar.gz",
                sha256 = "13972b563a65c7b95ce6690fa26c65f60d659a7c12b7d7b89bb2e115def553a1",
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
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)
    xvm.add("psl", { bindir = path.join(idir, "bin") })

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
    xvm.remove("psl")
    xvm.remove(package.name)
    return true
end
