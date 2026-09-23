-- Run gcc.lua's __prune_stale_fixincludes() against a synthetic
-- include-fixed tree, in plain Lua.
--
--     lua5.4 gcc_prune_fixincludes_harness.lua <recipe.lua> <install_dir> <variant>
--
-- <variant> selects which of libxpkg's two os.iorun implementations this
-- reproduces, so the same recipe function is exercised under both:
--
--   prelude   -- src/lua-stdlib/prelude.lua:182,  io.popen(cmd .. " 2>/dev/null")
--   executor  -- src/xpkg-executor.cppm:311-339, std::system(cmd .. ' 2>/dev/null
--               > "<tmp>"') followed by reading that temp file back
--
-- Neither raises on a non-zero exit; both just hand back whatever the
-- command wrote to stdout.
--
-- The harness process's OWN current working directory is what the shelled-out
-- `grep` inherits -- that is the exact channel the bug used (a `grep -r` with
-- no file operand recurses into cwd instead of the payload) -- so cwd is
-- controlled by the CALLER (chdir before invoking lua5.4), not by this
-- script.
--
-- Prints one line per log.info/log.warn call as `INFO <message>` /
-- `WARN <message>`, then `PRUNE done` (or `PRUNE ERROR <message>` if the
-- function raised).

local recipe, install_dir, variant = ...
assert(recipe and install_dir and (variant == "prelude" or variant == "executor"),
       "usage: lua gcc_prune_fixincludes_harness.lua <recipe.lua> <install_dir> <prelude|executor>")

-- xmake string extensions the recipe relies on (`s:trim()`, `s:split(sep,
-- opt)`). Added to the real global `string` table, not to the sandboxed env
-- below: a string value's metatable is fixed at the VM level and always
-- resolves through the actual global `string` table, regardless of which
-- _ENV a given chunk was loaded with.
function string.trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
function string.split(s, sep)
    local out = {}
    if sep == "" then return { s } end
    local start = 1
    while true do
        local i, j = s:find(sep, start, true)
        if not i then
            out[#out + 1] = s:sub(start)
            break
        end
        out[#out + 1] = s:sub(start, i - 1)
        start = j + 1
    end
    return out
end

local function isfile(p)
    local f = io.open(p, "rb")
    if f then f:close() return true end
    return false
end
local function isdir(p)
    return os.execute('test -d "' .. p .. '"') == true
end

-- Faithful to the two real os.iorun bodies (prelude.lua:182 and
-- xpkg-executor.cppm:311-339): neither checks the command's exit status,
-- both just return captured stdout, and only the mechanism used to capture it
-- differs -- which is exactly the mechanism the `|| true` trap depends on.
local function iorun(cmd)
    if variant == "prelude" then
        local f = io.popen(cmd .. " 2>/dev/null")
        if not f then return "" end
        local output = f:read("*a")
        f:close()
        return output or ""
    else
        local tmp = os.tmpname()
        os.execute(cmd .. ' 2>/dev/null > "' .. tmp .. '"')
        local f = io.open(tmp, "rb")
        local out = f and f:read("*a") or ""
        if f then f:close() end
        os.remove(tmp)
        return out or ""
    end
end

local stubs = {
    ["xim.libxpkg.pkginfo"] = { install_dir = function() return install_dir end },
    ["xim.libxpkg.log"] = {
        debug = function() end,
        info = function(fmt, ...) print("INFO " .. string.format(fmt, ...)) end,
        warn = function(fmt, ...) print("WARN " .. string.format(fmt, ...)) end,
        error = function(fmt, ...) print("ERROR " .. string.format(fmt, ...)) end,
    },
    ["xim.libxpkg.system"] = {},
    ["xim.libxpkg.xvm"] = {},
    ["xim.libxpkg.pkgmanager"] = {},
}

local env = setmetatable({}, { __index = _G })
env.import = function(name)
    local name_only = name:match("^([^,]+)")
    return stubs[name_only] or {}
end
env.os = setmetatable({
    host = function() return "linux" end,
    isfile = isfile,
    isdir = isdir,
    iorun = iorun,
    tryrm = function(p) return os.remove(p) ~= nil end,
}, { __index = os })
env.path = {
    join = function(...) return table.concat({ ... }, "/") end,
    filename = function(p) return p:match("([^/\\]+)$") or p end,
}

local chunk = assert(loadfile(recipe, "t", env))
chunk()
-- import() binds by the module's last component, as the hook runtime does.
for full, mod in pairs(stubs) do env[full:match("([^.]+)$")] = mod end

assert(env.__prune_stale_fixincludes, "recipe does not define __prune_stale_fixincludes")
local ok, err = pcall(env.__prune_stale_fixincludes)
if ok then
    print("PRUNE done")
else
    print("PRUNE ERROR " .. tostring(err))
end
