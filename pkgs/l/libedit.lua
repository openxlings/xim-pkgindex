package = {
    spec = "2",

    homepage = "http://thrysoee.dk/editline/",
    name = "libedit",
    description = "BSD libedit: command-line editing, history, and tokenization library",

    authors = {"Christos Zoulas and contributors"},
    licenses = {"BSD-2-Clause"},
    repo = "http://thrysoee.dk/editline/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"terminal", "lib"},
    keywords = {"libedit", "editline", "readline", "lib"},

    xpm = {
        linux = {
            -- libedit.so.0 carries DT_NEEDED libncurses.so.6 and
            -- libtinfo.so.6 -- the non-widec sonames, matching what
            -- pkgs/n/ncurses.lua's --with-termlib build provides (see
            -- that recipe's header comment on why the split matters).
            deps = { "xim:glibc", "xim:ncurses" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "3.1.20250104" },
            ["3.1.20250104"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libedit/releases/download/3.1.20250104/libedit-3.1.20250104-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libedit/releases/download/3.1.20250104/libedit-3.1.20250104-linux-x86_64.tar.gz",
                    },
                    sha256 = "f029da9ac8f68c7ce58bc2ceab6ae8341efa74f93c2ec8ee332371d39803fc04",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libedit/releases/download/3.1.20250104/libedit-3.1.20250104-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libedit/releases/download/3.1.20250104/libedit-3.1.20250104-linux-aarch64.tar.gz",
                    },
                    sha256 = "6eb88ac124e9493b12a2217d9d0fd204319a2fdf26edfb5b41ba91baabf6ea20",
                },
            },
        },
    },
}

-- Relocatable payload repacked from the conda-forge libedit package
-- (3.1.20250104, linux-64 and linux-aarch64 builds), built against a
-- glibc 2.17 baseline. The conda-forge build string carries a `pl5321`
-- (Perl 5.32.1) tag, an artifact of that feedstock's compiler-stack
-- labeling convention rather than an actual dependency: the package's own
-- recorded `depends` are ncurses/glibc/libgcc only, confirmed by
-- inspecting the upstream package metadata directly rather than trusting
-- the build string.
--
-- Payload contents: lib/*.so* (no static archives), include/ (histedit.h
-- plus the editline/ subdirectory -- a flat, package-owned namespace, so
-- config() uses declare_headers rather than the _tree variant), lib/
-- pkgconfig/libedit.pc, licenses/, and PROVENANCE.md. No bin/: libedit
-- ships no command-line tools of its own.
--
-- RPATH, measured with readelf -d: lib/libedit.so.0 already carried
-- RPATH=$ORIGIN. Reapplied explicitly with patchelf --force-rpath
-- (DT_RPATH, not DT_RUNPATH).
--
-- .pc file carries the conda-forge build machine's placeholder-padded
-- prefix; rewritten here to `prefix=/usr` with ${prefix}-relative
-- libdir/includedir. `Libs.private: -lncurses` is upstream's own value and
-- is left untouched -- it names a linker flag, not a payload path.
--
-- PLACEHOLDER AUDIT: no shipped file embeds the build-prefix placeholder
-- pattern (checked with grep over the whole assembled payload).

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libedit-" .. pkginfo.version(), dir)

    selfcontain.seal(dir)

    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name, { type = "group" })

    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)

    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
