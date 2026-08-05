package = {
    spec = "2",

    homepage = "https://gitlab.freedesktop.org/glvnd/libglvnd",
    name = "libglvnd",
    description = "The GL Vendor-Neutral Dispatch library",

    authors = {"NVIDIA Corporation", "libglvnd contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/glvnd/libglvnd",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libglvnd", "graphics", "gl"},

    xpm = {
        linux = {
            deps = { "xim:libX11@>=1.8", "xim:libXext@>=1.3" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.7.0" },
            ["1.7.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libglvnd/releases/download/1.7.0/libglvnd-1.7.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libglvnd/releases/download/1.7.0/libglvnd-1.7.0-linux-x86_64.tar.gz",
                },
                sha256 = "07366016ef25ec20436df65bf94f0dee758d41ec34d0723056690d5c899bf8c8",
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
    os.mv("libglvnd-1.7.0", dir)
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
