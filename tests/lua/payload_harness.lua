-- Exercise libs/payload.lua in a plain-Lua sandbox, the way libxpkg runs a
-- hook: import() is a no-op that leaves the module globals forged below, and
-- the host, the environment, the filesystem and `system.exec` are forged per
-- case. Nothing is extracted for real; what is checked is the directory the
-- module moves, the command it builds, and what it refuses.

local LIB = assert(os.getenv("PAYLOAD_LIB"), "PAYLOAD_LIB required")
local WINPATH = assert(os.getenv("WINPATH_LIB"), "WINPATH_LIB required")

local B = string.char(92)   -- a backslash, kept out of every shell quoting

-- ── the sandbox ────────────────────────────────────────────────────────────
local HOST, ENV = "windows", {}
local DIRS, FILES, MVES, EXECS, MKDIRS, RMS = {}, {}, {}, {}, {}, {}

import = function() end   -- libxpkg's import() leaves these as globals
winpath = assert(loadfile(WINPATH))()
os.host = function() return HOST end
os.getenv = function(k) return ENV[k] end
os.isdir = function(p) return DIRS[p] == true end
os.isfile = function(p) return FILES[p] == true end
os.tryrm = function(p) RMS[#RMS + 1] = p end
os.mv = function(src, dst)
    MVES[#MVES + 1] = { src, dst }
    DIRS[src] = nil; DIRS[dst] = true
end
fs = { mkdir_p = function(p) MKDIRS[#MKDIRS + 1] = p end }
pkginfo = {
    name = function() return "nginx" end,
    version = function() return "1.28.0" end,
    install_file = function() return INSTALL_FILE end,
    install_dir = function() return INSTALL_DIR end,
}
local function logger(level)
    return function(fmt, ...) print("  [" .. level .. "] " .. string.format(fmt, ...)) end
end
log = { info = logger("info"), warn = logger("warn"), error = logger("error") }
system = { exec = function(cmd) EXECS[#EXECS + 1] = cmd end }

INSTALL_FILE = "C:/cache/nginx-1.28.0-win.zip"
INSTALL_DIR = "C:/xpkgs/nginx/1.28.0"

local payload = assert(loadfile(LIB))()

-- ── the checks ─────────────────────────────────────────────────────────────
local n = 0
local function check(cond, msg)
    if not cond then error("FAIL: " .. msg, 2) end
    n = n + 1
end
local function has(hay, needle) return hay:find(needle, 1, true) ~= nil end
local function reset(host, env)
    HOST = host or "windows"
    ENV = env or { SystemRoot = "C:" .. B .. "Windows" }
    DIRS, FILES, MVES, EXECS, MKDIRS, RMS = {}, {}, {}, {}, {}, {}
end

-- 1. the framework already extracted the archive: the directory is moved
reset()
DIRS["C:/cache/nginx-1.28.0"] = true
local ok, src = payload.unpack{ extracted = "nginx-1.28.0", strip = 1 }
check(ok == true and src == "C:/cache/nginx-1.28.0", "the moved directory is answered")
check(MVES[1] and MVES[1][1] == "C:/cache/nginx-1.28.0" and MVES[1][2] == INSTALL_DIR,
      "os.mv(src, install_dir)")
check(MKDIRS[1] == "C:/xpkgs/nginx", "the install directory's parent is made first")
check(RMS[1] == INSTALL_DIR, "the install directory is cleared first")
check(#EXECS == 0, "no command is run when the extraction is already there")

-- 2. a list is tried in order: the posix tarball and the windows zip disagree
reset()
DIRS["C:/cache/nginx"] = true          -- the second name
local ok2, src2 = payload.unpack{ extracted = { "nginx-1.28.0", "nginx" }, strip = 1 }
check(ok2 == true and src2 == "C:/cache/nginx", "the second candidate is taken")
check(MVES[1][1] == "C:/cache/nginx", "and only that one is moved")

-- 3. nothing pre-extracted, a zip, Windows: the system tar, absolute
reset()
local ok3 = payload.unpack{ extracted = "nginx-1.28.0", strip = 1 }
check(ok3 == true and #EXECS == 1, "one command")
check(EXECS[1] == "C:" .. B .. "Windows" .. B .. "System32" .. B .. "tar.exe"
      .. ' -xf "C:' .. B .. 'cache' .. B .. 'nginx-1.28.0-win.zip"'
      .. " --strip-components=1"
      .. ' -C "C:' .. B .. 'xpkgs' .. B .. 'nginx' .. B .. '1.28.0"',
      "the exact command: " .. EXECS[1])
check(MKDIRS[1] == INSTALL_DIR, "the install directory is made for the extraction")

-- 4. strip omitted (a zip with no root directory): no strip flag
reset()
INSTALL_FILE = "C:/cache/Everything.zip"
local ok4 = payload.unpack{}
check(ok4 == true and has(EXECS[1], " -xf ") and not has(EXECS[1], "strip-components"),
      "no strip flag when none is asked for")
INSTALL_FILE = "C:/cache/nginx-1.28.0-win.zip"

-- 5. SystemRoot unset or trailing-slashed still names the one tar
reset("windows", {})
payload.unpack{}
check(has(EXECS[#EXECS], "C:" .. B .. "Windows" .. B .. "System32" .. B .. "tar.exe"),
      "the default SystemRoot names the system tar")
reset("windows", { SystemRoot = "C:" .. B .. "Windows" .. B .. B })
payload.unpack{}
check(has(EXECS[#EXECS], "System32" .. B .. "tar.exe")
      and not has(EXECS[#EXECS], "System32" .. B .. B),
      "a trailing backslash on SystemRoot is not doubled")

-- 6. fail closed: nothing pre-extracted and not an extractable archive
reset("linux", {})
local r6, e6 = pcall(payload.unpack, { extracted = { "nginx-1.28.0", "nginx" } })
check(r6 == false and has(e6, "nginx-1.28.0, nginx") and has(e6, "C:/cache"),
      "the error names every candidate and where it looked: " .. tostring(e6))
reset("linux", {})
INSTALL_FILE = "C:/cache/payload.zip"   -- a zip, but not on windows
local r6b, e6b = pcall(payload.unpack, { extracted = "payload" })
check(r6b == false, "a zip on another host is not silently extracted with the wrong tar")
INSTALL_FILE = "C:/cache/nginx-1.28.0-win.zip"

-- 7. require: every file named, the missing ones listed
reset()
FILES["C:/xpkgs/nginx/1.28.0/conf/nginx.conf"] = true
check(payload.require{ "conf/nginx.conf" } == true, "a present file passes")
local r7, e7 = pcall(payload.require, { "conf/nginx.conf", "sbin/nginx", "html/index.html" })
check(r7 == false and has(e7, "sbin/nginx") and has(e7, "html/index.html"),
      "each missing file is named")
check(r7 == false and not has(e7, "conf/nginx.conf"), "a present file is not listed")
check(r7 == false and has(e7, "C:/xpkgs/nginx/1.28.0"), "and the directory is named")

-- 8. present: the boolean for installed()
reset()
check(payload.present{ "conf/nginx.conf" } == false, "absent is false")
FILES["C:/xpkgs/nginx/1.28.0/conf/nginx.conf"] = true
FILES["C:/xpkgs/nginx/1.28.0/sbin/nginx"] = true
check(payload.present{ "conf/nginx.conf", "sbin/nginx" } == true, "all present is true")
FILES["C:/xpkgs/nginx/1.28.0/sbin/nginx"] = nil
check(payload.present{ "conf/nginx.conf", "sbin/nginx" } == false, "one absent is false")

print(string.format("PASS: %d checks", n))
