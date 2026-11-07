-- Exercise libs/nvim_plugin.lua in a plain-Lua sandbox, the way libxpkg runs a
-- hook: no xmake, only the handful of globals the prelude provides. The host,
-- the environment, the `nvim` on PATH and what `pkgmanager.install` brings are
-- forged per case, so every branch of the provisioning is reached on any
-- machine; the copy into the site pack runs for real under FAKE_ROOT.

local ROOT = assert(os.getenv("FAKE_ROOT"), "FAKE_ROOT required")
local LIB = assert(os.getenv("NVIM_PLUGIN"), "NVIM_PLUGIN required")

-- ── the sandbox ────────────────────────────────────────────────────────
-- path.join as libxpkg's prelude defines it: empty parts are skipped and a
-- trailing separator is not doubled.
path = {}
function path.join(...)
    local parts = {...}
    local result = parts[1] or ""
    for i = 2, #parts do
        if parts[i] and parts[i] ~= "" then
            result = result:gsub("[/\\]+$", "") .. "/" .. parts[i]
        end
    end
    return result
end

local HOST = "linux"
local ENV = {}
os.host = function() return HOST end
os.getenv = function(k) return ENV[k] end

-- The `nvim` on PATH: NVIM[cmd] is the version that command answers with, or
-- nil when it is not runnable. xmake's os.iorun raises on a failed command,
-- which is what the probe's pcall is for.
local NVIM = {}
local probes = 0
os.iorun = function(cmd)
    probes = probes + 1
    local v = NVIM[cmd]
    if not v then error("command not found: " .. cmd) end
    return "NVIM v" .. v .. "\nBuild type: Release\nLuaJIT 2.1\n"
end

