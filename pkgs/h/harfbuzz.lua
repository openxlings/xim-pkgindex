package = {
    spec = "2",
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
            -- The full DT_NEEDED closure of libharfbuzz.so.0, enumerated from
            -- the artifact rather than written from memory: libm/libc
            -- (glibc), libfreetype, libglib-2.0 and libgraphite2. The last
            -- two were missing -- glib because nothing had checked, graphite2
            -- because the index had no such package -- and the symptom was
            -- `-lharfbuzz` failing in a closed SubOS with undefined
            -- references to gr_* while the recipe looked complete.
            deps = {
                "xim:glibc@>=2.38",
                "xim:freetype@2.13.2",
                "xim:glib@>=2.80",
                "xim:graphite2@>=1.3.14",
            },
            -- WHY 14.4.0 IS HERE
            --
            -- The 8.3.0 payload contains exactly one library, libharfbuzz.so,
            -- where upstream installs several. Two consumers need the others:
            --
            --   * GTK 4 takes `harfbuzz-subset` as a HARD dependency
            --     (gtk meson.build:403, no `required: false`), so gtk4 cannot
            --     be configured against 8.3.0 at all.
            --   * pango's pangoft2.pc names `harfbuzz-gobject` in
            --     Requires.private, so `pkg-config --cflags pangoft2` fails --
            --     and gtk4 requires pangoft2 whenever the x11 or wayland
            --     backend is enabled (meson.build:406).
            --
            -- 14.4.0 ships six libraries and six .pc files. Added beside 8.3.0
            -- rather than replacing its bytes: a same-version republish
            -- changes the sha256 under every home that already resolved the
            -- old one. libharfbuzz.so.0 is ABI-stable across this range and
            -- GTK 4.16 asks only for >= 2.6.0, so the published pango and
            -- cairo payloads keep working against it.
            --
            -- 14.x no longer links libgraphite2 (it moved out of the default
            -- build); the dep above stays for 8.3.0, which does.
            ["latest"] = { ref = "14.4.0" },
            ["14.4.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/harfbuzz/releases/download/14.4.0/harfbuzz-14.4.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/harfbuzz/releases/download/14.4.0/harfbuzz-14.4.0-linux-x86_64.tar.gz",
                },
                sha256 = "303a1fb54ae787078e70132ac5883d62b9068a7362d8b412533d87bf0f700a7b",
            },
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
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    sysroot.adopt_payload()

    selfcontain.seal(pkginfo.install_dir())
    -- 8.3.0's .pc says `libdir=${prefix}/lib/x86_64-linux-gnu` -- a
    -- Debian-family build host -- against a payload with a flat lib/.
    -- Rewriting `prefix=` alone leaves pkg-config emitting -L for a directory
    -- that does not exist. It still links, because the subos lib search path
    -- covers it, and then the consumer that stamped its RPATH from
    -- `pkg-config --variable=libdir` dies at startup.
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")

    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Discovered from the payload, not listed here. This recipe used to carry
    -- `local libs = { "libharfbuzz.so", "libharfbuzz.so.0" }`, which is right
    -- for 8.3.0 and names one of the six libraries 14.4.0 installs -- so
    -- libharfbuzz-subset and libharfbuzz-gobject, the two that made the newer
    -- payload worth having, would never have been registered.
    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    sysroot.declare_pkgconfig(idir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    -- Declared assets go with the release. The `rm -f .../harfbuzz.pc` that
    -- used to be here would have left the other five behind.
    return true
end
