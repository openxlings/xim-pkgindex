package = {
    spec = "1",
    homepage = "https://pixman.org",

    name = "pixman",
    description = "Low-level pixel manipulation library (cairo backend)",
    maintainers = {"The Pixman Project"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/pixman/pixman",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "library"},
    keywords = {"pixman", "pixel", "graphics", "cairo"},

    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "0.42.2" },
            ["0.42.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/pixman/releases/download/0.42.2/pixman-0.42.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/pixman/releases/download/0.42.2/pixman-0.42.2-linux-x86_64.tar.gz",
                },
                sha256 = "8b721ae3ae5ea1006245b0253684ed29ec5208751e9e6684b6e0abd7f27494cf",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

-- 通用二进制包安装: tarball 内是 <pkg>-<ver>-linux-x86_64/{lib,include,lib/pkgconfig}
local libs = { "libpixman-1.so", "libpixman-1.so.0" }

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
    -- headers → sysroot/usr/include
    local sys_inc = path.join(sysroot, "usr/include")
    os.mkdir(sys_inc)
    local inc = path.join(idir, "include")
    if os.isdir(inc) then
        system.exec(string.format("sh -c 'cp -a %s/* %s/ 2>/dev/null || true'", inc, sys_inc))
    end
    -- *.pc → sysroot, prefix 重写到 install dir
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
    os.tryrm(path.join(sysroot, "usr/include/pixman-1"))
    system.exec(string.format("sh -c 'rm -f %s/usr/lib/pkgconfig/pixman-1.pc'", sysroot))
    return true
end
