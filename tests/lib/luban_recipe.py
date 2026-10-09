"""Execute declaration/config hooks with filesystem IO and a captured owner API."""
import os
from pathlib import Path
import shutil
import subprocess


def run_recipe(recipe, target, version="0.1.0", env=None, fail_policy=False):
    lua = shutil.which("lua") or shutil.which("lua5.4")
    if not lua:
        raise RuntimeError("Lua interpreter required")
    recipe = str(Path(recipe).resolve())
    target.mkdir(parents=True, exist_ok=True)
    harness = r'''
local recipe, target, version, fail = arg[1], arg[2], arg[3], arg[4]
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function exec(cmd)
    if cmd:match("^xlings subos config ") then
        local f = assert(io.open(target .. "/commands.txt", "a")); f:write(cmd .. "\n"); f:close()
        if fail == "yes" then error("policy rejected") end
        return
    end
    local ok = os.execute(cmd)
    if ok ~= true and ok ~= 0 then error("command failed: " .. cmd) end
end
os.mkdir = function(p) exec("mkdir -p " .. q(p)) end
os.tryrm = function(p) exec("rm -rf " .. q(p)) end
os.isfile = function(p) local f = io.open(p, "rb"); if f then f:close(); return true end; return false end
os.isdir = function(p) local ok = os.execute("test -d " .. q(p)); return ok == true or ok == 0 end
function import(name)
    local bare = name:match("xim%.libxpkg%.(.+)")
    assert(bare, "unexpected import " .. name)
    if bare == "pkginfo" then pkginfo = {install_dir=function() return target end, version=function() return version end}
    elseif bare == "system" then system = {exec=exec, subos_sysrootdir=function() return target .. "/subos/agent" end}
    elseif bare == "log" then log = {info=function() end}
    else error("unexpected module " .. bare) end
end
dofile(recipe)
assert(install())
if config then assert(config()) end
'''
    script = target.parent / (target.name + "-harness.lua")
    script.write_text(harness)
    return subprocess.run([lua, str(script), recipe, str(target), version,
                           "yes" if fail_policy else "no"],
                          env={**os.environ, **(env or {})}, text=True, capture_output=True)
