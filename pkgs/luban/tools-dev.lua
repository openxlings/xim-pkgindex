package = {
    spec = "1",

    name = "tools-dev",
    namespace = "luban",
    description = "Luban's development tool set: node, python with uv, bun",

    homepage = "https://github.com/openxlings/xim-pkgindex",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"luban", "tools"},
    keywords = {"luban", "tools"},

    -- The languages' runtimes and package managers a project asks for (the agent workspace's and the desktop's).
    -- Form: a meta package (design 2026-10-18 §4.6) -- only its deps, each
    -- the index's own package; an edition lists it, anyone may install it.
    xpm = {
        linux = {
            deps = {
                "xim:node@26.11.1",
                "xim:python@3.15.0",
                "xim:uv@0.12.7",
                "xim:bun@1.3.11",
            },
            ["latest"] = { ref = "2026.10.18.1" },
            ["2026.10.18.1"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
