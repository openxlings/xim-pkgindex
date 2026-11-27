package = {
    spec = "3",
    -- base info

    homepage = "https://github.com/openxlings/xim-pkgindex",

    name = "cpp",
    description = "C++ language toolchain",
    maintainers = {"xim team"},
    contributors = "https://github.com/openxlings/xim-pkgindex/graphs/contributors",

    -- xim pkg info
    type = "config",
    status = "stable", -- dev, stable, deprecated
    categories = { "plang", "compiler", "c" },

    xpm = {
        windows = {
            deps = { "xim:mingw-w64@13" },
            ["latest"] = { ref = "mingw" },
            ["mingw"] = {},
            ["msvc"] = {},
        },
        linux = {
            deps = { "xim:gcc" },
            ["latest"] = { ref = "gnu" },
            ["gnu"] = {},
        },
        macosx = {
            deps = { "xim:brew" },
            ["latest"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.pkgmanager")

function installed()
    if pkginfo.platform() == "macosx" then
        local output = system.run("gcc --version").out
        if not output then
            output = system.run("clang --version").out
        end
        return output ~= nil
    elseif pkginfo.version() == "msvc" then
        -- Check for MSVC cl.exe via vswhere or PATH
        local output = system.run("where cl 2>nul").out or system.run("cl 2>&1").out
        return output ~= nil and output ~= ""
    elseif pkginfo.version() == "mingw" or pkginfo.version() == "gnu" then
        local output = system.run("gcc --version").out
        return output ~= nil and string.find(output:trim(), "gcc", 1, true) ~= nil
    else
        return true
    end
end

function install()
    if pkginfo.platform() == "macosx" then
        pkgmanager.install("gcc")
    elseif pkginfo.version() == "msvc" then
        pkgmanager.install("msvc@2022")
    else
        -- install by deps
    end
    return true
end

function uninstall()
    if pkginfo.platform() == "macosx" then
        pkgmanager.remove("gcc")
    elseif pkginfo.version() == "msvc" then
        pkgmanager.remove("msvc@2022")
    elseif pkginfo.version() == "mingw" then
        pkgmanager.remove("mingw-w64@13")
    elseif pkginfo.version() == "gnu" then
        pkgmanager.remove("gcc")
    end
    return true
end
