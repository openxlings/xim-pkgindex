-- A package's launcher entry on Windows: a Start Menu or Desktop shortcut
-- (.lnk), and its removal. One implementation of what winscp, filezilla,
-- hxlings and everything each spelled themselves (byte-identical copies), of
-- what code.lua spells with its own .vbs template, and of what shortcut-tool
-- (a script package reached through a shim) spells a third way.
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.shortcut")
--
--     shortcut.create{ name = "WinSCP", target = dir .. "/WinSCP.exe",
--                      description = "WinSCP SFTP and FTP client" }  -- config()
--     shortcut.remove{ name = "WinSCP" }                             -- uninstall()
--
-- WHAT A RECIPE SAYS
--   name         the entry's display name (the .lnk's stem)          required
--   target       the program the entry starts; `/` is accepted        required
--   description  its tooltip                                          optional
--   arguments    the command line after the target                    optional
--   workdir      default: the target's directory                      optional
--   icon         default: the target                                  optional
--   location     "start-menu" (default) or "desktop"                  optional
--
-- The recipe does not say which host it is on (nothing happens elsewhere),
-- where the Start Menu is, how the shell is quoted, or what to print when the
-- entry could not be written. Each of those is answered here once.
--
-- BEST-EFFORT, AND HONEST ABOUT IT. A launcher entry is cosmetic: vc6, code,
-- winscp and filezilla all let a failed one pass rather than fail config()
-- before its xvm.add. So create() never raises. It answers true only when the
-- file is on disk afterwards -- a command that ran is not a shortcut -- and
-- log.warn is written here, with the package's name, so no recipe wraps the
-- call in pcall.
--
-- The quoting here is PowerShell's single-quote rule (a quote is doubled),
-- which is not `shell.quote`'s MSVCRT rule one door away: the values are
-- inside a PowerShell command line, not an argv.
--
-- A recipe registered under `local:` WITHOUT this index's libs/ (a bare
-- `xlings config --add-xpkg`) gets a permissive stub for this module and every
-- call is a truthy no-op: the install succeeds and no entry appears. CI's
-- install jobs copy libs/ beside the recipe (posix-test.sh, windows-test.ps1)
-- and do exercise this module; a developer's manual registration does not.

import("xim.libxpkg.fs")
import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.pkgindex.winpath")

local shortcut = {}

local FOLDERS = {
    ["start-menu"] = { env = "APPDATA", tail = "Microsoft\\Windows\\Start Menu\\Programs" },
    ["desktop"]    = { env = "USERPROFILE", tail = "Desktop" },
}

local function ps_quote(s) return (s:gsub("'", "''")) end

-- Where an entry named opt.name lives, or nil and the reason there is none.
-- create() and remove() both ask here, so the two cannot disagree.
function shortcut.path(opt)
    local folder = FOLDERS[opt.location or "start-menu"]
    if not folder then return nil, "unknown location: " .. tostring(opt.location) end
    if pkginfo.platform() ~= "windows" then return nil, "shortcuts exist on Windows only" end
    local root = os.getenv(folder.env)
    if not root or root == "" then return nil, folder.env .. " is not set" end
    return winpath.native(root) .. "\\" .. folder.tail .. "\\" .. opt.name .. ".lnk"
end

-- The one command that writes an entry. Every interpolated value is inside a
-- PowerShell single quote with its own quotes doubled.
local CREATE = [[powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('%s'); $s.TargetPath = '%s'; $s.IconLocation = '%s,0'; $s.WorkingDirectory = '%s'; $s.Description = '%s'; $s.Arguments = '%s'; $s.Save()"]]

function shortcut.create(opt)
    local lnk, why = shortcut.path(opt)
    if not lnk then
        if pkginfo.platform() == "windows" then
            log.warn("%s: no shortcut '%s': %s", pkginfo.name(), opt.name, why)
        end
        return false, why
    end
    local target = winpath.native(opt.target)
    local values = {
        ps_quote(lnk),
        ps_quote(target),
        ps_quote(winpath.native(opt.icon or opt.target)),
        ps_quote(winpath.native(opt.workdir or target:match("^(.*)\\[^\\]+$"))),
        ps_quote(opt.description or ""),
        ps_quote(opt.arguments or ""),
    }
    local dir = lnk:match("^(.*)\\[^\\]+$")
    if dir then fs.mkdir(dir) end
    -- exec-quoting-ok: every interpolated value goes through ps_quote (PowerShell single quotes).
    local ran, err = pcall(system.exec, string.format(CREATE, table.unpack(values)))
    if not ran then
        log.warn("%s: shortcut '%s' was not written: %s", pkginfo.name(), opt.name, tostring(err))
        return false, err
    end
    if not fs.is_file(lnk) then
        log.warn("%s: shortcut '%s' was not written at %s", pkginfo.name(), opt.name, lnk)
        return false, "not written: " .. lnk
    end
    return true, lnk
end

-- Removes the entry when it is there. Nothing to remove is not an error.
function shortcut.remove(opt)
    local lnk = shortcut.path(opt)
    if not lnk or not fs.is_file(lnk) then return false end
    fs.remove(lnk)
    return not fs.is_file(lnk)
end

return shortcut
