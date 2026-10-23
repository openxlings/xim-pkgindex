-- Run glibc.lua's binary relocation against a synthetic payload, in plain Lua.
--
--     lua5.4 glibc_relocate_harness.lua <recipe.lua> relocate <install_dir> <placeholder>
--     lua5.4 glibc_relocate_harness.lua <recipe.lua> assert   <install_dir>
--     lua5.4 glibc_relocate_harness.lua <recipe.lua> quote    <install_dir>
--
-- `relocate` calls __relocate_binaries(<install_dir>, <placeholder>) and then
-- __assert_no_reserved_prefix(<install_dir>, false), the binary half of what
-- install() does; `assert` calls __assert_no_reserved_prefix over every file;
-- `quote` calls __quote_linker_script_paths(<install_dir>).
--
-- The recipe is loaded with stub modules: only log.info is reached by these
-- functions, and it is printed as `INFO <message>`. The file operations are
-- the real ones (io.open, os.rename, `find`, `cp -p`), because they are what
-- is under test. Prints `RELOCATED <n>` / `ASSERTED` / `QUOTED <n>`, or `ERROR <message>`
-- when the function raised.

local recipe, mode, install_dir, placeholder = ...
assert(recipe and (mode == "relocate" or mode == "assert" or mode == "quote") and install_dir,
       "usage: lua glibc_relocate_harness.lua <recipe.lua> relocate|assert|quote <install_dir> [<placeholder>]")

local proxy
proxy = setmetatable({}, {
    __index = function() return proxy end,
    __call = function() return proxy end,
})

local modules = {
    log = {
        info = function(fmt, ...) print("INFO " .. string.format(fmt, ...)) end,
        warn = function(fmt, ...) print("WARN " .. string.format(fmt, ...)) end,
        debug = function() end,
    },
    pkginfo = {
        install_dir = function() return install_dir end,
        version = function() return "2.44.3" end,
    },
}

-- The index's own shared modules are the real ones: `shell.quote` builds the
-- `find` command the relocation walks with.
local libs = recipe:gsub("pkgs/[^/]+/[^/]+%.lua$", "libs/")
os.host = os.host or function() return "linux" end
function import(name)
    local short = name:match("[^.]+$")
    if not modules[short] and name:match("^xim%.pkgindex%.") then
        local chunk = loadfile(libs .. short .. ".lua")
        if chunk then modules[short] = chunk() end
    end
    _G[short] = modules[short] or proxy
    return _G[short]
end

function raise(msg) error(msg, 2) end

dofile(recipe)

local ok, err = pcall(function()
    if mode == "relocate" then
        local n = __relocate_binaries(install_dir, placeholder)
        if n > 0 then __assert_no_reserved_prefix(install_dir, false) end
        print("RELOCATED " .. n)
    elseif mode == "quote" then
        print("QUOTED " .. __quote_linker_script_paths(install_dir))
    else
        __assert_no_reserved_prefix(install_dir, true)
        print("ASSERTED")
    end
end)
if not ok then
    print("ERROR " .. tostring(err))
    os.exit(1)
end