-- What installing a coordinate puts on PATH, and the coordinates asked for.
local PROVIDES = {}
local installs = {}
local _stub_pkgmanager = {
    install = function(coord)
        installs[#installs + 1] = coord
        if PROVIDES[coord] then NVIM["nvim --version"] = PROVIDES[coord] end
    end,
}

local logged = { info = {}, warn = {}, error = {} }
local function _logger(level)
    return function(fmt, ...)
        local line = string.format(fmt, ...)
        table.insert(logged[level], line)
        print("[" .. level .. "] " .. line)
    end
end
local _stub_log = { info = _logger("info"), warn = _logger("warn"), error = _logger("error") }

function import(name)
    if name == "xim.libxpkg.log" then log = _stub_log; return _stub_log end
    if name == "xim.libxpkg.pkgmanager" then pkgmanager = _stub_pkgmanager; return _stub_pkgmanager end
    error("unexpected import: " .. name)
end

-- The file operations as the prelude runs them on a POSIX host.
os.tryrm = function(p) os.execute(string.format('rm -rf "%s"', p)) end
os.mkdir = function(p) os.execute(string.format('mkdir -p "%s"', p)) end
os.cp = function(src, dst) os.execute(string.format('cp -a "%s" "%s"', src, dst)) end
os.isfile = function(p)
    local f = io.open(p, "rb")
    if not f then return false end
    local ok = f:read(0)
    f:close()
    return ok ~= nil
end
local function isdir(p)
    local ok = os.execute(string.format('test -d "%s"', p))
    return ok == true or ok == 0
end

local ok_count, fail_count = 0, 0
local function check(name, got, want)
    if got == want then
        print(string.format("  ok   %s -> %s", name, tostring(got)))
        ok_count = ok_count + 1
    else
        print(string.format("  FAIL %s -> got %s, want %s",
                            name, tostring(got), tostring(want)))
        fail_count = fail_count + 1
    end
end

-- A fresh case: host, environment, the nvim on PATH, what an install brings.
local function case(host, env, nvim, provides)
    HOST, ENV, NVIM, PROVIDES = host, env or {}, nvim or {}, provides or {}
    installs, probes = {}, 0
    logged = { info = {}, warn = {}, error = {} }
end

-- ── load the module under test ─────────────────────────────────────────
local nvim_plugin = assert(loadfile(LIB))()

print("== 1. versions compare numerically, a missing component is 0 ==")
local at_least = nvim_plugin.version_at_least
check("0.10.0 >= 0.10.0", at_least("0.10.0", "0.10.0"), true)
check("0.10.4 >= 0.10.0", at_least("0.10.4", "0.10.0"), true)
check("0.12.5 >= 0.10.0", at_least("0.12.5", "0.10.0"), true)
check("1.0 >= 0.10.0", at_least("1.0", "0.10.0"), true)
check("0.10 >= 0.10.0", at_least("0.10", "0.10.0"), true)
check("0.9.5 < 0.10.0 (not a string compare)", at_least("0.9.5", "0.10.0"), false)
check("0.9.99 < 0.10.0", at_least("0.9.99", "0.10.0"), false)

print("== 2. Neovim's site dir per host ==")
case("linux", { XDG_DATA_HOME = "/x/data", HOME = "/home/u" })
check("linux, XDG_DATA_HOME", nvim_plugin.site_dir(), "/x/data/nvim/site")
case("linux", { XDG_DATA_HOME = "", HOME = "/home/u" })
check("linux, XDG_DATA_HOME empty", nvim_plugin.site_dir(), "/home/u/.local/share/nvim/site")
case("linux", { HOME = "/home/u" })
check("linux, HOME only", nvim_plugin.site_dir(), "/home/u/.local/share/nvim/site")
-- macOS is Unix to Neovim: not ~/Library/Application Support.
case("macosx", { HOME = "/Users/u" })
check("macosx, HOME", nvim_plugin.site_dir(), "/Users/u/.local/share/nvim/site")
case("macosx", { XDG_DATA_HOME = "/x/data", HOME = "/Users/u" })
check("macosx, XDG_DATA_HOME", nvim_plugin.site_dir(), "/x/data/nvim/site")
case("windows", { LOCALAPPDATA = "C:/Users/u/AppData/Local" })
check("windows, LOCALAPPDATA", nvim_plugin.site_dir(), "C:/Users/u/AppData/Local/nvim-data/site")
case("windows", { XDG_DATA_HOME = "D:/data", LOCALAPPDATA = "C:/Users/u/AppData/Local" })
check("windows, XDG_DATA_HOME", nvim_plugin.site_dir(), "D:/data/nvim-data/site")
case("linux", { XDG_DATA_HOME = "/x/data", NVIM_APPNAME = "lazyvim" })
check("linux, NVIM_APPNAME", nvim_plugin.site_dir(), "/x/data/lazyvim/site")
case("windows", { LOCALAPPDATA = "C:/Users/u/AppData/Local", NVIM_APPNAME = "lazyvim" })
check("windows, NVIM_APPNAME", nvim_plugin.site_dir(), "C:/Users/u/AppData/Local/lazyvim-data/site")

print("== 3. the pack dir is pack/xim/start/<name> under the site dir ==")
case("linux", { XDG_DATA_HOME = "/x/data" })
check("pack_dir(mcppls)", nvim_plugin.pack_dir("mcppls"), "/x/data/nvim/site/pack/xim/start/mcppls")
check("pack_dir(mcpp)", nvim_plugin.pack_dir("mcpp"), "/x/data/nvim/site/pack/xim/start/mcpp")

print("== 4. the probe reads `nvim --version`; Windows also asks nvim.exe ==")
case("linux", {}, { ["nvim --version"] = "0.12.5" })
check("linux, nvim answers", nvim_plugin.version(), "0.12.5")
case("linux", {}, {})
check("linux, no nvim", nvim_plugin.version(), nil)
case("windows", {}, { ["nvim.exe --version"] = "0.11.5" })
check("windows, only nvim.exe answers", nvim_plugin.version(), "0.11.5")

print("== 5. provisioning: detect first, install only on absence, re-probe ==")
case("linux", {}, { ["nvim --version"] = "0.12.5" }, { ["xim:nvim"] = "0.12.5" })
check("present: the version", nvim_plugin.provision(), "0.12.5")
check("present: nothing installed", #installs, 0)
check("present: no warning", #logged.warn, 0)

case("linux", {}, { ["nvim --version"] = "0.9.5" }, { ["xim:nvim"] = "0.12.5" })
check("too old: the version, not a failure", nvim_plugin.provision(), "0.9.5")
check("too old: nothing installed", #installs, 0)
check("too old: one warning", #logged.warn, 1)

case("linux", {}, {}, { ["xim:nvim"] = "0.12.5" })
check("absent, xim:nvim brings it", nvim_plugin.provision(), "0.12.5")
check("absent, xim:nvim brings it: one install", #installs, 1)
check("absent, xim:nvim brings it: the qualified spelling", installs[1], "xim:nvim")

case("linux", {}, {}, { ["nvim"] = "0.11.5" })
check("absent, only the bare spelling brings it", nvim_plugin.provision(), "0.11.5")
check("absent, bare spelling: two installs", #installs, 2)
check("absent, bare spelling: qualified first", installs[1], "xim:nvim")
check("absent, bare spelling: bare second", installs[2], "nvim")

case("linux", {}, {}, {})
check("absent, nothing brings it: nil", nvim_plugin.provision(), nil)
check("absent, nothing brings it: both spellings tried", #installs, 2)
check("absent, nothing brings it: re-probed after each", probes, 3)
check("absent, nothing brings it: one warning", #logged.warn, 1)

print("== 6. the copy lands as the plugin root, again on a second config ==")
local src = ROOT .. "/install"
os.mkdir(src .. "/lua/demo")
local f = assert(io.open(src .. "/lua/demo/init.lua", "w"))
f:write("return {}\n")
f:close()
case("linux", { XDG_DATA_HOME = ROOT .. "/data" })
local pack = ROOT .. "/data/nvim/site/pack/xim/start/demo"
check("first copy: the pack dir", nvim_plugin.copy_to_pack(src, "demo", "lua/demo/init.lua"), pack)
check("second copy: the pack dir", nvim_plugin.copy_to_pack(src, "demo", "lua/demo/init.lua"), pack)
check("second copy: the plugin root, not nested", os.isfile(pack .. "/lua/demo/init.lua"), true)
check("second copy: no install dir inside", isdir(pack .. "/install"), false)
check("a file that did not land: nil", nvim_plugin.copy_to_pack(src, "demo", "lua/demo/missing.lua"), nil)
check("a file that did not land: said", #logged.error, 1)

print("== 7. removal takes exactly the copy ==")
nvim_plugin.copy_to_pack(src, "demo", "lua/demo/init.lua")
os.mkdir(ROOT .. "/data/nvim/site/pack/xim/start/other")
nvim_plugin.remove_from_pack("demo")
check("the copy is gone", isdir(pack), false)
check("a sibling stays", isdir(ROOT .. "/data/nvim/site/pack/xim/start/other"), true)
check("the plugin's install dir stays", os.isfile(src .. "/lua/demo/init.lua"), true)

print("== 8. macOS: the copy an earlier recipe left in ~/Library is taken away ==")
local home = ROOT .. "/home"
local stale = home .. "/Library/Application Support/nvim/site/pack/xim/start/demo"
case("macosx", { HOME = home })
os.mkdir(stale)
check("copy: the pack dir", nvim_plugin.copy_to_pack(src, "demo", "lua/demo/init.lua"),
      home .. "/.local/share/nvim/site/pack/xim/start/demo")
check("copy: the stale copy is gone", isdir(stale), false)
os.mkdir(stale)
nvim_plugin.remove_from_pack("demo")
check("remove: the stale copy is gone", isdir(stale), false)
check("remove: the copy is gone", isdir(home .. "/.local/share/nvim/site/pack/xim/start/demo"), false)

print()
if fail_count == 0 then
    print(string.format("PASS: %d assertions", ok_count))
    os.exit(0)
else
    print(string.format("FAIL: %d failed, %d passed", fail_count, ok_count))
    os.exit(1)
end
