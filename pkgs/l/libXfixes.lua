package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXfixes",
    description = "X Fixes extension client library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXfixes",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxfixes", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "xim:libX11@>=1.8" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "6.0.1" },
            ["6.0.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXfixes/releases/download/6.0.1/libXfixes-6.0.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXfixes/releases/download/6.0.1/libXfixes-6.0.1-linux-x86_64.tar.gz",
                },
                sha256 = "9e52c227f93b668a2c8fc1ee4c0768226c3e9168010a32466a95339d27dd6974",
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
    os.mv("libXfixes-6.0.1", dir)

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
