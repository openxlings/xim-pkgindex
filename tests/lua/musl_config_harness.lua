-- Runs musl.lua's config() or uninstall() against a payload directory and
-- prints what it asks of xlings, one line each:
--
--   add <name> <type> <version> <binding>
--   files <src> <dst> <binding>
--   remove <name> <version>
--
-- usage: lua musl_config_harness.lua <recipe> <arch> <config|uninstall>
--            <payload> [<name>,... registered in the home]
local recipe, arch, mode, payload, registered = ...
assert(recipe and (arch == "x86_64" or arch == "aarch64") and payload)
function is_arch(want) return arch == want end
local proxy
proxy = setmetatable({}, { __index = function() return proxy end, __call = function() return proxy end })
function import(name) _G[name:match("[^.]+$")] = proxy end
dofile(recipe)

local known = {}
for name in (registered or ""):gmatch("[^,]+") do known[name] = true end
local function exists(p, flag)
    return os.execute(string.format('test %s "%s"', flag, p)) == true
end
path = {
    join = function(...) return table.concat({...}, "/") end,
    directory = function(p) return p:match("^(.*)/[^/]+$") end,
    filename = function(p) return p:match("([^/]+)$") end,
}
os.isfile = function(p) return exists(p, "-f") end
os.isdir = function(p) return exists(p, "-d") end
pkginfo = {
    install_dir = function() return payload end,
    version = function() return payload:match("([^/]+)$") end,
}
xvm = {
    add = function(name, opt)
        opt = opt or {}
        print(table.concat({ "add", name, opt.type or "program",
                             opt.version or pkginfo.version(), opt.binding or "-" }, " "))
    end,
    remove = function(name, version) print("remove " .. name .. " " .. (version or "")) end,
    has = function(name, version) return known[name .. "@" .. version] == true end,
}
sysroot = {
    declare_headers = function(_, src_rel, dst_rel, binding)
        print(table.concat({ "files", src_rel, dst_rel, binding }, " "))
        return true
    end,
}
if mode == "config" then
    assert(config())
else
    assert(uninstall())
end
