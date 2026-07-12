package = {
    spec = "1",
    -- base info
    name = "sourcetrail",
    description = "Sourcetrail - free and open-source interactive source explorer",

    contributors = "https://github.com/CoatiSoftware/Sourcetrail/graphs/contributors",
    licenses = {"GPL-3.0"},
    repo = "https://github.com/CoatiSoftware/Sourcetrail",
    ci = { mirror = true },

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"tools", "codeviewer"},
    keywords = {"explorer", "cross-platform"},

    xpm = {
        windows = {
            ["latest"] = { ref = "2021.4.19" },
            ["2021.4.19"] = {
                url = "https://github.com/CoatiSoftware/Sourcetrail/releases/download/2021.4.19/Sourcetrail_2021_4_19_Windows_64bit_Portable.zip",
                sha256 = nil,
            },
        },
        linux = {
            ["latest"] = { ref = "2021.4.19" },
            ["2021.4.19"] = {
                url = "https://github.com/CoatiSoftware/Sourcetrail/releases/download/2021.4.19/Sourcetrail_2021_4_19_Linux_64bit.tar.gz",
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.xvm")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")

function install()
    os.tryrm(pkginfo.install_dir())
    local appdir = nil
    if os.host() == "windows" then
        appdir = "Sourcetrail_2021_4_19_64bit_Portable"
    else
        appdir = "Sourcetrail"
    end
    if not os.isdir(appdir) then
        log.error("Cannot find extracted Sourcetrail directory: " .. appdir)
        return false
    end
    os.trymv(appdir, pkginfo.install_dir())
    return true
end

function config()

    if os.host() == "windows" then
        app_bindir = path.join(pkginfo.install_dir(), "Sourcetrail_2021_4_19_64bit")
        xvm.add("sourcetrail", {bindir = app_bindir})
    else
        xvm.add("sourcetrail", {
            alias = "Sourcetrail.sh",
        })
    end

    return true
end

function uninstall()
    xvm.remove("sourcetrail")
    return true
end