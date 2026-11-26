-- starship - the minimal, blazing-fast, and infinitely customizable prompt for any shell.
--
-- Platform and architecture coverage (verified against starship/starship v1.27.0):
--   linux    x86_64, aarch64   static musl ELF binary (`starship` at archive root,
--                              no dynamic library dependencies)
--   macosx   x86_64, aarch64   official Mach-O binary (`starship` at archive root)
--   windows  x86_64, aarch64   official PE binary (`starship.exe` at archive root,
--                              imports Windows system DLLs only; static CRT)
--
-- All archives are flat (a single `starship` or `starship.exe` executable at
-- the archive root with no enclosing directory).

package = {
    spec = "2",

    name = "starship",
    description = "The minimal, blazing-fast, and infinitely customizable prompt for any shell",
    homepage = "https://starship.rs",
    authors = {"Starship Contributors"},
    maintainers = {"Starship Contributors"},
    licenses = {"ISC"},
    repo = "https://github.com/starship/starship",
    docs = "https://starship.rs/guide/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "shell", "prompt", "tools"},
    keywords = {"starship", "prompt", "shell", "rust", "bash", "zsh", "fish"},

    programs = {"starship"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/starship/starship/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/starship/starship/releases/download/v${version}/starship-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/starship/starship/releases/download/v${version}/starship-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/starship/starship/releases/download/v${version}/starship-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/starship/starship/releases/download/v${version}/starship-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/starship/starship/releases/download/v${version}/starship-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/starship/starship/releases/download/v${version}/starship-aarch64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "1.27.0" },
            ["1.27.0"] = {
                x86_64 = {
                    url = "https://github.com/starship/starship/releases/download/v1.27.0/starship-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "10c8eb4cb3b761d9bf59ea828444c2dab36c900b7d69a69e08814b286969df89",
                },
                aarch64 = {
                    url = "https://github.com/starship/starship/releases/download/v1.27.0/starship-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "341f5cbf24699fa0b27ec88965ad25f862ea09e15d35a543fd6ffdff1d2aa00d",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.27.0" },
            ["1.27.0"] = {
                x86_64 = {
                    url = "https://github.com/starship/starship/releases/download/v1.27.0/starship-x86_64-apple-darwin.tar.gz",
                    sha256 = "344e4d38787e0aa86dd522ae5462e6fb6da1227691f81a79ffed480a4563ccb3",
                },
                aarch64 = {
                    url = "https://github.com/starship/starship/releases/download/v1.27.0/starship-aarch64-apple-darwin.tar.gz",
                    sha256 = "5362da8cb2928f98f3ce0ffda697cf0f8de70081db000dae316d6d3a404f6cf0",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "1.27.0" },
            ["1.27.0"] = {
                x86_64 = {
                    url = "https://github.com/starship/starship/releases/download/v1.27.0/starship-x86_64-pc-windows-msvc.zip",
                    sha256 = "7764f861805376af2812dd78c84fadc16b714cf3f346baed9b597bfda8484403",
                },
                aarch64 = {
                    url = "https://github.com/starship/starship/releases/download/v1.27.0/starship-aarch64-pc-windows-msvc.zip",
                    sha256 = "1822b6cf1af28071b056976d3f445359d61df324918ffe76c6d0f851eef9366f",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.winpath")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/starship.exe") or os.isfile(dir .. "/starship")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("starship: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local download_dir = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "starship.exe" or "starship"
    local pre_extracted = download_dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(pre_extracted) then
        os.mv(pre_extracted, dir .. "/" .. exe)
    elseif os.isfile(archive) then
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        end
    else
        error("starship: neither extracted binary (" .. pre_extracted .. ") nor archive (" .. archive .. ") exists")
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
    end

    if not installed() then
        error("starship: " .. exe .. " is missing after install in " .. dir)
    end
    return true
end

function config()
    xvm.add("starship", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("starship")
    return true
end
