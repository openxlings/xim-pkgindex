package = {
    spec = "1",
    homepage = "https://invisible-island.net/ncurses/",

    name = "ncurses",
    description = "Terminal control libraries — libtinfo + libncurses (SVr4/XSI curses)",
    maintainers = {"Thomas E. Dickey"},
    licenses = {"MIT"},
    repo = "https://github.com/ThomasDickey/ncurses-snapshots",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"terminal", "library"},
    keywords = {"ncurses", "tinfo", "terminfo", "curses", "lib"},

    xvm_enable = true,

    -- WHY THIS PACKAGE EXISTS — the known closure gap of rule D
    -- (ecosystem-closure design §C6), and the root-layer fix for
    -- mcpp-community/mcpp#392:
    --
    -- xmake and the llvm toolchain binaries NEED `libtinfo.so.6` /
    -- `libncurses.so.6`, and until this package no index recipe provided
    -- either soname. In form H that gap is invisible — the sonames resolve
    -- from the host's ld.so cache on every desktop distro. In form X there
    -- is no host fallback at all (our ld.so's baked cache path exists on no
    -- machine), so the same binaries crash — mcpp#392 is exactly that. Form
    -- H hides closure gaps; form X exposes them. This recipe closes the gap
    -- on the provider side so rule D ("every soname in a form-X closure has
    -- an index provider, host-link deps the only exemption") can hold.
    --
    -- BUILD SHAPE — non-widec + --with-termlib, and both are load-bearing:
    -- the consumers' NEEDED entries name the NON-wide sonames
    -- (`libncurses.so.6`, not `libncursesw.so.6`), so a widec build would
    -- ship a payload that satisfies nobody; and --with-termlib splits
    -- libtinfo out as its own object, which is the soname most consumers
    -- (xmake included) actually link. form/menu/panel ride along in lib/
    -- and are reachable through the payload libdir for any consumer that
    -- declares this package; they get no xvm nodes of their own until
    -- something needs them.
    --
    -- Built via .agents/tools/graphics/build-in-subos.sh with
    -- patches/ncurses-6.5-no-config-script-install.patch (the ncurses6-config
    -- script hard-codes host prefixes and is exactly what the payload check
    -- rejects; consumers use the .pc files instead).
    xpm = {
        linux = {
            deps = { "xim:glibc" },
            ["latest"] = { ref = "6.5" },
            -- CN mirror listed by convention; the gitcode release is
            -- uploaded by the mirror flow after merge.
            ["6.5"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/ncurses/releases/download/6.5/ncurses-6.5-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/ncurses/releases/download/6.5/ncurses-6.5-linux-x86_64.tar.gz",
                },
                sha256 = "8023553b73691daad972e5d4f2aae7088c78dd8b1d2d5e53e2953c09587189a0",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.selfcontain")

-- Only the two sonames the closure gap is about, plus their linker names.
-- form/menu/panel stay unregistered in the payload (see the header note).
local libs = {
    "libtinfo.so", "libtinfo.so.6",
    "libncurses.so", "libncurses.so.6",
}

function install()
    -- The tarball's top directory is `ncurses-<version>` (build-in-subos
    -- publish layout), not the `<name>-<ver>-linux-x86_64` convention zlib
    -- follows — derive nothing, just name it.
    local srcdir = "ncurses-" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())

    -- The payload ships with RUNPATH=$ORIGIN on every .so; seal rewrites
    -- that to $ORIGIN + this package's own closure (glibc) with a fixed
    -- value, so re-running converges. Under `local:` registration (CI's
    -- --add-xpkg path) this import is a truthy no-op proxy and the payload
    -- keeps its as-shipped $ORIGIN — which still resolves libtinfo's only
    -- external NEEDED (libc.so.6) nowhere worse than today.
    selfcontain.seal(pkginfo.install_dir())
    return true
end

function config()
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local binding = package.name .. "@" .. pkginfo.version()

    -- Name-only placeholder: `group`, because the node names no artifact —
    -- a bare add would mint a program node and with it a shim that can only
    -- ever fail (openxlings/xlings#452).
    xvm.add(package.name, { type = "group" })

    for _, lib in ipairs(libs) do
        if os.isfile(path.join(libdir, lib)) then
            xvm.add(lib, {
                type = "lib",
                bindir = libdir,
                filename = lib,
                alias = lib,
                binding = binding,
            })
        end
    end

    -- bin/ (tic, tput, infocmp, clear, reset, ...) is deliberately NOT
    -- registered, twice over:
    --
    --   * these are everyday host commands; claiming the names with shims
    --     would shadow the distro's own tools for every subos user, and the
    --     closure gap this package closes is about .so resolution only.
    --   * measured on the shipped payload: the bin tools carry the BUILD
    --     machine's absolute PT_INTERP (a build-in-subos product), so as
    --     shipped they only run where that exact glibc payload path exists.
    --     The predicate-driven elfpatch rewrites INTERP to this home's
    --     glibc at install time, which repairs them — but that repair is a
    --     runtime property of the installing client, not a contract worth
    --     selling shims on.
    --
    -- share/terminfo ships in the payload; the baked default search stays
    -- /usr/share/terminfo + $HOME/.terminfo + $TERMINFO. Reading the host's
    -- terminfo DATABASE breaks no closure rule — it is data, not code.
    return true
end

function uninstall()
    xvm.remove(package.name)
    for _, lib in ipairs(libs) do
        xvm.remove(lib)
    end
    return true
end
