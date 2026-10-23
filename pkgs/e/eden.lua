local base = "https://stable.eden-emu.dev/v0.2.1/"

local function asset(name, sha256)
    return { url = base .. name, sha256 = sha256 }
end

package = {
    spec = "2",
    name = "eden",
    description = "Eden Nintendo Switch emulator (desktop GUI and command-line frontend)",
    homepage = "https://eden-emu.dev/",
    repo = "https://git.eden-emu.dev/eden-emu/eden",
    docs = "https://git.eden-emu.dev/eden-emu/eden/src/branch/master/docs/user/README.md",
    licenses = {"GPL-3.0-or-later"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"app", "game", "emulator"},
    keywords = {"eden", "switch", "emulator", "yuzu"},
    programs = {"eden"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "0.2.1" },
            ["0.2.1"] = {
                x86_64 = asset("Eden-Linux-v0.2.1-amd64-gcc-standard.AppImage",
                    "2fae658397daf13c118082a3eb65d61a6519967b5e22e6667756baecf6000c5a"),
                aarch64 = asset("Eden-Linux-v0.2.1-aarch64-gcc-standard.AppImage",
                    "494014f67401bbbe7d48da7128d769734cf97863bfb2349d48cd2a118173e769"),
            },
        },
        windows = {
            ["latest"] = { ref = "0.2.1" },
            ["0.2.1"] = {
                x86_64 = asset("Eden-Windows-v0.2.1-amd64-msvc-standard.zip",
                    "ff498e5da9630216926ac3cbe9fb493b14930665c728a40a8f5b59507fdd7ebf"),
                aarch64 = asset("Eden-Windows-v0.2.1-arm64-clang-standard.zip",
                    "7df16b64bb0a0225acddcb498e524aa7854c24708022ecbea599cc1aebf010dc"),
            },
        },
        macosx = {
            ["latest"] = { ref = "0.2.1" },
            -- This release's experimental macOS bundle contains arm64 only.
            ["0.2.1"] = {
                aarch64 = asset("Eden-macOS-v0.2.1.dmg",
                    "40575fc79a61550fbb9e332cbae94ccd20f5de20ff61b4b60fe1d42f2525c0b5"),
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

function installed()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/eden.AppImage") then
        return os.isfile(dir .. "/bin/eden") and os.isfile(dir .. "/bin/eden-cli")
    elseif os.isfile(dir .. "/eden.exe") then
        return os.isfile(dir .. "/eden-cli.exe") and os.isfile(dir .. "/LICENSE.txt")
            and os.isfile(dir .. "/eden.cmd")
    end
    return os.isfile(dir .. "/eden.app/Contents/MacOS/eden")
        and os.isfile(dir .. "/eden.app/Contents/Frameworks/libMoltenVK.dylib")
end

function install()
    local archive, dir = pkginfo.install_file(), pkginfo.install_dir()
    local parent = archive:gsub("\\", "/"):match("^(.*)/[^/]+$")
    os.mkdir(dir)
    if archive:match("%.AppImage$") then
        -- Keep the upstream runtime and its bundled libraries intact. Its
        -- extract-and-run mode also works on machines without FUSE.
        os.cp(archive, dir .. "/eden.AppImage")
        os.mkdir(dir .. "/bin")
        for _, name in ipairs({"eden", "eden-cli"}) do
            local f = assert(io.open(dir .. "/bin/" .. name, "w"))
            f:write("#!/bin/sh\nexec ", quote(dir .. "/eden.AppImage"),
                " --appimage-extract-and-run ", name, " \"$@\"\n")
            f:close()
            system.exec("chmod 0755 " .. quote(dir .. "/bin/" .. name))
        end
        system.exec("chmod 0755 " .. quote(dir .. "/eden.AppImage"))
    elseif archive:match("%.zip$") then
        for _, name in ipairs({"eden.exe", "eden-cli.exe", "LICENSE.txt", "LICENSES", "README.md"}) do
            os.cp(parent .. "/" .. name, dir .. "/" .. name)
        end
        -- The GUI does not implement version/help switches. Keep those
        -- useful for terminals and CI by forwarding them to its CLI frontend.
        local f = assert(io.open(dir .. "/eden.cmd", "wb"))
        f:write('@echo off\r\n',
            'if "%~1"=="--version" goto version\r\n',
            'if "%~1"=="/?" goto help\r\n',
            'if "%~1"=="--help" goto help\r\n',
            '"%~dp0eden.exe" %*\r\nexit /b %errorlevel%\r\n',
            ':version\r\n"%~dp0eden-cli.exe" --version\r\nexit /b %errorlevel%\r\n',
            ':help\r\n"%~dp0eden-cli.exe" --help\r\nexit /b %errorlevel%\r\n')
        f:close()
    elseif archive:match("%.dmg$") then
        local mount = dir .. "/.mount"
        os.mkdir(mount)
        system.exec("/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint " ..
            quote(mount) .. " " .. quote(archive))
        local ok, err = pcall(function()
            system.exec("/usr/bin/ditto " .. quote(mount .. "/eden.app") .. " " .. quote(dir .. "/eden.app"))
        end)
        system.exec("/usr/bin/hdiutil detach " .. quote(mount))
        os.tryrm(mount)
        if not ok then error(err) end
    else
        error("Unsupported Eden archive: " .. archive)
    end
    assert(installed(), "Eden payload is incomplete")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/eden.exe") then
        xvm.add("eden", { bindir = dir, alias = "eden.cmd" })
        xvm.add("eden-cli", { bindir = dir })
    elseif os.isfile(dir .. "/eden.AppImage") then
        xvm.add("eden", { bindir = dir .. "/bin" })
        xvm.add("eden-cli", { bindir = dir .. "/bin" })
    else
        xvm.add("eden", { bindir = dir .. "/eden.app/Contents/MacOS" })
    end
    return true
end

function uninstall()
    xvm.remove("eden-cli")
    xvm.remove("eden")
    return true
end
