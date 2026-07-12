package = {
    spec = "1",
    -- base info
    name = "seeme-server",
    description = "让别人知道你在干什么 seeme 服务端",

    authors = {"2412322029"},
    contributors = "https://github.com/2412322029/seeme",
    licenses = {""},
    repo = "https://github.com/2412322029/seeme",
    ci = { mirror = true },
    docs = "https://github.com/2412322029/seeme",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"web"},
    keywords = {"flask", "python"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            deps = {"python@3"},
            ["latest"] = { ref = "0.0.2" },
            ["0.0.2"] = {
                url = "https://github.com/2412322029/seeme/releases/download/pub/seeme-server.zip",
                sha256 = nil
            },
        },
        debian = {
            deps = {"python@3"},
            ["latest"] = { ref = "0.0.2" },
            ["0.0.2"] = {
                url = "https://github.com/2412322029/seeme/releases/download/pub/seeme-server.zip",
                sha256 = nil
            },
        },
        ubuntu = { ref = "debian" },
        archlinux = { ref = "debian" },
        manjaro = { ref = "debian" },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")


function install()
    os.tryrm(pkginfo.install_dir())
    os.trymv("server", pkginfo.install_dir())
    log.debug("Installing dependencies from requirements.txt...")
    os.exec(string.format("pip install -r %s", path.join(pkginfo.install_dir(), "requirement.txt")))
    log.debug("\n${green}use -> seeme-server${clear}\n")
    log.debug("\n${green}install seeme-report after${clear}\n")
    return true
end

function config()
    xvm.add("seeme-server", {
        alias = "python " .. path.join(pkginfo.install_dir(), "main.py"),
    })
    return true
end

function uninstall()
    xvm.remove("seeme-server")
    return true
end