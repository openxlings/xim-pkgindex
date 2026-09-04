package = {
    spec = "2",
    homepage = "https://www.sqlite.org",
    name = "sqlite",
    description = "Self-contained, serverless, zero-configuration SQL database engine (libsqlite3 + sqlite3 CLI)",
    maintainers = {"D. Richard Hipp"},
    licenses = {"blessing"},
    repo = "https://www.sqlite.org/src",
    docs = "https://www.sqlite.org/docs.html",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "database"},
    keywords = {"sqlite", "sql", "database", "lib"},
    programs = {"sqlite3"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- Built from the upstream autoconf amalgamation
            -- (sqlite-autoconf-3530400) with --disable-static
            -- --disable-readline against the xim glib 2.80.0 stack; hosted
            -- under FarnaHerry pending xlings-res adoption (asset name follows
            -- the xlings-res convention). Upstream's Makefile omits DT_SONAME,
            -- so the tarball's libsqlite3.so.0 had its soname stamped with
            -- patchelf post-build -- without it consumers record an absolute
            -- build-host path in DT_NEEDED.
            ["latest"] = { ref = "3.53.4" },
            ["3.53.4"] = {
                url = "https://github.com/FarnaHerry/sqlite/releases/download/3.53.4/sqlite-3.53.4-linux-x86_64.tar.gz",
                sha256 = "57747e0319861f8ff2570b342d19657fa5b845dea877684dd6616b44220f9cd9",
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

    -- package.name ("sqlite") is NOT one of the programs (the CLI is
    -- "sqlite3"), so the root node and the program node are separate
    -- registrations and cannot collide.
    xvm.add(package.name)
    xvm.add("sqlite3", { bindir = path.join(idir, "bin") })

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
    xvm.remove("sqlite3")
    xvm.remove(package.name)
    return true
end
