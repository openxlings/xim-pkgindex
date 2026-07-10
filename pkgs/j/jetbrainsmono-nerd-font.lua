package = {
    spec = "1",

    name = "jetbrainsmono-nerd-font",
    description = "JetBrainsMono Nerd Font patched with terminal icons and glyphs",
    homepage = "https://www.nerdfonts.com/font-downloads",
    maintainers = {"ryanoasis"},
    licenses = {"OFL-1.1", "MIT"},
    repo = "https://github.com/ryanoasis/nerd-fonts",
    docs = "https://github.com/ryanoasis/nerd-fonts#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"font", "terminal"},
    keywords = {"nerd-fonts", "jetbrainsmono", "font", "terminal", "icons"},
    xvm_enable = true,

    -- Data-only font package: only a package-name xvm entry is
    -- registered for lifecycle tracking. No executable program is exposed.
    -- The xlings-res asset is the arch-independent upstream font zip reused
    -- under every supported OS/arch entry.
    xpm = {
        linux = {
            ["latest"] = { ref = "3.4.0" },
            ["3.4.0"] = {
                url = {
                    GLOBAL = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip",
                    CN = "https://gitcode.com/xlings-res/jetbrainsmono-nerd-font/releases/download/3.4.0/JetBrainsMono.zip",
                },
                sha256 = "76f05ff3ace48a464a6ca57977998784ff7bdbb65a6d915d7e401cd3927c493c",
            },
        },
        macosx = {
            ["latest"] = { ref = "3.4.0" },
            ["3.4.0"] = {
                url = {
                    GLOBAL = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip",
                    CN = "https://gitcode.com/xlings-res/jetbrainsmono-nerd-font/releases/download/3.4.0/JetBrainsMono.zip",
                },
                sha256 = "76f05ff3ace48a464a6ca57977998784ff7bdbb65a6d915d7e401cd3927c493c",
            },
        },
        windows = {
            ["latest"] = { ref = "3.4.0" },
            ["3.4.0"] = {
                url = {
                    GLOBAL = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip",
                    CN = "https://gitcode.com/xlings-res/jetbrainsmono-nerd-font/releases/download/3.4.0/JetBrainsMono.zip",
                },
                sha256 = "76f05ff3ace48a464a6ca57977998784ff7bdbb65a6d915d7e401cd3927c493c",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

local function _sh(value)
    return "'" .. tostring(value):gsub("'", [['"'"']]) .. "'"
end

local function _ps(value)
    return "'" .. tostring(value):gsub("'", "''") .. "'"
end

local function _run_sh(script)
    system.exec("sh -c " .. _sh(script))
end

local function _run_powershell(script)
    system.exec('powershell -NoProfile -ExecutionPolicy Bypass -Command "' .. script .. '"')
end

local function _home_dir()
    return os.getenv("HOME") or os.getenv("USERPROFILE")
end

local function _font_dir()
    if is_host("windows") then
        local base = os.getenv("LOCALAPPDATA")
        if not base then
            local home = _home_dir()
            if not home then error("LOCALAPPDATA or USERPROFILE is required") end
            base = path.join(home, "AppData", "Local")
        end
        -- Windows user font directory: Microsoft\Windows\Fonts
        return path.join(base, "Microsoft", "Windows", "Fonts")
    end

    local home = _home_dir()
    if not home then error("HOME is required") end

    if is_host("macosx") then
        return path.join(home, "Library", "Fonts")
    end

    local data_home = os.getenv("XDG_DATA_HOME") or path.join(home, ".local", "share")
    return path.join(data_home, "fonts")
end

local function _refresh_linux_font_cache(font_dir)
    if is_host("linux") then
        _run_sh("command -v fc-cache >/dev/null 2>&1 && fc-cache -f " .. _sh(font_dir) .. " || true")
    end
end

local function _copy_fonts_to(font_dir)
    if is_host("windows") then
        local script = table.concat({
            "$src = " .. _ps(pkginfo.install_dir()),
            "$dst = " .. _ps(font_dir),
            "New-Item -ItemType Directory -Force -Path $dst | Out-Null",
            "$reg = 'HKCU:\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts'",
            "Get-ChildItem -Path $src -Filter '*.ttf' | ForEach-Object { $target = Join-Path $dst $_.Name; Copy-Item -Path $_.FullName -Destination $target -Force; New-ItemProperty -Path $reg -Name ($_.Name + ' (TrueType)') -Value $target -PropertyType String -Force | Out-Null }",
        }, "; ")
        _run_powershell(script)
    else
        _run_sh("cp -f " .. _sh(pkginfo.install_dir()) .. "/*.ttf " .. _sh(font_dir) .. "/")
    end
end

local function _remove_fonts_from(font_dir)
    if is_host("windows") then
        local script = table.concat({
            "$dst = " .. _ps(font_dir),
            "$reg = 'HKCU:\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts'",
            "Get-ChildItem -Path $dst -Filter 'JetBrainsMono*NerdFont*.ttf' -ErrorAction SilentlyContinue | ForEach-Object { Remove-ItemProperty -Path $reg -Name ($_.Name + ' (TrueType)') -ErrorAction SilentlyContinue; Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }",
        }, "; ")
        _run_powershell(script)
    else
        _run_sh("rm -f " .. _sh(font_dir) .. "/JetBrainsMono*NerdFont*.ttf")
    end
end

function installed()
    return xvm.has(package.name)
       and os.isfile(path.join(_font_dir(), "JetBrainsMonoNerdFont-Regular.ttf"))
       and os.isfile(path.join(pkginfo.install_dir(), "JetBrainsMonoNerdFont-Regular.ttf"))
end

function install()
    -- Keep the original extracted payload in pkginfo.install_dir().
    -- The upstream zip is flat, and xlings stages its files into that
    -- local xpkg install directory after this hook returns.
    return true
end

function config()
    local font_dir = _font_dir()
    os.mkdir(font_dir)
    _copy_fonts_to(font_dir)
    _refresh_linux_font_cache(font_dir)
    xvm.add(package.name)
    log.info("JetBrainsMono Nerd Font installed to %s", font_dir)
    return true
end

function uninstall()
    local font_dir = _font_dir()
    _remove_fonts_from(font_dir)
    _refresh_linux_font_cache(font_dir)
    xvm.remove(package.name)
    return true
end
