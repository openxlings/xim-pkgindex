package = {
    spec = "2",

    homepage = "https://wayland.freedesktop.org",
    name = "wayland",
    description = "Wayland protocol library and scanner",

    authors = {"Wayland contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/wayland/wayland",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"wayland", "graphics", "gl"},

    xpm = {
        linux = {
            -- libxml2 and expat are for `bin/wayland-scanner`, not for the
            -- libraries, and that is why they were missing for so long.
            --
            -- Measured on the 1.23.1 payload, 2026-08-08. Its full DT_NEEDED set
            -- across every ELF member is:
            --
            --   libc.so.6  libffi.so.8  libwayland-client.so.0
            --   libexpat.so.1  libxml2.so.2
            --
            -- and the payload itself ships neither expat nor libxml2. Only
            -- libffi and glibc were declared, so `xlings install wayland` on a
            -- clean machine produced a wayland-scanner that cannot start:
            --
            --   wayland-scanner: error while loading shared libraries:
            --   libxml2.so.2: cannot open shared object file
            --
            -- It went unnoticed because the LIBRARY half is fine --
            -- libwayland-client needs only libffi and libc -- so a GL or EGL
            -- program works and nothing hints that the code generator is broken.
            -- It only surfaced when mesa's build invoked wayland-scanner, 1957
            -- targets in, with an error naming neither wayland nor mesa.
            --
            -- Floors, not pins: both are ABI-stable and the consumer only needs
            -- them present. 2.13.5 and 2.6.x are what the index carries.
            deps = {
                "xim:libffi@>=3.4",
                "xim:libxml2@>=2.12",
                "xim:expat@>=2.6",
                "xim:glibc@>=2.38",
            },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.23.1" },
            ["1.23.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/wayland/releases/download/1.23.1/wayland-1.23.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/wayland/releases/download/1.23.1/wayland-1.23.1-linux-x86_64.tar.gz",
                },
                sha256 = "5132067ff533ea627a0335dfeaab9612889842ffbdd26148c9306993c41f6ea2",
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
    os.mv("wayland-1.23.1", dir)

    -- Stamp this payload's own dependency closure onto its libraries, so they
    -- resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(pkginfo.install_dir())

    -- This payload's .pc files were never published; see
    -- sysroot.declare_pkgconfig. Relocate here, declare in config().
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())

    -- Headers into the subos sysroot, so a compiler in this subos can build
    -- against this package, not only run it. Declared rather than copied, so
    -- xlings removes them with the package.
    --
    -- _tree, not declare_headers: eight packages in this stack contribute to
    -- one `X11/`, and declaring that directory places it as a single asset --
    -- rename(2) over the sysroot's copy, so the last install wins and the
    -- other seven vanish. See libs/sysroot.lua for why neither of the
    -- non-recursive helpers can express a shared namespace.
    if not sysroot.declare_headers_tree(pkginfo.install_dir(), "include",
                                        "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(pkginfo.install_dir(), "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end
    sysroot.declare_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig", binding)

    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
