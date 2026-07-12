package = {
    spec = "1",
    -- base info
    name = "seeme-report",
    description = "让别人知道你在干什么 seeme report端",

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
    categories = {},
    keywords = {"python"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            deps = {"python@3"},
            ["latest"] = { ref = "0.0.2" },
            ["0.0.2"] = {
                url = "https://github.com/2412322029/seeme/releases/download/pub/seeme-report.zip",
                sha256 = nil
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    os.tryrm(pkginfo.install_dir()) -- 移除可能存在的老代码
    os.trymv("report", pkginfo.install_dir())
    log.debug("Installing dependencies from requirements.txt...")
    local install_result = os.exec(string.format("pip install -r %s", path.join(pkginfo.install_dir(), "requirement.txt")))-- for win \\
    log.debug("\n${green}run seeme-server first${clear}")
    log.debug("\n${green}run it, use -> seeme-report run${clear} ")
    log.debug("\n${green}run in background, use -> seeme-reportw run${clear}")
    log.debug("\n${green}for help use -> seeme-report -h${clear}")

    return true

end

function config()
    local report_script = path.join(pkginfo.install_dir(), "report.py")

    xvm.add(package.name, {
        alias = "python " .. report_script,
        envs = { REPORT_KEY = "seeme", REPORT_URL = "http://127.0.0.1" },
    })
    xvm.add("seeme-reportw", {
        alias = "pythonw " .. report_script,
        envs = { REPORT_KEY = "seeme", REPORT_URL = "http://127.0.0.1" },
        binding = package.name .. "@" .. pkginfo.version(),
    })
    return true
end

function uninstall()
    xvm.remove(package.name)
    xvm.remove("seeme-reportw")
    return true
end