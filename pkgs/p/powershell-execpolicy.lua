package = {
    spec = "3",
    -- base info
    name = "powershell-execpolicy",
    description = "fix execution policy issue when open Powershell(load .ps1 file)",

    authors = {"sunrisepeak"},
    licenses = {"Apache-2.0"},

    -- xim pkg info
    type = "bugfix",
    archs = {"x86_64"},
    namespace = "config",

    xpm = {
        windows = {
            ["latest"] = { ref = "0.0.1" },
            ["0.0.1"] = { }
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.system")

function installed()
    local policy = system.run([[powershell -ExecutionPolicy Bypass -Command "Get-ExecutionPolicy -Scope CurrentUser"]]).out:trim()
    if policy == "RemoteSigned" or policy == "Bypass" then
        return true
    else
        return false
    end
end

function install()
    log.info("config current user's execution policy to [ RemoteSigned ] ...")
    --system.exec([[powershell -ExecutionPolicy RemoteSigned -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"]])
    system.run([[powershell -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"]])
    return true
end

function uninstall()
    log.info("config current user's execution policy to [ Restricted ] ...")
    system.exec([[powershell -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Restricted"]])
    return true
end