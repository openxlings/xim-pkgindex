package = {
    spec = "1",
    homepage = "https://libexpat.github.io",
    name = "expat",
    description = "Fast streaming XML parser library",
    maintainers = {"The Expat Developers"},
    licenses = {"MIT"},
    repo = "https://github.com/libexpat/libexpat",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"xml", "library"},
    keywords = {"expat", "xml", "parser", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "2.6.2" },
            ["2.6.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/expat/releases/download/2.6.2/expat-2.6.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/expat/releases/download/2.6.2/expat-2.6.2-linux-x86_64.tar.gz",
                },
                sha256 = "2d2c0fffc8d5b2fd5ff25d9945dcab1a6d349e15a55e320ae7de7de161a9ab51",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = { "libexpat.so", "libexpat.so.1" }

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
    system.exec(string.format("sh -c 'rm -f %s/usr/include/expat.h %s/usr/include/expat_external.h %s/usr/lib/pkgconfig/expat.pc'", sysroot, sysroot, sysroot))
    return true
end
