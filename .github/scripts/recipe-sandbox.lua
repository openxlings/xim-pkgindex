--
-- Loads an xpkg recipe AS LUA and returns the `package` table it declares.
--
-- Shared by the checks that read recipe structure rather than recipe text:
-- check-dep-namespace.lua (dep declarations) and check-revision.lua (version
-- entries and their `revision`). A recipe is data that spans lines, repeats
-- under several `xpm.<platform>` sections and is sometimes assembled by code
-- (npm assigns one table to three platforms after the literal), so a line
-- sweep both misses entries and misattributes them. Loading it gives the
-- values the client itself sees.
--
-- The recipe runs in a sandbox: hook bodies never run (loading a chunk does
-- not call its functions), and the top-level `import(...)` calls the recipes
-- make resolve to a permissive stub, so no libxpkg is required.
--
-- Requires Lua 5.2+ for `load`/`loadfile` with an env argument. On 5.1 or
-- LuaJIT the argument is ignored, every recipe runs against the real globals,
-- `import(...)` is nil, and every recipe fails to load; the wrappers probe the
-- interpreter version for that reason.
--
--     local sandbox = dofile(<dir> .. "/recipe-sandbox.lua")
--     local pkg, err = sandbox.load_recipe(path)
--     local pkg, err = sandbox.load_recipe_text(text, chunkname)
--     local pkg, err = sandbox.load_recipe_text(text, chunkname, { arch = "aarch64" })
--

local M = {}

-- A value that tolerates being indexed, called, iterated and printed, so
-- top-level recipe statements (`import("xim.libxpkg.pkginfo")`, and the
-- occasional `local x = something.y`) neither fail nor reach anything real.
local stub
stub = setmetatable({}, {
    __index    = function() return stub end,
    __newindex = function() end,
    __call     = function() return stub end,
    __concat   = function() return "" end,
    __tostring = function() return "" end,
    __len      = function() return 0 end,
})
M.stub = stub

-- The canonical name of an architecture spelling (the client's table).
local ARCH_ALIASES = { arm64 = "aarch64", amd64 = "x86_64", x64 = "x86_64" }
function M.normalized_arch(name)
    if type(name) ~= "string" then return name end
    local lower = name:lower()
    return ARCH_ALIASES[lower] or lower
end

-- `opts.arch`: the architecture the recipe is loaded for. A recipe's top level
-- may choose its URL with `os.arch()` or `is_arch(...)`, and what it chose is
-- what a client of that architecture saw; without `opts.arch` both are the
-- permissive stub, as before.
function M.sandbox_env(opts)
    opts = opts or {}
    local arch = opts.arch and M.normalized_arch(opts.arch) or nil
    -- os/io are handed out as safe subsets: a recipe may legitimately read
    -- os.getenv at load time, but nothing here may execute or delete.
    local safe_os = setmetatable(
        { time = os.time, date = os.date, clock = os.clock, getenv = os.getenv,
          arch = arch and function() return arch end or nil },
        { __index = function() return stub end })
    local safe_io = setmetatable({}, { __index = function() return stub end })

    local base = {
        assert = assert, error = error, ipairs = ipairs, pairs = pairs,
        next = next, pcall = pcall, xpcall = xpcall, select = select,
        tonumber = tonumber, tostring = tostring, type = type,
        rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen,
        setmetatable = setmetatable, getmetatable = getmetatable,
        unpack = table.unpack, print = function() end,
        string = string, table = table, math = math,
        os = safe_os, io = safe_io,
        is_arch = arch and function(...)
            for i = 1, select("#", ...) do
                if M.normalized_arch(select(i, ...)) == arch then return true end
            end
            return false
        end or nil,
    }
    local env = {}
    setmetatable(env, {
        __index = function(_, k)
            local v = base[k]
            if v ~= nil then return v end
            return stub
        end,
    })
    return env
end

local function run_chunk(chunk, err, env)
    if not chunk then return nil, "parse error: " .. tostring(err) end
    local ok, rerr = pcall(chunk)
    if not ok then return nil, "load error: " .. tostring(rerr) end
    local pkg = rawget(env, "package")
    if type(pkg) ~= "table" then return nil, "no `package` table" end
    return pkg, nil
end

-- Load one recipe file and return the `package` table it declares (or nil,
-- err). Running the chunk executes only its top level: the install/config/
-- uninstall hooks are defined, never called.
function M.load_recipe(file, opts)
    local env = M.sandbox_env(opts)
    local chunk, err = loadfile(file, "t", env)
    return run_chunk(chunk, err, env)
end

-- The same, for recipe text that is not a file in the work tree -- the
-- version of a recipe on another commit, read with `git show`.
function M.load_recipe_text(text, chunkname, opts)
    local env = M.sandbox_env(opts)
    local chunk, err = load(text, "=" .. tostring(chunkname), "t", env)
    return run_chunk(chunk, err, env)
end

function M.sorted_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

return M
