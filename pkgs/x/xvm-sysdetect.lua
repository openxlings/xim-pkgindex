package = {
    spec = "3",
    -- base info
    name = "xvm-sysdetect",
    description = "XVM - System Package Detect Tools",

    authors = {"sunrisepeak"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- xim pkg info
    type = "config",
    status = "stable", -- dev, stable, deprecated
    categories = {"xim", "xvm"},
    keywords = {"xvm", "detect-tool"},

    -- xvm: xlings version management
    xpm = {
        linux = {
            ["latest"] = { },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.fs")
import("xim.libxpkg.path")

local sys_paths = {
    linux = {
        "/usr/bin",
        "/usr/local/bin",
        "/bin",
        "/sbin",
        "/usr/sbin",
        "/usr/local/sbin",
    },
}

local pkgs = {
    "python",
    "gcc",
    "g++",
    "java",
    "make",
    "cmake",
    "git",
}


function install()
    for _, pkg in ipairs(pkgs) do
        for _, p in ipairs(sys_paths.linux) do
            if fs.is_file(path.join(p, pkg)) then
                xvm.add(pkg, { version = "system", bindir = p })
                break
            end
        end
    end
    return true
end

function config()
    log.debug("")
    log.debug("\t run [${yellow bright}xvm use ${green}name${clear} ${yellow bright}system${clear}] switch to system version")
    log.debug("")
    return true
end

function uninstall()
    for _, pkg in ipairs(pkgs) do
        xvm.remove(pkg, "system")
    end
    return true
end