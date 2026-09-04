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
            -- Lower bounds, not exact pins. An `@2.80.0` here is not a
            -- statement about compatibility, it is a statement that no sibling
            -- may ever move: the moment glib or cairo publishes a newer
            -- release, a consumer asking for that release and a pango
            -- demanding the old one cannot both be satisfied.
            --
            -- libthai and libXft are additions, and both are things this
            -- payload ALREADY needed:
            --   * libthai -- measured, not inferred: `readelf -d` on this
            --     payload's libpango-1.0.so.0 lists `libthai.so.0` in its
            --     DT_NEEDED. Nothing in the index provided it, so every
            --     installed pango has been resolving it from the host's
            --     /usr/lib. It was the only unresolved soname in the whole
            --     installed stack.
            --   * libXft -- pango.pc names `xft >= 2.0.0` in Requires.private
            --     and pkg-config resolves Requires.private before it answers
            --     anything, so without it `pkg-config --cflags pango` fails
            --     outright. Note this one is NOT in the payload's DT_NEEDED
            --     (no pango library links X at all); it is a pkg-config-time
            --     requirement of the .pc upstream shipped, so the closure
            --     check will report it as declared-but-unused, correctly.
            deps = {
                "xim:glib@>=2.80", "xim:harfbuzz@>=8.3", "xim:fribidi@>=1.0.13",
                "xim:cairo@>=1.18", "xim:freetype@>=2.13", "xim:fontconfig@>=2.15",
                "xim:libthai@>=0.1.30", "xim:libXft@>=2.3.9",
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
import("xim.pkgindex.sysroot")

local libs = {
    "libpango-1.0.so", "libpango-1.0.so.0",
    "libpangocairo-1.0.so", "libpangocairo-1.0.so.0",
    "libpangoft2-1.0.so", "libpangoft2-1.0.so.0",
}

function install()
    sysroot.adopt_payload()

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
    system.exec(string.format(
        "sh -c 'rm -rf %s/usr/include/pango-1.0; rm -f %s/usr/lib/pkgconfig/pango.pc %s/usr/lib/pkgconfig/pangocairo.pc %s/usr/lib/pkgconfig/pangoft2.pc'",
        sysroot, sysroot, sysroot, sysroot
    ))
    return true
end
