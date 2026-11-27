package = {
    spec = "3",

    name = "devcpp",
    description = "Dev-C++: A full-featured Integrated Development Environment (IDE) for the C/C++",
    homepage = "https://sourceforge.net/projects/orwelldevcpp/",
    maintainers = {"Orwell (Johan Mes)"},
    licenses = {"GPL"},
    repo = "https://sourceforge.net/projects/orwelldevcpp/",
    docs = "https://forum.d2learn.org/topic/134",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"ide", "c", "c++"},
    keywords = {"dev-cpp"},

    programs = { "devcpp" },

    xpm = {
        windows = {
            strip = 1,
            deps = { "xim:shortcut-tool", "xim:windows-acp" },
            ["latest"] = { ref = "5.11" },
            ["5.11"] = {
                url = "https://gitcode.com/xlings-res/dev-cpp/releases/download/5.11/dev-cpp-5.11-windows-x86_64.zip",
                sha256 = nil,
            },
            ["chinese"] = {
                url = "https://gitcode.com/xlings-res/dev-cpp/releases/download/chinese/dev-cpp-chinese-windows-x86_64.zip",
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")
import("xim.libxpkg.fs")
import("xim.libxpkg.path")

local function get_appdata_devcpp()
    return path.join(os.getenv("APPDATA"), "Dev-Cpp")
end


function config()
    xvm.add("devcpp")
    system.exec(string.format(
        [[shortcut-tool create --name "Dev-C++ 5.11" --target "%s" --icon "%s"]],
        path.join(pkginfo.install_dir(), "devcpp.exe"),
        path.join(pkginfo.install_dir(), "devcpp.exe")
    ))

    if pkginfo.version() == "chinese" then
        log.info("config Dev-C++ to use Chinese settings...")
        log.info("config-file-dir: " .. get_appdata_devcpp())
        fs.remove(get_appdata_devcpp())
        fs.mkdir(get_appdata_devcpp())
        fs.copy(path.join(pkginfo.install_dir(), "devcpp.ini"), path.join(get_appdata_devcpp(), "devcpp.ini"))
        fs.copy(path.join(pkginfo.install_dir(), "codeinsertion.ini"), path.join(get_appdata_devcpp(), "codeinsertion.ini"))
    end

    local acp = system.run("windows-acp").out
    if acp and acp:trim() == "65001" then
        log.warn("Current system ACP is UTF-8 (65001), use utf-8 encoding in Dev-C++")

        local langdir = path.join(pkginfo.install_dir(), "Lang")
        local lng_file = path.join(langdir, "Chinese.lng")
        local tips_file = path.join(langdir, "Chinese.tips")
        local lng_file_utf8 = path.join(langdir, "chinese", "Chinese.lng.utf8")
        local tips_file_utf8 = path.join(langdir, "chinese", "Chinese.tips.utf8")

        fs.remove(lng_file)
        fs.remove(tips_file)
        fs.copy(lng_file_utf8, lng_file)
        fs.copy(tips_file_utf8, tips_file)
    end

    log.debug([[${yellow}

           ConfigDoc | 配置文档
    https://forum.d2learn.org/topic/134

    ]])

    return true
end

function uninstall()
    xvm.remove("devcpp")
    system.exec(string.format(
        [[shortcut-tool remove --name "Dev-C++ 5.11"]]
    ))
    fs.remove(get_appdata_devcpp())
    return true
end