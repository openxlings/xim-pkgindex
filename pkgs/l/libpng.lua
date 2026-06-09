package = {
    spec = "1",
    homepage = "http://www.libpng.org/pub/png/libpng.html",
    name = "libpng",
    description = "Official PNG reference library",
    maintainers = {"PNG Development Group"},
    licenses = {"libpng-2.0"},
    repo = "https://github.com/glennrp/libpng",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "image", "library"},
    keywords = {"libpng", "png", "image", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { "zlib@1.3.1" },
            ["latest"] = { ref = "1.6.43" },
            ["1.6.43"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libpng/releases/download/1.6.43/libpng-1.6.43-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libpng/releases/download/1.6.43/libpng-1.6.43-linux-x86_64.tar.gz",
                },
                sha256 = "e8c23040da7966bb8e3c96ee2ddb70ee86e533503dd362a156ebc516278ae25e",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = { "libpng16.so", "libpng16.so.16" }

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
    os.tryrm(path.join(sysroot, "usr/include/libpng16"))
    system.exec(string.format("sh -c 'rm -f %s/usr/lib/pkgconfig/libpng16.pc'", sysroot))
    return true
end
