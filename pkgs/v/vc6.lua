package = {
    spec = "1",

    name = "vc6",
    description = "Visual C++ 6.0: Classic C/C++ IDE (portable for Windows 10/11)",
    homepage = "https://en.wikipedia.org/wiki/Visual_C%2B%2B#32-bit_versions",
    licenses = {"Proprietary"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"ide", "c", "c++"},
    keywords = {"visual-c++", "vc6", "msvc6", "vc++6.0"},

    programs = { "msdev" },

    xpm = {
        windows = {
            deps = { "shortcut-tool" },
            ["latest"] = { ref = "6.0" },
            ["6.0"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

local SHORTCUT_NAME = "Visual C++ 6.0"
local MSDEV_REL = path.join("Common", "MSDev98", "Bin", "MSDEV.EXE")

function installed()
    local msdev = path.join(pkginfo.install_dir(), MSDEV_REL)
    if os.isfile(msdev) then
        return "6.0"
    end
    return nil
end

function install()
    os.tryrm(pkginfo.install_dir())
    local extracted = pkginfo.install_file():replace(".zip", "")
    os.mv(extracted, pkginfo.install_dir())
    return true
end

function config()
    local msdev_path = path.join(pkginfo.install_dir(), MSDEV_REL)

    -- Set Windows XP SP3 compatibility mode + RunAsAdmin via registry
    __setup_compat_mode(msdev_path)

    -- Register IDE launcher to xvm
    xvm.add("msdev", {
        bindir = path.join(pkginfo.install_dir(), "Common", "MSDev98", "Bin"),
    })

    -- Create desktop + start menu shortcut
    system.exec(string.format(
        [[shortcut-tool create --name "%s" --target "%s" --icon "%s"]],
        SHORTCUT_NAME, msdev_path, msdev_path
    ))

    log.info("VC++ 6.0 installed with Windows XP SP3 compatibility mode")

    return true
end

function uninstall()
    -- Remove shortcut
    system.exec(string.format(
        [[shortcut-tool remove --name "%s"]], SHORTCUT_NAME
    ))

    -- Unregister from xvm
    xvm.remove("msdev")

    -- Clean up compatibility registry entry
    local msdev_path = path.join(pkginfo.install_dir(), MSDEV_REL)
    __cleanup_compat_mode(msdev_path)

    return true
end

function __setup_compat_mode(exe_path)
    local cmd = string.format(
        [[reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "%s" /d "~ WINXPSP3 RUNASADMIN" /f]],
        exe_path
    )
    try { function() os.run(cmd) end, catch = function(e)
        log.warn("Failed to set compat mode: %s", tostring(e))
    end }
end

function __cleanup_compat_mode(exe_path)
    local cmd = string.format(
        [[reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "%s" /f]],
        exe_path
    )
    try { function() os.run(cmd) end, catch = function(e)
        log.warn("Failed to clean compat registry: %s", tostring(e))
    end }
end
