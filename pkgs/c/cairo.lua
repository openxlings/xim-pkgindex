package = {
    spec = "2",
    homepage = "https://cairographics.org",
    name = "cairo",
    description = "2D graphics library (cairo + cairo-gobject, the GTK rendering base)",
    maintainers = {"The Cairo Team"},
    licenses = {"LGPL-2.1", "MPL-1.1"},
    repo = "https://gitlab.freedesktop.org/cairo/cairo",
    docs = "https://www.cairographics.org/documentation/",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "rendering", "2d"},
    keywords = {"cairo", "graphics", "2d", "gtk", "lib"},
    -- 1.18.4 ships bin/cairo-trace; 1.18.0 shipped no bin/ at all, so
    -- config() registers it only when the payload has it.
    programs = {"cairo-trace"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- The X11 entries arrived with 1.18.4. 1.18.0 was an "xcb-free /
            -- headless build for manim" and needed none of them; 1.18.4 has the
            -- xlib and xcb backends on, because GTK 4's X11 backend goes
            -- through cairo-xlib. Declared for both versions: a lower bound
            -- that an older payload does not exercise costs an install, and
            -- getting it wrong costs a startup failure on somebody else's
            -- machine.
            deps = {
                "xim:glibc@>=2.38",
                "xim:freetype@>=2.13",
                "xim:fontconfig@>=2.15",
                "xim:libpng@>=1.6",
                "xim:pixman@>=0.42",
                "xim:zlib@>=1.3",
                "xim:glib@>=2.80",
                "xim:libX11@>=1.8",
                "xim:libXext@>=1.3",
                "xim:libXrender@>=0.9",
                -- libcairo names libxcb, libxcb-render AND libxcb-shm; all
                -- three come from libxcb. expat used to be here and is not:
                -- nothing in the payload names a soname it provides -- that
                -- reaches cairo through fontconfig, which declares it.
                "xim:libxcb@>=1.17",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            -- WHY 1.18.4 EXISTS HERE
            --
            -- GTK 4 takes cairo-gobject as a HARD dependency -- gtk's
            -- meson.build has `cairogobj_dep = dependency('cairo-gobject',
            -- version: cairo_req)` with no `required: false` -- and the 1.18.0
            -- payload contains libcairo.so and nothing else. No
            -- libcairo-gobject.so, no cairo-gobject.pc. There is no option or
            -- flag that configures gtk4 against it.
            --
            -- 1.18.4 is built with `-Dglib=enabled` and ships 15 .pc files
            -- against 1.18.0's one, including cairo-gobject, cairo-ft,
            -- cairo-xlib and cairo-xcb.
            --
            -- It also drops `prefix=/tmp/cairo-prefix`, which 1.18.0's
            -- cairo.pc has carried since it was published -- a directory that
            -- exists on no machine, papered over by config() rewriting a copy
            -- on its way into the sysroot.
            ["latest"] = { ref = "1.18.4" },
            ["1.18.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/cairo/releases/download/1.18.4/cairo-1.18.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/cairo/releases/download/1.18.4/cairo-1.18.4-linux-x86_64.tar.gz",
                },
                sha256 = "d72cf1d45c0812fa9e823058dec8b8c0e17d403d430e01631801fae29ed2ea30",
            },
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
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    sysroot.adopt_payload()

    selfcontain.seal(pkginfo.install_dir())
    -- Fix the payload's own .pc rather than rewriting a copy per subos, which
    -- is what this recipe used to do. The copy left the PAYLOAD's cairo.pc
    -- saying `prefix=/tmp/cairo-prefix`, and anything reading the payload
    -- directly -- `build-in-subos.sh --deps cairo`, for one -- got that.
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    local bindir = path.join(idir, "bin")
    if os.isfile(path.join(bindir, "cairo-trace")) then
        xvm.add("cairo-trace", { bindir = bindir })
    end

    -- Every linker-facing soname, discovered from the payload rather than
    -- listed here: 1.18.0 ships one library and 1.18.4 ships three
    -- (libcairo, libcairo-gobject, libcairo-script-interpreter), and a
    -- hand-written list would have to name a file the older payload lacks.
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
    xvm.remove("cairo-trace")
    xvm.remove(package.name)
    -- Declared assets are reclaimed with the release; the `rm -rf` that used
    -- to live here belonged to the hand-copied era and deleted a fixed
    -- `cairo.pc`, which would have missed the other fourteen .pc files 1.18.4
    -- installs.
    return true
end
