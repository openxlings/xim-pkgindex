package = {
    spec = "1",
    homepage = "https://cairographics.org",
    name = "cairo",
    description = "2D graphics library (xcb-free / headless build for manim)",
    maintainers = {"The Cairo Team"},
    licenses = {"LGPL-2.1", "MPL-1.1"},
    repo = "https://gitlab.freedesktop.org/cairo/cairo",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "rendering", "2d"},
    keywords = {"cairo", "graphics", "2d", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { "freetype@2.13.2", "fontconfig@2.15.0", "libpng@1.6.43", "pixman@0.42.2" },
            ["latest"] = { ref = "1.18.0" },
            ["1.18.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/cairo/releases/download/1.18.0/cairo-1.18.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/cairo/releases/download/1.18.0/cairo-1.18.0-linux-x86_64.tar.gz",
                },
                sha256 = "08e83de84aaef49cb1ab03e91832e0a1e88491337ff1fd3a7843b99e2a885a74",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = { "libcairo.so", "libcairo.so.2" }

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
    system.exec(string.format("sh -c 'rm -rf %s/usr/include/cairo; rm -f %s/usr/lib/pkgconfig/cairo.pc'", sysroot, sysroot))
    return true
end
