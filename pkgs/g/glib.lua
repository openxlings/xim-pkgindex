package = {
    spec = "2",
    homepage = "https://gitlab.gnome.org/GNOME/glib",
    name = "glib",
    description = "Low-level core library (GLib/GObject/GIO)",
    maintainers = {"The GNOME Project"},
    licenses = {"LGPL-2.1"},
    repo = "https://gitlab.gnome.org/GNOME/glib",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "gnome"},
    keywords = {"glib", "gobject", "gio", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {
                "xim:glibc@>=2.38",
                "xim:libffi@3.4.4",
                "xim:zlib@1.3.1",
                "xim:pcre2@10.42",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.80.0" },
            ["2.80.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/glib/releases/download/2.80.0/glib-2.80.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/glib/releases/download/2.80.0/glib-2.80.0-linux-x86_64.tar.gz",
                },
                sha256 = "acc0a845d0591d3cf178d0ca140254563024dd087d34e19b324f21799180ccb6",
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
    local srcdir = pkginfo.name() .. "-" .. pkginfo.version() .. "-linux-x86_64"
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())

    selfcontain.seal(pkginfo.install_dir())
    relocate_pkgconfig(pkginfo.install_dir())
    return true
end

-- Rewrite the payload's own .pc files, once, at install time.
--
-- This artifact was built on a Debian-family host, so every .pc ships
-- `prefix=/usr` and `libdir=${prefix}/lib/x86_64-linux-gnu` while the payload
-- puts its libraries in a flat `lib/`. Rewriting only `prefix` -- what this
-- recipe did before -- leaves pkg-config emitting
-- -L<payload>/lib/x86_64-linux-gnu, a directory that does not exist. It still
-- LINKS inside a subos, because declare_libs has meanwhile put the sonames on
-- the implicit search path, so the damage shows up one step later: a consumer
-- that stamps its RPATH from `pkg-config --variable=libdir` (meson, cmake,
-- libtool all do) builds clean and then dies at startup with
-- `libgobject-2.0.so.0: cannot open shared object file`. Measured both ways in
-- a sandboxed subos.
--
-- In the PAYLOAD, not into the sysroot, because the answer is the same for
-- every subos that mounts this payload: prefix is the payload's own absolute
-- path. Writing it here makes the file correct at its source, which is what
-- lets config() DECLARE it instead of copying a rewritten duplicate per subos.
function relocate_pkgconfig(idir)
    local pcdir = path.join(idir, "lib", "pkgconfig")
    if not os.isdir(pcdir) then return end
    system.exec(string.format(
        "sh -c 'for pc in %s/*.pc; do [ -f \"$pc\" ] || continue; "
        .. "sed -i -e \"s|^prefix=.*|prefix=%s|\" -e \"s|^libdir=.*|libdir=%s/lib|\" \"$pc\"; done'",
        pcdir, idir, idir))

    -- R4: check the artifact, not the intent. A sed that matched nothing is
    -- indistinguishable from a sed that worked, and the difference only
    -- surfaces as a link or startup failure in somebody else's package.
    for _, name in ipairs(sysroot.entries(pcdir)) do
        if name:find("%.pc$") then
            local pc = "\n" .. (io.readfile(path.join(pcdir, name)) or "")
            if not pc:find("\nlibdir=" .. idir .. "/lib\n", 1, true) then
                -- string.format, not raise's varargs: this client passes the
                -- message through verbatim, so a %s left for it to fill
                -- reaches the user as the literal "%s". Verified by making
                -- the check fail on purpose.
                raise(string.format(
                    "pkgconfig relocation left %s with a libdir that is not "
                    .. "%s/lib; a consumer would link against a directory that "
                    .. "does not exist", name, idir))
            end
        end
    end
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Register every linker-facing soname at its exact release version. This
    -- materializes <subos>/lib entries for GNU ld as well as lld.
    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    -- pkg-config metadata, DECLARED like the headers rather than copied.
    -- install() already made the payload's own .pc files correct, so there is
    -- nothing left to rewrite per subos -- the asset is the payload file, and
    -- the names in lib/pkgconfig are ours, so the non-recursive helper is the
    -- right one. The fallback keeps clients without `xvm.files` working
    -- exactly as before.
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

    -- `xvm.files` assets are declared, but on this client they are not
    -- reclaimed. Measured on xlings 2026.8.22.4, in a subos holding glib and
    -- nothing else, so no other binding can be claiming the paths:
    --
    --     after install   lib nodes 15   header assets 274   pc assets 5
    --     after remove    lib nodes  0   header assets 274   pc assets 5
    --
    -- The `type = "lib"` nodes go with xvm.remove(binding); the file assets
    -- stay, pointing into a payload this subos no longer uses. So the hook
    -- still removes both trees by hand -- a duplicate of what the declaration
    -- already says, kept only until a client reclaims them. Re-run that
    -- measurement before deleting this; a green install proves nothing about
    -- removal.
    --
    -- glibconfig.h lives inside glib-2.0/ in this artifact (not in
    -- lib/glib-2.0/include as on a distro), so the one tree covers it.
    local sysroot_dir = system.subos_sysrootdir()
    system.exec(string.format(
        "sh -c 'rm -rf %s/usr/include/glib-2.0; rm -f %s/usr/lib/pkgconfig/glib-2.0.pc %s/usr/lib/pkgconfig/gobject-2.0.pc %s/usr/lib/pkgconfig/gio-2.0.pc %s/usr/lib/pkgconfig/gmodule-2.0.pc %s/usr/lib/pkgconfig/gthread-2.0.pc'",
        sysroot_dir, sysroot_dir, sysroot_dir, sysroot_dir, sysroot_dir, sysroot_dir
    ))
    return true
end
