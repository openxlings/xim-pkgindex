-- Run node.lua's config() against a forged install dir, in plain Lua.
--
--     lua5.4 node_preload_harness.lua <recipe.lua> <install_dir> [patchelf_dir]
--
-- Only the hook runtime is stubbed; the shell the hook hands its work to runs
-- for real, so what is asserted afterwards is the ELF on disk, not what the
-- hook meant to do. `patchelf_dir` is what pkginfo.tool_payload_dir answers
-- (a directory holding bin/patchelf); without it the hook falls back to PATH.
--
-- Prints one line per log.warn as `WARN <message>`, then `CONFIG <result>`.

local recipe, install_dir, patchelf_dir = ...
assert(recipe and install_dir,
       "usage: lua node_preload_harness.lua <recipe.lua> <install_dir> [patchelf_dir]")

local function isfile(p)
    local f = io.open(p, "rb")
    if f then f:close() return true end
    return false
end

local stubs = {
    ["xim.libxpkg.pkginfo"] = {
        install_dir = function() return install_dir end,
        version = function() return "0.0.0" end,
        tool_payload_dir = function() return patchelf_dir end,
    },
    ["xim.libxpkg.xvm"] = { add = function() end, remove = function() end },
    ["xim.libxpkg.log"] = {
        debug = function() end,
        info = function() end,
        warn = function(fmt, ...) print("WARN " .. string.format(fmt, ...)) end,
        error = function(fmt, ...) print("ERROR " .. string.format(fmt, ...)) end,
    },
    ["xim.libxpkg.system"] = {
        exec = function(cmd)
            local ok = os.execute(cmd)
            if not ok then error("exec failed: " .. cmd) end
        end,
    },
}

local env = setmetatable({}, { __index = _G })
env.import = function(name)
    local name_only = name:match("^([^,]+)")
    return stubs[name_only] or {}
end
-- xmake-style globals the recipe relies on, on top of plain Lua.
env.os = setmetatable({
    host = function() return "linux" end,
    isfile = isfile,
}, { __index = os })
env.io = setmetatable({
    writefile = function(p, s)
        local f = io.open(p, "wb")
        if not f then return false end
        f:write(s) f:close()
        return true
    end,
}, { __index = io })
env.path = { join = function(...) return table.concat({ ... }, "/") end }

local chunk = assert(loadfile(recipe, "t", env))
chunk()
-- import() binds by the module's last component, as the hook runtime does.
for full, mod in pairs(stubs) do env[full:match("([^.]+)$")] = mod end

print("CONFIG " .. tostring(env.config()))
