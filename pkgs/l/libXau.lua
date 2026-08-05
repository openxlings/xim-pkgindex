package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXau",
    description = "X11 authorisation protocol library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXau",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxau", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "xim:xorgproto@>=2024" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.0.11" },
            ["1.0.11"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXau/releases/download/1.0.11/libXau-1.0.11-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXau/releases/download/1.0.11/libXau-1.0.11-linux-x86_64.tar.gz",
                },
                sha256 = "07df5c69c4e1c9480e0f0e98f18bcb0d9e25990e994f8f77540fb69f6b55dfb5",
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
    os.mv("libXau-1.0.11", dir)
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
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
