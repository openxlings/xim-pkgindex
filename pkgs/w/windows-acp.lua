package = {
    spec = "1",
    -- base info
    name = "windows-acp",
    description = "ACP: Beta: Use Unicode UTF-8 for worldwide language support",

    maintainers = {"d2learn"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "dev", -- dev, stable, deprecated
    categories = {"encode", "lang", "windows" },
    keywords = {"encode", "lang"},

    xpm = {
        windows = { ["latest"] = { } },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

function install()
    return true
end

function config()
    local cmd_alias = [[powershell -NoProfile -Command (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage).ACP]]

    log.info("add to xvm ...")
    xvm.add("windows-acp", {
        alias = cmd_alias,
    })

    log.info([[run 'windows-acp' to show current status ...]])
    os.exec("windows-acp")

    return true
end

function uninstall()
    log.info("remove from xvm ...")
    xvm.remove("windows-acp")
    return true
end