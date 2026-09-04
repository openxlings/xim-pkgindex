package = {
    spec = "1",
    homepage = "https://freetype.org",

    name = "freetype",
    description = "A freely available software library to render fonts",
    maintainers = {"The FreeType Project"},
    licenses = {"FTL", "GPL-2.0-or-later"},
    repo = "https://gitlab.freedesktop.org/freetype/freetype",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "font", "library"},
    keywords = {"freetype", "font", "rendering", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.38" },
            -- elfpatch appends this to a consumer's RPATH, which is what makes
            -- `deps = { "xim:freetype@2.13.2" }` enough for godot and friends
            -- to resolve libfreetype.so.6 with no LD_LIBRARY_PATH plumbing.
            --
            -- `lib`, flat, like every other library payload in this index. The
            -- 2.13.2 asset was rebuilt on 2026-08-26 for exactly that reason
            -- (#687): it used to ship its libraries under
            -- lib/x86_64-linux-musl, the index's only such shape, so every
            -- generic sysroot helper needed an exception for this one package
            -- -- and a missing exception does not fail, it just quietly
            -- registers nothing. The rebuild also dropped two build-machine
            -- artefacts: a RUNPATH naming the builder's subos, and a
            -- `prefix=<builder home>/xpkgs/fromsource-x-freetype/...` inside
            -- the shipped .pc. SONAME and DT_NEEDED are unchanged, so the five
            -- recipes pinning @2.13.2 keep working.
            exports = {
                runtime = {
                    libdirs = { "lib" },
                },
            },
            ["latest"] = { ref = "2.13.2" },
            ["2.13.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/freetype/releases/download/2.13.2/freetype-2.13.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/freetype/releases/download/2.13.2/freetype-2.13.2-linux-x86_64.tar.gz",
                },
                sha256 = "a6c64a5008ec26917c769dd9840bf4f8d207e5a41f9ac48a8a9f2dc416af2664",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.sysroot")

-- The payload published before 2026-08-26 for this same version. Kept only to
-- recognise it: a home that installed 2.13.2 earlier still has that tree on
-- disk, and `xlings install` will not re-fetch what it considers present. Then
-- config() would look in `lib`, find nothing, register nothing, and every
-- consumer would quietly lose its libfreetype entry -- so the mismatch is
-- reported instead. Delete this once the old shape can no longer be in the
-- wild. See openxlings/xim-pkgindex#687.
local LEGACY_LIBSUB = "lib/x86_64-linux-musl"

function install()
    -- `freetype-<ver>`, not `freetype-<ver>-linux-x86_64`: the rebuilt asset
    -- is packed by build-in-subos.sh, whose top-level directory is
    -- <name>-<version> like every other payload that harness produces.
    local srcdir = "freetype-" .. pkginfo.version()
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())

    -- prefix=/usr as built; point it at the payload so the .pc can be
    -- declared rather than copied-and-rewritten per subos.
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    if not os.isdir(path.join(idir, "lib")) then
        raise(string.format(
            "this freetype payload has no lib/ -- it is the pre-2026-08-26 "
            .. "%s layout, which this recipe no longer reads. Reinstall it: "
            .. "`xlings remove freetype@%s` then `xlings install freetype`.",
            LEGACY_LIBSUB, pkginfo.version()))
    end

    xvm.add(package.name)

    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    -- declare_headers, not _tree: `freetype2/` is a name this package owns,
    -- so one asset for the directory is right and cheaper than 200 leaves.
    if not sysroot.declare_headers(idir, "include", "usr/include", binding) then
        sysroot.install_headers(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    -- install() already pointed the payload's .pc at the payload, so there is
    -- nothing left to rewrite per subos and no `.sysroot.pc` twin to generate.
    if not sysroot.declare_headers(idir, "lib/pkgconfig",
                                   "usr/lib/pkgconfig", binding) then
        local sysroot_pc = path.join(system.subos_sysrootdir(), "usr/lib/pkgconfig")
        os.mkdir(sysroot_pc)
        system.exec(string.format(
            "sh -c 'for pc in %s/lib/pkgconfig/*.pc; do [ -f \"$pc\" ] && cp -f \"$pc\" %s/; done'",
            idir, sysroot_pc))
    end
    return true
end

function uninstall()
    xvm.remove(package.name)

    -- Nothing by hand. xlings reclaims declared assets on every path that
    -- gives a release up -- full uninstall, detach, a re-registration that
    -- stops declaring a destination, and a `use` down to a smaller asset set
    -- (openxlings/xlings#423, fixed in 2026.8.26.1). The hand-written mirror
    -- that used to live here is gone; the numbers that justify its removal,
    -- and what an older client does without it, are on
    -- `sysroot.declare_headers` in libs/sysroot.lua.
    return true
end
