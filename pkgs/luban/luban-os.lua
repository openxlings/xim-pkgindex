package = {
    -- Platform version sets differ ON PURPOSE: macOS and Windows builds of the
    -- window start at 2026.10.15.1; Linux carries the releases before it.
    platform_versions_diverge = true,
    spec = "1",

    name = "luban-os",
    description = "Luban OS: the systems of this home in a window -- a list, then a system's console or desktop, and a management panel",

    homepage = "https://github.com/openxlings/xlings",
    repo = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "luban", "gui"},
    keywords = {"luban", "luban-os", "desktop", "window", "machine", "subos"},

    -- The Luban OS window (xlings: Luban OS architecture design §14), released
    -- with xlings at the same date version (openxlings/xlings,
    -- tools/luban_os_release.sh; mirrored to xlings-res/luban-os). It opens a
    -- window, so unlike xlings and luban it is not static: it links glibc and
    -- X11 (through SDL), which these dependencies are, and an install patches
    -- it onto them. It drives the xlings and luban of the home it is installed
    -- in. config() adds its desktop entry (~/.local/share/applications). Its
    -- fonts are luban-fonts' (share/fonts/luban), on every system.
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
                "xim:luban-fonts",
            },
            ["latest"] = { ref = "2026.10.16.2" },
            ["2026.10.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "b8226b4686683fa308bbdf1f5f2b92fe5dc0e66c7424626c60a3489e3a3712fb",
                },
            },
            ["2026.10.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4e40066176c879c8db819d6014918e18073612f56b4b8f603db190c15ec76ec2",
                },
            },
            ["2026.10.15.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "440f04b0d0fec2e3ccdd5ecd570b1e6a2acd7c123584c64ca998f06389260206",
                },
            },
            ["2026.10.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "0736faecbab6f0629ac506478c88039bea2df1654876d139e311149e835dce60",
                },
            },
            ["2026.10.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fb4aacac1c1bcdab2ed35cfa299fd162e2b58178e355660f4a5658f7564e2712",
                },
            },
            ["2026.10.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "67040e3a2d0b8417c17856d682b55448319a7cec4f91df34f6eb0153980ff761",
                },
            },
            ["2026.10.13.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3894e9abf4893256b2ec69485d46f46333a199ab9ced3dc1245dbaa8a0ea0148",
                },
            },
            ["2026.10.13.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fd3b3c5e562ab65dd53b963b22c1e71d85d037adecb7edeed528e5c9b3594f2e",
                },
            },
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
        macosx = {
            deps = { "xim:luban-fonts" },
            ["latest"] = { ref = "2026.10.16.2" },
            ["2026.10.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "99582cada89d6cf9c3f67821ace299e4147ab6bec82719b2d1b531d4ed496cbf",
                },
            },
            ["2026.10.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "05aeab5f02b2c91783cd2dc065245b81d7039266d0d3f90db0eb87414e42a4ec",
                },
            },
            ["2026.10.15.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "151a31993f6b65a63deb10665c4a4559ea386bbf74c203085d8064d05586aa01",
                },
            },
            ["2026.10.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "02bcc5f9beab53abeecdaf8fed47c5c4176b924d248182628c700d7478f68801",
                },
            },
            ["2026.10.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9be453ef4279f00b9799e329ed0376edb81788f13587da5c99997fd371a95a0a",
                },
            },
            ["2026.10.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "31dd65de8156e09eb1a388a99c9abc2d410b72c4c227f984bcd628ef487b8fad",
                },
            },
        },
        windows = {
            deps = { "xim:luban-fonts" },
            ["latest"] = { ref = "2026.10.16.2" },
            ["2026.10.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5356a037cd2c026f4a5d6f12c2570d40d04e4aa554183d44ab58feaccdb6dab7",
                },
            },
            ["2026.10.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bce9b7e10735e44270e39bc1792b51308f493f4714a7506dc9612099eca4fb47",
                },
            },
            ["2026.10.15.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "54a041d886db6b7ccd9dc4ad59af36262c18d296d525cbb856a26d40a1335247",
                },
            },
            ["2026.10.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "9c9165dd72aa7bf60f141423ca25c3a1d8762513d89dc3677ac8138643e56a27",
                },
            },
            ["2026.10.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "15011fa3b54f500dcc09ddd1ceccf1678b3f501c99fb378c0291b689d202e642",
                },
            },
            ["2026.10.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "7534dca161db18f4589998ac1f3ab57d87096feae177705c289d3955aa5aeee6",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- bin/luban-os (bin/luban-os.exe on Windows): the payload extracts into
-- luban-os-<version>-<os>-<arch>/, a .tar.gz on Linux and macOS, a .zip on Windows.
local function exe()
    return is_host("windows") and "luban-os.exe" or "luban-os"
end

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", ""):replace(".zip", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "bin", exe()))
end

local function entry_file()
    return path.join(os.getenv("HOME") or "", ".local/share/applications", "luban-os.xvm.desktop")
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("luban-os", { bindir = path.join(dir, "bin") })
    -- The host's application menu (a freedesktop one: Linux): the window of this home.
    if is_host("linux") and os.getenv("HOME") then
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
