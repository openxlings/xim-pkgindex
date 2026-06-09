package = {
    spec = "1",
    homepage = "https://freetype.org",

    name = "freetype",
    description = "A freely available software library to render fonts",
    maintainers = {"The FreeType Project"},
    licenses = {"FTL", "GPL-2.0-or-later"},
    repo = "https://gitlab.freedesktop.org/freetype/freetype",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "font", "library"},
    keywords = {"freetype", "font", "rendering", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "2.13.2" },
            ["2.13.2"] = {
                url = {
                    -- CN: switch to gitcode.com/xlings-res/freetype once the mirror is published
                    GLOBAL = "https://github.com/xlings-res/freetype/releases/download/2.13.2/freetype-2.13.2-linux-x86_64.tar.gz",
                    CN     = "https://github.com/xlings-res/freetype/releases/download/2.13.2/freetype-2.13.2-linux-x86_64.tar.gz",
                },
                sha256 = "461bd3493988542edabdda6ac54436e796d2f56055478acfb8efec7aa1cc55ac",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- musl-static from-source build lays libs under lib/x86_64-linux-musl
local LIBSUB = "lib/x86_64-linux-musl"
local libs = { "libfreetype.so", "libfreetype.so.6" }

function install()
    local srcdir = "freetype-" .. pkginfo.version() .. "-linux-x86_64"
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local libdir = path.join(idir, LIBSUB)
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    for _, lib in ipairs(libs) do
        local p = path.join(libdir, lib)
        if os.isfile(p) then
            xvm.add(lib, {
                type = "lib",
                bindir = libdir,
                filename = lib,
                alias = lib,
                binding = binding,
            })
        end
    end

    local sysroot = system.subos_sysrootdir()

    -- headers → sysroot/usr/include/freetype2
    local sys_inc = path.join(sysroot, "usr/include")
    os.mkdir(sys_inc)
    local ft_inc = path.join(idir, "include/freetype2")
    if os.isdir(ft_inc) then
        os.cp(ft_inc, sys_inc, { force = true })
    end

    -- freetype2.pc → sysroot, with prefix rewritten to the install dir
    local sys_pc = path.join(sysroot, "usr/lib/pkgconfig")
    os.mkdir(sys_pc)
    local src_pc = path.join(libdir, "pkgconfig/freetype2.pc")
    if os.isfile(src_pc) then
        system.exec(string.format(
            "sh -c 'sed \"s|^prefix=.*|prefix=%s|\" %s > %s/freetype2.pc'",
            idir, src_pc, sys_pc
        ))
    end

    return true
end

function uninstall()
    xvm.remove(package.name)
    for _, lib in ipairs(libs) do
        xvm.remove(lib)
    end
    local sysroot = system.subos_sysrootdir()
    os.tryrm(path.join(sysroot, "usr/include/freetype2"))
    os.tryrm(path.join(sysroot, "usr/lib/pkgconfig/freetype2.pc"))
    return true
end
