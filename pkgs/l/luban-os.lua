package = {
    spec = "1",

    name = "luban-os",
    description = "Luban OS: the systems of this home in a window -- a list, then a system's console or desktop, and a management panel",

    homepage = "https://github.com/openxlings/xlings",
    repo = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"desktop", "luban", "gui"},
    keywords = {"luban", "luban-os", "desktop", "window", "machine", "subos"},

    -- The Luban OS window (xlings: Luban OS architecture design §14), released
    -- with xlings at the same date version (openxlings/xlings,
    -- tools/luban_os_release.sh; mirrored to xlings-res/luban-os). It opens a
    -- window, so unlike xlings and luban it is not static: it links glibc and
    -- X11 (through SDL), which these dependencies are, and an install patches
    -- it onto them. It drives the xlings and luban of the home it is installed
    -- in. config() adds its desktop entry (~/.local/share/applications).
    programs = {"luban-os"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xim:glibc@>=2.44",
                "xim:gcc-runtime",
                "xim:libX11@>=1.8",
                "xim:libxcb@>=1.17",
                "xim:libXcursor",
                "xim:libXext@>=1.3",
                "xim:libXfixes",
                "xim:libXi",
                "xim:libXrandr",
            },
            ["latest"] = { ref = "2026.10.13.2" },
            ["2026.10.13.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "009fc85fcdf352692fa5eccbb4c8c514f52caf439622d5ee1cb41a7672da2aa2",
                },
            },
            ["2026.10.13.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1d493a67f52c09fb14eca43b37185b10a89e9f1ed0acd8ad7ef9224a88e07d2a",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "bin", "luban-os"))
end

local function entry_file()
    return path.join(os.getenv("HOME") or "", ".local/share/applications", "luban-os.xvm.desktop")
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("luban-os", { bindir = path.join(dir, "bin") })
    -- The host's application menu: the window of this home.
    if os.getenv("HOME") then
        local home = os.getenv("XLINGS_HOME") or path.join(os.getenv("HOME"), ".xlings")
        local entry = string.format([[
[Desktop Entry]
Type=Application
Name=Luban OS
Comment=Your Luban OS systems: start one, or manage them
Exec=env XLINGS_HOME=%s %s
Icon=%s
Terminal=false
Categories=System;Emulator;
StartupWMClass=luban-os
]], home, path.join(dir, "bin", "luban-os"), path.join(dir, "share/icons/hicolor/scalable/apps/luban-os.svg"))
        os.mkdir(path.join(os.getenv("HOME"), ".local/share/applications"))
        io.writefile(entry_file(), entry)
        log.debug("desktop entry %s", entry_file())
    end
    return true
end

function uninstall()
    os.tryrm(entry_file())
    xvm.remove("luban-os")
    return true
end
