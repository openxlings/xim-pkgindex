package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXinerama",
    description = "X11 Xinerama extension — multi-monitor screen geometry",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXinerama",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxinerama", "graphics", "x11", "multi-monitor"},

    -- Why this is in the stack at all.
    --
    -- It is not on any DT_NEEDED path: mesa does not need it, and nothing in the
    -- rendering closure does. A toolkit dlopens it to ask how many monitors
    -- there are and where they are. So it appears in no dependency graph derived
    -- from ELF metadata, and the surfaceless probe that was this stack's
    -- acceptance criterion could never miss it.
    --
    -- godot found it: with `graphics` installed it stops adding host library
    -- directories to its RPATH, and then printed
    --   libXinerama.so.1: cannot open shared object file
    -- while still starting, because the failure is non-fatal -- it falls back to
    -- single-screen geometry. A non-fatal dlopen failure is exactly the kind of
    -- gap that survives every test that only asks "did it run".
    xpm = {
        linux = {
            deps = { "xim:libX11@>=1.8", "xim:libXext@>=1.3" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.1.5" },
            -- GLOBAL only, and that is a known gap rather than an oversight:
            -- `gtc` can publish a RELEASE into an existing GitCode project but
            -- cannot create the project itself, and `xlings-res/libXinerama`
            -- does not exist on GitCode yet. A CN URL pointing at a missing
            -- project would be worse than none -- it fails at download time
            -- instead of falling back. Add the mirror table once the project is
            -- created; the payload is byte-identical either way (sha256 below).
            ["1.1.5"] = {
                url = "https://github.com/xlings-res/libXinerama/releases/download/1.1.5/libXinerama-1.1.5-linux-x86_64.tar.gz",
                sha256 = "8dfb7eb3459d920f6cc8209ee7db0a1b84cb3b4687f23f7a70442ee5c69802b3",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXinerama-1.1.5", dir)
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)
    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())

    -- _tree, not declare_headers: this contributes `X11/extensions/Xinerama.h`
    -- to an `X11/` directory eight other packages also write into. Declaring
    -- that directory would place it as one asset -- rename(2) over the sysroot's
    -- copy -- so the last install wins and the others vanish.
    if not sysroot.declare_headers_tree(pkginfo.install_dir(), "include",
                                        "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(pkginfo.install_dir(), "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
