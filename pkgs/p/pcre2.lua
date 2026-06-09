package = {
    spec = "1",
    homepage = "https://www.pcre.org",
    name = "pcre2",
    description = "Perl Compatible Regular Expressions (v2)",
    maintainers = {"Philip Hazel"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/PCRE2Project/pcre2",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "regex"},
    keywords = {"pcre2", "regex", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "10.42" },
            ["10.42"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/pcre2/releases/download/10.42/pcre2-10.42-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/pcre2/releases/download/10.42/pcre2-10.42-linux-x86_64.tar.gz",
                },
                sha256 = "aba6cf9ee68d23fab2c0198599cf9fce19927bf986b71309c1ce320fb0d0ff1e",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = { "libpcre2-8.so", "libpcre2-8.so.0" }

function install()
    local srcdir = pkginfo.name() .. "-" .. pkginfo.version() .. "-linux-x86_64"
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local libdir = path.join(idir, "lib")
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name)
    for _, lib in ipairs(libs) do
        if os.isfile(path.join(libdir, lib)) then
            xvm.add(lib, { type = "lib", bindir = libdir, filename = lib, alias = lib, binding = binding })
        end
    end
    local sysroot = system.subos_sysrootdir()
    local sys_inc = path.join(sysroot, "usr/include")
    os.mkdir(sys_inc)
    system.exec(string.format("sh -c 'cp -a %s/include/* %s/ 2>/dev/null || true'", idir, sys_inc))
    local sys_pc = path.join(sysroot, "usr/lib/pkgconfig")
    os.mkdir(sys_pc)
    system.exec(string.format(
        "sh -c 'for pc in %s/lib/pkgconfig/*.pc; do [ -f \"$pc\" ] && sed \"s|^prefix=.*|prefix=%s|\" \"$pc\" > %s/$(basename \"$pc\"); done'",
        idir, idir, sys_pc
    ))
    return true
end

function uninstall()
    xvm.remove(package.name)
    for _, lib in ipairs(libs) do xvm.remove(lib) end
    local sysroot = system.subos_sysrootdir()
    system.exec(string.format("sh -c 'rm -f %s/usr/include/pcre2.h %s/usr/lib/pkgconfig/libpcre2-8.pc'", sysroot, sysroot))
    return true
end
