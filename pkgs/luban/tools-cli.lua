package = {
    spec = "1",

    name = "tools-cli",
    namespace = "luban",
    description = "Luban's command-line tool set: ripgrep, fd, fzf, jq, tmux, htop",

    homepage = "https://github.com/openxlings/xim-pkgindex",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"luban", "tools"},
    keywords = {"luban", "tools"},

    -- What a person reaches for in a terminal (the desktop edition's, design §6.1).
    -- Form: a meta package (design 2026-10-18 §4.6) -- only its deps, each
    -- the index's own package; an edition lists it, anyone may install it.
    xpm = {
        linux = {
            deps = {
                "xim:ripgrep@15.1.0",
                "xim:fd@10.5.0",
                "xim:fzf@0.74.3",
                "xim:jq@1.8.2",
                "xim:tmux@3.8",
                "xim:htop@3.5.3",
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
