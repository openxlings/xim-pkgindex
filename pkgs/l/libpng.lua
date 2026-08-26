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
            deps = { "xim:zlib@1.3.1" },
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
import("xim.pkgindex.sysroot")

local libs = { "libpng16.so", "libpng16.so.16" }

function install()
    local srcdir = pkginfo.name() .. "-" .. pkginfo.version() .. "-linux-x86_64"
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())

    -- The .pc files in this payload say `libdir=${prefix}/lib/x86_64-linux-gnu`
    -- -- a Debian-family build host -- against a payload with a flat lib/.
    -- Rewriting `prefix=` alone (what this recipe did) leaves pkg-config
    -- emitting -L for a directory that does not exist. It still links, because
    -- the subos lib search path covers it, and then the consumer that stamped
    -- its RPATH from `pkg-config --variable=libdir` dies at startup.
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")

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
    -- The payload's .pc files were already pointed at the payload in
    -- install(); copying them verbatim is what keeps that the only answer.
    system.exec(string.format(
        "sh -c 'for pc in %s/lib/pkgconfig/*.pc; do [ -f \"$pc\" ] && cp -f \"$pc\" %s/; done'",
        idir, sys_pc
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
