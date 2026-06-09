package = {
    spec = "1",
    homepage = "https://www.freedesktop.org/wiki/Software/fontconfig/",
    name = "fontconfig",
    description = "Library for configuring and customizing font access",
    maintainers = {"The Fontconfig Developers"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/fontconfig/fontconfig",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "font", "library"},
    keywords = {"fontconfig", "font", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { "freetype@2.13.2", "expat@2.6.2" },
            ["latest"] = { ref = "2.15.0" },
            ["2.15.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/fontconfig/releases/download/2.15.0/fontconfig-2.15.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/fontconfig/releases/download/2.15.0/fontconfig-2.15.0-linux-x86_64.tar.gz",
                },
                sha256 = "dfe6869d6b615414deb0c818a195a9f2b8cb8ad10789376dfa6ce9c2a1e3135f",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = { "libfontconfig.so", "libfontconfig.so.1" }

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
    system.exec(string.format("sh -c 'rm -rf %s/usr/include/fontconfig; rm -f %s/usr/lib/pkgconfig/fontconfig.pc'", sysroot, sysroot))
    return true
end
