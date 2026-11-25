-- Everything - instant file & folder name search utility for Windows by voidtools.
--
-- Platform and architecture:
--   windows  x86_64   Everything-1.4.1.1032.x64.zip   (everything.exe + Everything.lng)
--   windows  aarch64  Everything-1.4.1.1032.ARM64.zip (EverythingARM64.exe normalized to everything.exe + Everything.lng)
--
-- Checksums verified against https://www.voidtools.com/Everything-1.4.1.1032.sha256
-- and by downloading the ARM64 zip directly from voidtools.com.
--
-- `programs` is omitted deliberately: everything.exe is a Windows GUI application
-- whose `-?` / `/?` dialog opens a modal MessageBox waiting for OK click rather than
-- exiting immediately to stdout in headless CI. `config()` still registers
-- `everything` via xvm and creates a Start Menu shortcut (no Desktop icon).
package = {
    spec = "2",

    name = "everything",
    description = "Everything - fast desktop search utility that locates files and folders by name instantly on Windows",
    homepage = "https://www.voidtools.com",
    authors = {"David Carpenter (voidtools)"},
    maintainers = {"voidtools"},
    licenses = {"MIT"},
    docs = "https://www.voidtools.com/support/everything/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "search", "filesystem", "windows"},
    keywords = {"everything", "voidtools", "search", "files", "ntfs", "windows"},

    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "1.4.1.1032" },
            ["1.4.1.1032"] = {
                x86_64 = {
                    url = "https://www.voidtools.com/Everything-1.4.1.1032.x64.zip",
                    sha256 = "698df475ec44e638f66f1b6a32d28fea613cec78d3b6310e6abe53431eeb940c",
                },
                aarch64 = {
                    url = "https://www.voidtools.com/Everything-1.4.1.1032.ARM64.zip",
                    sha256 = "23dca1a64574bf30c9988bbaf5f1d201a0ec7ee9a15e12270ae92a52183cccc8",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.shortcut")
import("xim.pkgindex.winpath")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/everything.exe") and os.isfile(dir .. "/Everything.lng")
end

function install()
    local dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()
    local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
    local systar = sysroot .. "\\System32\\tar.exe"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
    system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))

    if os.isfile(dir .. "/EverythingARM64.exe") and not os.isfile(dir .. "/everything.exe") then
        os.mv(dir .. "/EverythingARM64.exe", dir .. "/everything.exe")
    end

    if not installed() then
        error("everything executable is missing after install in " .. dir)
    end
    return true
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("everything", { bindir = dir, alias = "everything.exe" })
    shortcut.create{
        name = "Everything",
        target = dir .. "/everything.exe",
        description = "Everything file search utility",
    }
    return true
end

function uninstall()
    shortcut.remove{ name = "Everything" }
    xvm.remove("everything")
    return true
end
