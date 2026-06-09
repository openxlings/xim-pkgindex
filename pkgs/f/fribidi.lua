package = {
    spec = "1",
    homepage = "https://github.com/fribidi/fribidi",
    name = "fribidi",
    description = "Free Implementation of the Unicode Bidirectional Algorithm",
    maintainers = {"The FriBidi Developers"},
    licenses = {"LGPL-2.1"},
    repo = "https://github.com/fribidi/fribidi",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "text", "unicode"},
    keywords = {"fribidi", "bidi", "unicode", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "1.0.13" },
            ["1.0.13"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/fribidi/releases/download/1.0.13/fribidi-1.0.13-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/fribidi/releases/download/1.0.13/fribidi-1.0.13-linux-x86_64.tar.gz",
                },
                sha256 = "c502b6094d11edba64f7d907457eb1e28747fa8ff0fb251bf3b8e0b4c53d49cc",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = { "libfribidi.so", "libfribidi.so.0" }

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
    system.exec(string.format("sh -c 'rm -rf %s/usr/include/fribidi; rm -f %s/usr/lib/pkgconfig/fribidi.pc'", sysroot, sysroot))
    return true
end
