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
            -- default: Chinese simplified; use vc6@english for English
            ["latest"] = { ref = "chinese" },
            ["chinese"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vc6/releases/download/6.0-chs/vc6-6.0-chinese-windows-x86_64.zip",
                    CN = "https://gitcode.com/xlings-res/vc6/releases/download/6.0-chs/vc6-6.0-chinese-windows-x86_64.zip",
                },
            },
            ["english"] = "XLINGS_RES",
            -- keep "6.0" as alias for english (backward compat)
            ["6.0"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

local function __shortcut_name()
    if pkginfo.version() == "english" or pkginfo.version() == "6.0" then
        return "Visual C++ 6.0"
    end
    return "Visual C++ 6.0 中文版"
end
local MSDEV_REL = path.join("Common", "MSDev98", "BIN", "MSDEV.EXE")

function installed()
    local msdev = path.join(pkginfo.install_dir(), MSDEV_REL)
    if os.isfile(msdev) then
        return pkginfo.version()
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

    -- Register package.name as binding root
    xvm.add(package.name)

    -- Register IDE launcher to xvm
    xvm.add("msdev", {
        bindir = path.join(pkginfo.install_dir(), "Common", "MSDev98", "BIN"),
        binding = package.name .. "@" .. pkginfo.version(),
    })

    -- Create desktop + start menu shortcut
    system.exec(string.format(
        [[shortcut-tool create --name "%s" --target "%s" --icon "%s"]],
        __shortcut_name(), msdev_path, msdev_path
    ))

    log.info("VC++ 6.0 installed with Windows XP SP3 compatibility mode")

    return true
end

function uninstall()
    -- Remove shortcut (try both names in case version changed)
    pcall(system.exec, string.format(
        [[shortcut-tool remove --name "%s"]], "Visual C++ 6.0 中文版"
    ))
    pcall(system.exec, string.format(
        [[shortcut-tool remove --name "%s"]], "Visual C++ 6.0"
    ))

    -- Unregister from xvm
    xvm.remove(package.name)
    xvm.remove("msdev")

    -- Clean up compatibility registry entry
    local msdev_path = path.join(pkginfo.install_dir(), MSDEV_REL)
    __cleanup_compat_mode(msdev_path)

    -- Remove install directory
    os.tryrm(pkginfo.install_dir())

    return true
end

function __setup_compat_mode(exe_path)
    local cmd = string.format(
        [[reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "%s" /d "~ WINXPSP3 RUNASADMIN" /f]],
        exe_path
    )
    local ok, err = pcall(system.exec, cmd)
    if not ok then
        log.warn("Failed to set compat mode: %s", tostring(err))
    end
end

function __cleanup_compat_mode(exe_path)
    local cmd = string.format(
        [[reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "%s" /f]],
        exe_path
    )
    local ok, err = pcall(system.exec, cmd)
    if not ok then
        log.warn("Failed to clean compat registry: %s", tostring(err))
    end
end
