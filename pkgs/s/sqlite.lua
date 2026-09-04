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
            -- BUILT, not repacked, and that is the exception rather than the
            -- rule here. Upstream does publish a Linux x86_64 binary for this
            -- version -- sqlite-tools-linux-x64-3530400.zip -- and it contains
            -- sqlite3, sqldiff, sqlite3_analyzer and sqlite3_rsync: four CLI
            -- executables and no libsqlite3.so. libsoup links
            -- `libsqlite3.so.0`, which is precisely the half upstream's binary
            -- archive does not carry.
            --
            -- Built from the autoconf amalgamation with --disable-readline
            -- (readline is not in the index; the CLI works without line
            -- editing).
            deps = {
                "xim:glibc@>=2.38",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "3.53.4" },
            ["3.53.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/sqlite/releases/download/3.53.4/sqlite-3.53.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/sqlite/releases/download/3.53.4/sqlite-3.53.4-linux-x86_64.tar.gz",
                },
                sha256 = "f4f6fe756174986f0982010b756838b1b8cae362d0cb173e73d2748480614abb",
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
    xvm.add("sqlite3", { bindir = path.join(idir, "bin") })


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
    xvm.remove("sqlite3")
    xvm.remove(package.name)
    return true
end
