package = {
    spec = "1",

    name = "tools-agent",
    namespace = "luban",
    description = "Luban's agent tool set: claude, codex, pi, opencode (and dsh on x86_64)",

    homepage = "https://github.com/openxlings/xim-pkgindex",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"luban", "tools"},
    keywords = {"luban", "tools"},

    -- The coding agents. Not pinned: an agent changes weekly and is wanted as it is now; `luban upgrade` moves them.
    -- Form: a meta package (design 2026-10-18 §4.6) -- only its deps, each
    -- the index's own package; an edition lists it, anyone may install it.
    xpm = {
        linux = {
            deps = {
                "xim:claude",
                "xim:codex",
                "xim:pi",
                "xim:opencode",
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

-- dsh: upstream builds x86_64 only.
local recipe_arch = (os.arch and os.arch())
if not (recipe_arch == "aarch64" or recipe_arch == "arm64") then
    table.insert(package.xpm.linux.deps, "xim:dsh")
end
