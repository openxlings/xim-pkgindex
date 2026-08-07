package = {
    spec = "1",

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

local function get_appdata_devcpp()
    return path.join(os.getenv("APPDATA"), "Dev-Cpp")
end

function install()
    os.tryrm(pkginfo.install_dir())
    local devcpp_dir = pkginfo.install_file()
        :replace(".zip", "")
    os.mv(devcpp_dir, pkginfo.install_dir())
    return true
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
        os.tryrm(get_appdata_devcpp())
        os.mkdir(get_appdata_devcpp())
        os.cp(path.join(pkginfo.install_dir(), "devcpp.ini"), path.join(get_appdata_devcpp(), "devcpp.ini"))
        os.cp(path.join(pkginfo.install_dir(), "codeinsertion.ini"), path.join(get_appdata_devcpp(), "codeinsertion.ini"))
    end

    local acp = os.iorun("windows-acp")
    if acp and acp:trim() == "65001" then
        log.warn("Current system ACP is UTF-8 (65001), use utf-8 encoding in Dev-C++")

        local langdir = path.join(pkginfo.install_dir(), "Lang")
        local lng_file = path.join(langdir, "Chinese.lng")
        local tips_file = path.join(langdir, "Chinese.tips")
        local lng_file_utf8 = path.join(langdir, "chinese", "Chinese.lng.utf8")
        local tips_file_utf8 = path.join(langdir, "chinese", "Chinese.tips.utf8")

        os.tryrm(lng_file)
        os.tryrm(tips_file)
        os.cp(lng_file_utf8, lng_file)
        os.cp(tips_file_utf8, tips_file)
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
    os.tryrm(get_appdata_devcpp())
    return true
end