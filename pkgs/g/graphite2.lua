package = {
    spec = "2",

    homepage = "https://graphite.sil.org",
    name = "graphite2",
    description = "Font rendering engine for complex scripts (libgraphite2)",

    authors = {"SIL International"},
    licenses = {"LGPL-2.1-or-later", "MPL-2.0"},
    repo = "https://github.com/silnrsi/graphite",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "font", "library"},
    keywords = {"graphite2", "font", "shaping", "lib"},

    xpm = {
        linux = {
            -- libc and nothing else: graphite2 is C++ but is built without
            -- exceptions or RTTI and does not link libstdc++, so this needs
            -- no gcc-runtime. Checked with readelf, not assumed.
            deps = { "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.3.14" },
            ["1.3.14"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/graphite2/releases/download/1.3.14/graphite2-1.3.14-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/graphite2/releases/download/1.3.14/graphite2-1.3.14-linux-x86_64.tar.gz",
                },
                sha256 = "67c266c33a1dad67a5a5f6caed964108710f594a837393c87f6abef9b8425124",
            },
        },
    },
}

-- What needs this is HarfBuzz: libharfbuzz.so.0 names libgraphite2.so.3 in
-- its DT_NEEDED, and with no graphite2 in the index, `-lharfbuzz` inside a
-- closed SubOS failed with undefined references to gr_make_face_with_ops,
-- gr_face_find_fref and the rest of the gr_* API. Same shape as the
-- gio -> libmount/libselinux gap closed in #680.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("graphite2-" .. pkginfo.version(), dir)

    -- Stamp this payload's own dependency closure onto its libraries, so they
    -- resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(dir)

    -- graphite2.pc is the shape with NO variables at all -- it hardcodes
    -- `Libs: -L/usr/lib -lgraphite2` and `Cflags: -I/usr/include`, so before
    -- this call it hands every consumer the HOST's /usr/lib, which on most
    -- machines exists and holds a different library.
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    -- Binding root first: xvm refuses a registration whose binding names a
    -- node the recipe never registered.
    xvm.add(package.name)

    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    -- declare_headers, not _tree: `graphite2/` is a name this package owns.
    if not sysroot.declare_headers(idir, "include", "usr/include", binding) then
        sysroot.install_headers(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    sysroot.declare_pkgconfig(idir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)

    -- Declared file assets are not reclaimed by `xlings remove` on the
    -- clients shipping today (openxlings/xlings#423), so the hook removes
    -- what it declared -- by name, because `usr/include` is shared.
    local sysroot_dir = system.subos_sysrootdir()
    system.exec(string.format(
        "sh -c 'rm -rf %s/usr/include/graphite2; rm -f %s/usr/lib/pkgconfig/graphite2.pc'",
        sysroot_dir, sysroot_dir
    ))
    return true
end
