package = {
    spec = "1",
    homepage = "https://harfbuzz.github.io",
    name = "harfbuzz",
    description = "OpenType text shaping engine",
    maintainers = {"The HarfBuzz Developers"},
    licenses = {"MIT"},
    repo = "https://github.com/harfbuzz/harfbuzz",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "text", "library"},
    keywords = {"harfbuzz", "text", "shaping", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { "freetype@2.13.2" },
            ["latest"] = { ref = "8.3.0" },
            ["8.3.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/harfbuzz/releases/download/8.3.0/harfbuzz-8.3.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/harfbuzz/releases/download/8.3.0/harfbuzz-8.3.0-linux-x86_64.tar.gz",
                },
                sha256 = "2a2bee694e8db83263e81d2b9c568583920dc63d13f7738b408b3659d38cc159",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = { "libharfbuzz.so", "libharfbuzz.so.0" }

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
    system.exec(string.format("sh -c 'rm -rf %s/usr/include/harfbuzz; rm -f %s/usr/lib/pkgconfig/harfbuzz.pc'", sysroot, sysroot))
    return true
end
