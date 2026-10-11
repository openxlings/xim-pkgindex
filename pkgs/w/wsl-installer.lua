package = {
    spec = "1",

    name = "wsl-installer",
    description = "Windows Subsystem for Linux: Microsoft's WSL installer (MSI), for xlings' Linux SubOS on Windows",

    homepage = "https://learn.microsoft.com/windows/wsl/",
    repo = "https://github.com/microsoft/WSL",
    licenses = {"MIT"},

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"windows", "subsystem", "virtualization"},
    keywords = {"wsl", "wsl2", "msi", "linux", "subsystem", "subos", "luban"},

    -- Not `wsl`: that name is the winget wrapper's (pmwrapper.lua, Microsoft.WSL).
    -- What a Windows machine's first Linux SubOS needs (the wsl2 carrier):
    -- `xlings self doctor --isolation --fix` -- or `subos new`, where it is
    -- asked -- installs this package and runs its MSI, and turns on the
    -- Virtual Machine Platform, through xlings' one door for administrator
    -- rights. Nothing here runs at install: the payload is the MSI, kept as
    -- wsl.msi, pinned by Microsoft's published digest.
    xpm = {
        windows = {
            ["latest"] = { ref = "3.0.1" },
            ["3.0.1"] = {
                url = {
                    GLOBAL = "https://github.com/microsoft/WSL/releases/download/3.0.1/wsl.3.0.1.0.x64.msi",
                    CN     = "https://gitcode.com/xlings-res/wsl/releases/download/3.0.1/wsl.3.0.1.0.x64.msi",
                },
                sha256 = "28b1a0d013640a2ac95898ea705fa186e5b4ff767a1c1b49257161bc106599c6",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(dir)
    os.mv(pkginfo.install_file(), path.join(dir, "wsl.msi"))
    return os.isfile(path.join(dir, "wsl.msi"))
end

-- An installer, not a program: the package name is registered (xvm.add) so a
-- home knows it has it; xlings runs wsl.msi through its elevation door.
function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
