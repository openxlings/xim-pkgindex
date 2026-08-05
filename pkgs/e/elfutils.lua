package = {
    spec = "2",

    homepage = "https://sourceware.org/elfutils/",
    name = "elfutils",
    description = "ELF object file access library — libelf, for radeonsi",

    authors = {"Red Hat, Inc.", "elfutils contributors"},
    licenses = {"GPL-3.0-or-later", "LGPL-3.0-or-later"},
    repo = "https://sourceware.org/git/elfutils.git",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"elfutils", "graphics", "gl"},

    xpm = {
        linux = {
            deps = { "xim:zlib@>=1.2", "xim:glibc@2.39" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.191" },
            ["0.191"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/elfutils/releases/download/0.191/elfutils-0.191-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/elfutils/releases/download/0.191/elfutils-0.191-linux-x86_64.tar.gz",
                },
                sha256 = "30efe8df032b049f47f6067c32fd86c7f0a253795988f2825cc61675a58f2c61",
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
    os.mv("elfutils-0.191", dir)
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
