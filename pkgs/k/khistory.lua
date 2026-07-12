-- TODO: Linux 运行时缺 libglfw.so.3，需要在 xpm.linux 中添加 deps 或在描述中注明需 sudo apt install libglfw3

package = {
    spec = "1",
    -- base info
    name = "khistory",
    description = "An elegant keyboard/gamepad key detection and visualization tool",

    authors = {"Sunrisepeak"},
    maintainers = {"Sunrisepeak"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/Sunrisepeak/KHistory",
    ci = { mirror = true },

    -- xim pkg info
    type = "package",

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "pre-v0.0.5" },
            ["pre-v0.0.5"] = {
                url = "https://github.com/Sunrisepeak/KHistory/releases/download/pre-v0.0.5/khistory-pre-v0.0.5-win-x86_64.exe",
                sha256 = nil
            },
        },
        linux = {
            ["latest"] = { ref = "pre-v0.0.5" },
            ["pre-v0.0.5"] = {
                url = "https://github.com/Sunrisepeak/KHistory/releases/download/pre-v0.0.5/khistory-pre-v0.0.5-linux-x86_64",
                sha256 = nil
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    if os.host() == "linux" then
        os.exec("chmod 775 " .. pkginfo.install_file())
    end
    os.mkdir(pkginfo.install_dir())
    os.mv(pkginfo.install_file(), path.join(pkginfo.install_dir(), _exe_filename_by_version(pkginfo.version())))
    return true
end

function config()

    xvm.add("khistory", {
        bindir = pkginfo.install_dir(),
        alias = _exe_filename_by_version(pkginfo.version()),
    })

    return true
end

function uninstall()
    xvm.remove("khistory")
    return true
end

function _exe_filename_by_version(version)
    if os.host() == "windows" then
        return string.format("khistory-%s-win-x86_64.exe", version)
    else
        return string.format("khistory-%s-linux-x86_64", version)
    end
end