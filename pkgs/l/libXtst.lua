package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXtst",
    description = "X11 Testing/Record extension client library — required by the JDK's AWT",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXtst",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxtst", "xtest", "record", "x11", "awt", "jdk"},

    -- WHY THIS IS PACKAGED
    --
    -- Half of what blocks the JDK loader migration. Every JDK's
    -- `libawt_xawt.so` has a hard DT_NEEDED on it:
    --
    --   libawt_xawt.so NEEDED: libawt.so libjava.so libdl.so.2 libm.so.6
    --                          libX11.so.6 libXext.so.6 libXi.so.6
    --                          libXrender.so.1 libXtst.so.6 ...
    --
    -- Switching a JDK's PT_INTERP to our loader REMOVES ALL HOST FALLBACK: our
    -- glibc's compiled-in cache path exists on no machine, and on a multiarch
    -- distro the host's libraries are reachable only through that cache. So the
    -- JDK cannot be switched until its whole closure is ours -- and AWT is the
    -- first thing to die, with an error naming `libawt_xawt.so` rather than the
    -- dependency that is actually missing.
    --
    -- `alsa-lib` (libasound) is the other half. See openxlings/xim-pkgindex#568.

    xpm = {
        linux = {
            -- Exactly the payload's runtime closure, measured:
            --
            --   objdump -p lib/libXtst.so.6.1.0 | grep NEEDED
            --     libX11.so.6  libXext.so.6  libXi.so.6  libc.so.6
            --
            -- `libXfixes` is deliberately NOT here. It is needed to BUILD this --
            -- `xi.pc` carries `Requires: xfixes`, and omitting it fails configure
            -- with `Package 'xfixes', required by 'xi', not found`, an error
            -- naming neither libXtst nor libXi -- but nothing in the payload
            -- links it. libXi declares it, so it arrives transitively at runtime.
            -- Declaring a build-time need as a runtime dep would make this
            -- package's closure claim something the ELF does not.
            deps = {
                "xim:libX11", "xim:libXext@>=1.3", "xim:libXi@>=1.8", "xim:glibc",
            },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.2.5" },
            ["1.2.5"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXtst/releases/download/1.2.5/libXtst-1.2.5-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXtst/releases/download/1.2.5/libXtst-1.2.5-linux-x86_64.tar.gz",
                },
                sha256 = "5974d03284fd77e379f7790d635ff4b9950c40c1a4b17397444c0431dd13680c",
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
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXtst-1.2.5", dir)

    -- The one file the JDK actually opens, asserted by the SONAME it asks for.
    -- `libXtst.so` (the dev symlink) being present says nothing about whether
    -- the runtime name resolves.
    if not os.isfile(path.join(dir, "lib", "libXtst.so.6")) then
        raise("libXtst payload has no lib/libXtst.so.6 -- that is the SONAME "
              .. "libawt_xawt.so has a DT_NEEDED on")
    end

    -- Stamp this payload's own dependency closure onto its libraries, so they
    -- resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(dir)
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())

    -- _tree, not declare_headers: several packages contribute to one `X11/`,
    -- and declaring that directory places it as a single asset -- rename(2)
    -- over the sysroot's copy, so the last install wins and the others vanish.
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
