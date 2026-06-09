package = {
    spec = "1",
    homepage = "https://pango.gnome.org",
    name = "pango",
    description = "Library for layout and rendering of internationalized text",
    maintainers = {"The GNOME Project"},
    licenses = {"LGPL-2.1"},
    repo = "https://gitlab.gnome.org/GNOME/pango",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "text", "library"},
    keywords = {"pango", "text", "layout", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- fromsource 漏了 glib/fribidi, 这里补全(pango 运行时确需)
            deps = {
                "glib@2.80.0", "harfbuzz@8.3.0", "fribidi@1.0.13",
                "cairo@1.18.0", "freetype@2.13.2", "fontconfig@2.15.0",
            },
            ["latest"] = { ref = "1.52.1" },
            ["1.52.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/pango/releases/download/1.52.1/pango-1.52.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/pango/releases/download/1.52.1/pango-1.52.1-linux-x86_64.tar.gz",
                },
                sha256 = "cb6334fb3e075afc173f23197c6854c1fe42b391c5bae5ee882a914f7f19c31b",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = {
    "libpango-1.0.so", "libpango-1.0.so.0",
    "libpangocairo-1.0.so", "libpangocairo-1.0.so.0",
    "libpangoft2-1.0.so", "libpangoft2-1.0.so.0",
}

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
    system.exec(string.format(
        "sh -c 'rm -rf %s/usr/include/pango-1.0; rm -f %s/usr/lib/pkgconfig/pango.pc %s/usr/lib/pkgconfig/pangocairo.pc %s/usr/lib/pkgconfig/pangoft2.pc'",
        sysroot, sysroot, sysroot, sysroot
    ))
    return true
end
