package = {
    spec = "1",
    homepage = "https://sourceware.org/libffi",
    name = "libffi",
    description = "Portable foreign-function interface library",
    maintainers = {"The libffi Developers"},
    licenses = {"MIT"},
    repo = "https://github.com/libffi/libffi",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "ffi"},
    keywords = {"libffi", "ffi", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "3.4.4" },
            ["3.4.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libffi/releases/download/3.4.4/libffi-3.4.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libffi/releases/download/3.4.4/libffi-3.4.4-linux-x86_64.tar.gz",
                },
                sha256 = "04797df0fa33a869a6093ee7238b2cf25d478eddb03658db76fd7f5c01f1ebef",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = { "libffi.so", "libffi.so.7" }

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
    system.exec(string.format("sh -c 'rm -f %s/usr/include/ffi.h %s/usr/include/ffitarget.h %s/usr/lib/pkgconfig/libffi.pc'", sysroot, sysroot, sysroot))
    return true
end
