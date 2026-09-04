package = {
    spec = "2",
    homepage = "https://github.com/tlwg/libdatrie",
    name = "libdatrie",
    description = "Double-array trie library (the trie engine behind libthai)",
    maintainers = {"Theppitak Karoonboonyanan"},
    licenses = {"LGPL-2.1"},
    repo = "https://github.com/tlwg/libdatrie",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "text"},
    keywords = {"datrie", "trie", "text", "lib"},
    programs = {"trietool"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- Here for libthai, which is here for pango. Upstream ships source
            -- only; built from the release tarball in an xlings subos.
            deps = {
                "xim:glibc@>=2.38",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.2.14" },
            ["0.2.14"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libdatrie/releases/download/0.2.14/libdatrie-0.2.14-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libdatrie/releases/download/0.2.14/libdatrie-0.2.14-linux-x86_64.tar.gz",
                },
                sha256 = "5c509113023cbe90de4681d4f9b78cedc2adc495b7562c1c6e4a498a38b8b40c",
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
    sysroot.adopt_payload()

    selfcontain.seal(pkginfo.install_dir())
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)
    -- The payload also ships `trietool-0.2`, the same program under its
    -- versioned name. One xvm node for it is enough; a second would be a
    -- duplicate registration of the same binary.
    xvm.add("trietool", { bindir = path.join(idir, "bin") })


    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    sysroot.declare_pkgconfig(idir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove("trietool")
    xvm.remove(package.name)
    return true
end
