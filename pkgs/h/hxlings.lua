-- Hxlings - Desktop GUI manager for xlings built with mcpp and HuxerUI.
--
-- Platform and architecture coverage (upstream v0.1.5 release):
--   linux    x86_64   self-contained mcpp bundle (`hxlings` wrapper + `bin/` + `lib/`)
--   macosx   aarch64  self-contained mcpp bundle (`hxlings` wrapper + `bin/`)
--   windows  x86_64   self-contained mcpp bundle (`hxlings.exe` + `hxlings.resources/`)
--
-- Upstream currently publishes linux/x86_64, macos/arm64, and windows/x86_64 only
-- (no linux/aarch64, macos/x86_64, or windows/aarch64 assets).
--
-- `programs` is omitted deliberately: `hxlings` launches `huxerui::RunApplication()`
-- directly and does not implement CLI `--version` / `--help` flags, so invoking
-- it on headless CI blocks instead of exiting. `config()` still registers
-- `hxlings` via `xvm.add` (and creates a Windows Start Menu shortcut without
-- touching the Desktop).

package = {
    spec = "2",

    name = "hxlings",
    description = "Desktop GUI manager for xlings built with mcpp and HuxerUI",
    homepage = "https://github.com/FarnaHerry/Hxlings",
    authors = {"FarnaHerry"},
    maintainers = {"FarnaHerry"},
    licenses = {"MIT"},
    repo = "https://github.com/FarnaHerry/Hxlings",
    docs = "https://github.com/FarnaHerry/Hxlings#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "gui", "desktop", "package-manager"},
    keywords = {"hxlings", "xlings", "mcpp", "huxerui", "gui", "package-manager"},

    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/FarnaHerry/Hxlings/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/FarnaHerry/Hxlings/releases/download/v${version}/hxlings-${version}-linux-x86_64.tar.gz",
                        },
                        macosx = {
                            aarch64 = "https://github.com/FarnaHerry/Hxlings/releases/download/v${version}/hxlings-${version}-macos-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/FarnaHerry/Hxlings/releases/download/v${version}/hxlings-${version}-windows-x86_64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "0.1.7" },
            ["0.1.5"] = {
                revision = 1,
                x86_64 = {
                    url = "https://github.com/FarnaHerry/Hxlings/releases/download/v0.1.5/hxlings-0.1.5-linux-x86_64.tar.gz",
                    sha256 = "2dca576961521b5b185610b3cb06b924f7d8b27192efd1ea14c718b96ade30f4",
                },
            },
            ["0.1.7"] = {
                x86_64 = {
                    url = "https://github.com/FarnaHerry/Hxlings/releases/download/v0.1.7/hxlings-0.1.7-linux-x86_64.tar.gz",
                    sha256 = "6bd72c76c2456325f683cca6c6c5ca26ccc71944b2e5e797743b8020e8677a57",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.1.7" },
            ["0.1.5"] = {
                revision = 1,
                aarch64 = {
                    url = "https://github.com/FarnaHerry/Hxlings/releases/download/v0.1.5/hxlings-0.1.5-macos-arm64.tar.gz",
                    sha256 = "f3a1febfc49b20e769613efbb92dd38a40a894f10ea238ccdf4d2bc31536c701",
                },
            },
            ["0.1.7"] = {
                aarch64 = {
                    url = "https://github.com/FarnaHerry/Hxlings/releases/download/v0.1.7/hxlings-0.1.7-macos-arm64.tar.gz",
                    sha256 = "808e17baf1a1ccd181f8f2309eb36a2950fe2e277ebf57274905a08ff8143145",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.1.7" },
            ["0.1.5"] = {
                revision = 1,
                x86_64 = {
                    url = "https://github.com/FarnaHerry/Hxlings/releases/download/v0.1.5/hxlings-0.1.5-windows-x86_64.zip",
                    sha256 = "9613fc498389a0d392c05f3c7ff9719feaec72291069554851b2ee484159e52a",
                },
            },
            ["0.1.7"] = {
                x86_64 = {
                    url = "https://github.com/FarnaHerry/Hxlings/releases/download/v0.1.7/hxlings-0.1.7-windows-x86_64.zip",
                    sha256 = "4c8cb80613f77ecd80fb33e2dce7733b09479366dc197b6e63e088a63b7288fc",
                },
            },
        },
    },
}

import("xim.libxpkg.elfpatch")
import("xim.libxpkg.fs")
import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function winpath(p)
    return (p:gsub("/", "\\"))
end

local function ps_quote(s)
    return (s:gsub("'", "''"))
end

local function start_menu_lnk(name)
    local appdata = os.getenv("APPDATA")
    if not appdata or appdata == "" then return nil end
    return winpath(appdata) .. "\\Microsoft\\Windows\\Start Menu\\Programs\\" .. name .. ".lnk"
end

local function create_start_menu_shortcut(name, target, workdir, description)
    local lnk = start_menu_lnk(name)
    if not lnk then return end
    local programs_dir = lnk:match("^(.*)\\[^\\]+$")
    if programs_dir then fs.mkdir_p(programs_dir) end
    -- exec-quoting-ok: every interpolated value is enclosed in PowerShell single quotes.
    system.exec(string.format(
        [[powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('%s'); $s.TargetPath = '%s'; $s.IconLocation = '%s,0'; $s.WorkingDirectory = '%s'; $s.Description = '%s'; $s.Save()"]],
        ps_quote(lnk),
        ps_quote(winpath(target)),
        ps_quote(winpath(target)),
        ps_quote(winpath(workdir)),
        ps_quote(description)
    ))
end

function installed()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/hxlings.exe") then
        return true
    end
    return os.isfile(dir .. "/hxlings") and os.isfile(dir .. "/bin/hxlings")
end

function install()
    local archive = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.tgz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local extracted = parent .. "/" .. stem

    fs.mkdir_p(dir)
    os.tryrm(dir)

    if os.isdir(extracted) then
        os.mv(extracted, dir)
    else
        local staging = dir .. ".staging"
        os.tryrm(staging)
        fs.mkdir_p(staging)
        local ok, err = pcall(function()
            if is_win then
                local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("/", "\\"):gsub("\\+$", "")
                local systar = sysroot .. "\\System32\\tar.exe"
                -- exec-quoting-ok: the first token is Windows' built-in tar.exe, which cmd.exe requires unquoted
                system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath(archive), winpath(staging)))
            else
                system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, staging))
            end
            local payload = staging .. "/" .. stem
            if os.isdir(payload) then
                os.mv(payload, dir)
            elseif os.isfile(staging .. "/hxlings.exe") or os.isfile(staging .. "/hxlings") then
                os.mv(staging, dir)
            else
                error("hxlings payload directory not found in " .. staging)
            end
        end)
        os.tryrm(staging)
        if not ok then error(err) end
    end

    if not is_win then
        for _, rel in ipairs({ "/hxlings", "/bin/hxlings", "/run.sh" }) do
            local target = dir .. rel
            if os.isfile(target) then
                system.exec(string.format([[chmod +x "%s"]], target))
            end
        end
        -- Align PT_INTERP of self-contained Linux ELFs with the bundled loader
        -- so xlings' post-install verifier sees loader and libc in the same payload.
        local loader = dir .. "/lib/ld-linux-x86-64.so.2"
        if os.isfile(loader) and elfpatch and type(elfpatch.set_interpreter) == "function" then
            for _, rel in ipairs({ "/bin/hxlings", "/lib/libc.so.6" }) do
                local elf = dir .. rel
                if os.isfile(elf) then
                    elfpatch.set_interpreter(elf, loader)
                end
            end
        end
    end

    if not installed() then
        error("hxlings executable is missing after install in " .. dir)
    end
    return true
end

function config()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/hxlings.exe") then
        xvm.add("hxlings", { bindir = dir, alias = "hxlings.exe" })
        local ok, err = pcall(
            create_start_menu_shortcut,
            "Hxlings",
            dir .. "/hxlings.exe",
            dir,
            "Desktop GUI manager for xlings"
        )
        if not ok then
            log.warn("hxlings: failed to create Start Menu shortcut: " .. tostring(err))
        end
    else
        xvm.add("hxlings", { bindir = dir })
    end
    return true
end

function uninstall()
    local lnk = start_menu_lnk("Hxlings")
    if lnk then os.tryrm(lnk) end
    xvm.remove("hxlings")
    return true
end
