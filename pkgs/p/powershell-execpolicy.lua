package = {
    spec = "1",
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
    local policy = os.iorun([[powershell -ExecutionPolicy Bypass -Command "Get-ExecutionPolicy -Scope CurrentUser"]]):trim()
    if policy == "RemoteSigned" or policy == "Bypass" then
        return true
    else
        return false
    end
end

function install()
    log.info("config current user's execution policy to [ RemoteSigned ] ...")
    --system.exec([[powershell -ExecutionPolicy RemoteSigned -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"]])
    os.iorun([[powershell -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"]])
    return true
end

function uninstall()
    log.info("config current user's execution policy to [ Restricted ] ...")
    system.exec([[powershell -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Restricted"]])
    return true
end