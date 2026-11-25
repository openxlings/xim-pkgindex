-- Exercise libs/shortcut.lua in a plain-Lua sandbox, the way libxpkg runs a
-- hook: import() is a no-op that leaves the module globals forged below, and
-- the host, the environment and `system.exec` are forged per case. Nothing
-- here touches a real Start Menu and no PowerShell runs: what is checked is
-- the command the module builds, the path it chooses, and what it answers.

local LIB = assert(os.getenv("SHORTCUT_LIB"), "SHORTCUT_LIB required")
local WINPATH = assert(os.getenv("WINPATH_LIB"), "WINPATH_LIB required")

local B, Q = string.char(92), string.char(39)      -- a backslash, a single quote

-- ── the sandbox ────────────────────────────────────────────────────────────
local HOST, ENV = "windows", {}
local FILES, MKDIRS, EXECS, WARNS = {}, {}, {}, {}
local MODE = "ok"            -- ok | noop | raise : what system.exec does

import = function() end     -- libxpkg's import() leaves these as globals
winpath = assert(loadfile(WINPATH))()   -- the real module, as the lib imports it
os.host = function() return HOST end
os.getenv = function(k) return ENV[k] end
os.isfile = function(p) return FILES[p] == true end
os.tryrm = function(p) FILES[p] = nil end
fs = { mkdir_p = function(p) MKDIRS[#MKDIRS + 1] = p end }
pkginfo = { name = function() return "winscp" end }
local function logger(level)
    return function(fmt, ...)
        local line = string.format(fmt, ...)
        if level == "warn" then WARNS[#WARNS + 1] = line end
        print("  [" .. level .. "] " .. line)
    end
end
log = { info = logger("info"), warn = logger("warn"), error = logger("error") }

-- The entry PowerShell would have written is the first single-quoted value.
system = { exec = function(cmd)
    EXECS[#EXECS + 1] = cmd
    if MODE == "raise" then error("powershell: command not found") end
    if MODE == "ok" then
        local _, b = cmd:find("CreateShortcut(", 1, true)
        local v = cmd:sub(b + 2)
        local e = v:find(Q .. ");", 1, true)
        FILES[(v:sub(1, e - 1)):gsub(Q .. Q, Q)] = true
    end
end }

local shortcut = assert(loadfile(LIB))()

-- ── the checks ─────────────────────────────────────────────────────────────
local n = 0
local function check(cond, msg)
    if not cond then error("FAIL: " .. msg, 2) end
    n = n + 1
end
local function has(hay, needle) return hay:find(needle, 1, true) ~= nil end
local function psq(s) return (s:gsub(Q, Q .. Q)) end   -- a value as PowerShell receives it

local USER = "C:" .. B .. "Users" .. B .. "O" .. Q .. "Neil"
local MENU_DIR = USER .. B .. "AppData" .. B .. "Roaming" .. B .. "Microsoft" .. B
                 .. "Windows" .. B .. "Start Menu" .. B .. "Programs"
local MENU = MENU_DIR .. B .. "WinSCP.lnk"
local TD = table.concat({ "C:", "xlings", "data", "xpkgs", "xim-x-winscp", "6.7.1" }, B)
local DIR = "C:/xlings/data/xpkgs/xim-x-winscp/6.7.1"

local function reset(host, env, mode)
    HOST = host or "windows"
    ENV = env or { APPDATA = USER .. B .. "AppData" .. B .. "Roaming", USERPROFILE = USER }
    MODE = mode or "ok"
    FILES, MKDIRS, EXECS, WARNS = {}, {}, {}, {}
end
local function entry()
    return shortcut.create({ name = "WinSCP", target = DIR .. "/WinSCP.exe",
                             description = "WinSCP client" })
end

-- 1. the entry a recipe asks for by default
reset()
local ok, where = entry()
check(ok == true and where == MENU, "create answers true and the entry's path")
check(#EXECS == 1, "one command")
check(has(EXECS[1], "CreateShortcut(" .. Q .. psq(MENU) .. Q .. ")"), "the command names the Start Menu entry")
check(has(EXECS[1], "$s.TargetPath = " .. Q .. TD .. B .. "WinSCP.exe" .. Q), "the target is in native form")
check(has(EXECS[1], "$s.WorkingDirectory = " .. Q .. TD .. Q), "workdir defaults to the target's directory")
check(has(EXECS[1], "$s.IconLocation = " .. Q .. TD .. B .. "WinSCP.exe,0" .. Q), "icon defaults to the target")
check(has(EXECS[1], "$s.Description = " .. Q .. "WinSCP client" .. Q), "the description is passed")
check(not has(EXECS[1], "Desktop"), "no Desktop entry is written")
check(MKDIRS[1] == MENU_DIR, "the Programs directory is made first")
check(#WARNS == 0, "nothing to warn about")

-- 2. an apostrophe in the home is doubled, not left to end the PowerShell string
check(has(EXECS[1], "O" .. Q .. Q .. "Neil") and not has(EXECS[1], "O" .. Q .. "Neil"),
      "a single quote in a path is doubled")

-- 3. config() runs again; the entry lands on the same file
reset()
entry()
local _, again = entry()
check(again == MENU, "idempotent: the same path on a second run")

-- 4. arguments and the Desktop are the recipe's to choose
reset()
shortcut.create({ name = "Git Bash", target = DIR .. "/git-bash.exe",
                  arguments = "--cd-to-home", location = "desktop" })
check(has(EXECS[1], "$s.Arguments = " .. Q .. "--cd-to-home" .. Q), "arguments are passed")
check(has(EXECS[1], B .. "Desktop" .. B .. "Git Bash.lnk"), "location = desktop")

-- 5. the command ran and wrote nothing: false, and a warning that names the package
reset("windows", nil, "noop")
local ok5, why5 = entry()
check(ok5 == false and has(why5, "not written"), "a command that wrote nothing is not a shortcut")
check(#WARNS == 1 and has(WARNS[1], "winscp: shortcut " .. Q .. "WinSCP" .. Q .. " was not written"),
      "one warning, naming the package")

-- 6. the command cannot run: still no raise (a cosmetic entry must not fail config())
reset("windows", nil, "raise")
local ran, ok6, err6 = pcall(shortcut.create, { name = "WinSCP", target = DIR .. "/WinSCP.exe" })
check(ran == true and ok6 == false and type(err6) == "string" and has(err6, "command not found"),
      "a failing exec is answered, not raised")
check(#WARNS == 1, "and said once")

-- 7. no APPDATA
reset("windows", {})
local ok7 = entry()
check(ok7 == false and #EXECS == 0 and #WARNS == 1 and has(WARNS[1], "APPDATA is not set"),
      "a missing APPDATA is said, once")

-- 8. another host: nothing happens, and nothing is printed
reset("linux", {})
check(entry() == false and #EXECS == 0 and #WARNS == 0, "another host: no command, no warning")
check(shortcut.remove({ name = "WinSCP" }) == false, "another host: nothing to remove")

-- 9. removal
reset()
entry()
check(shortcut.remove({ name = "WinSCP" }) == true and FILES[MENU] == nil,
      "remove deletes the entry create wrote")
check(shortcut.remove({ name = "WinSCP" }) == false, "a second remove is not an error")

-- 10. a location that is not one
reset()
local ok10, why10 = shortcut.create({ name = "WinSCP", target = DIR, location = "taskbar" })
check(ok10 == false and has(why10, "unknown location"), "an unknown location is refused")

print(string.format("PASS: %d checks", n))
