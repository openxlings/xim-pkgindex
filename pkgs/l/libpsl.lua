package = {
    spec = "2",
    homepage = "https://github.com/rockdaboot/libpsl",
    name = "libpsl",
    description = "C library for the Public Suffix List (libpsl + psl CLI)",
    maintainers = {"Tim Ruehsen"},
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
            -- libsoup links libpsl.so.5 to decide cookie scope.
            --
            -- Built -Druntime=no, which drops the libidn2/libunistring chain:
            -- IDNA conversion of non-ASCII domains is unavailable, the built-in
            -- PSL data and every ASCII-domain lookup libsoup performs are not.
            deps = {
                "xim:glibc@>=2.38",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.23.3" },
            ["0.23.3"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libpsl/releases/download/0.23.3/libpsl-0.23.3-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libpsl/releases/download/0.23.3/libpsl-0.23.3-linux-x86_64.tar.gz",
                },
                sha256 = "1987dd56df0aab14d516af533de370c97df6b37a167c1b4ef2dce54d7a796988",
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
    xvm.add("psl", { bindir = path.join(idir, "bin") })
    -- bin/psl-make-dafsa is shipped but deliberately NOT registered: it is a
    -- build-time source generator whose shebang is `#!/usr/bin/env python`,
    -- and modern distributions provide `python3` without a bare `python`. A
    -- registered shim for it would resolve and then fail on execution, which
    -- is worse than not being on PATH.


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
    xvm.remove("psl")
    xvm.remove(package.name)
    return true
end
