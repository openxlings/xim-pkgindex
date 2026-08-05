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
            deps = { "xim:libffi@>=3.4", "xim:glibc@2.39" },
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

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("wayland-1.23.1", dir)
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
