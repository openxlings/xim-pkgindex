package = {
    spec = "2",

    homepage = "https://xkbcommon.org",
    name = "libxkbcommon",
    description = "Keymap handling library for Wayland and X11 clients",

    authors = {"xkbcommon contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/xkbcommon/libxkbcommon",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxkbcommon", "graphics", "x11"},

    xpm = {
        linux = {
            deps = {},
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.7.0" },
            ["1.7.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libxkbcommon/releases/download/1.7.0/libxkbcommon-1.7.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libxkbcommon/releases/download/1.7.0/libxkbcommon-1.7.0-linux-x86_64.tar.gz",
                },
                sha256 = "d493b37955b7bd7c24c94d8481a44a933ac462accb2c699e80e312c3bb5a8425",
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
    os.mv("libxkbcommon-1.7.0", dir)
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
