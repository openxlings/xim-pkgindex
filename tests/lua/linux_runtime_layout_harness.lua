-- Exercise payload paths using the recipe hooks with architecture API absent.
local recipe, archive, root, metadata_arch, payload_arch = ...
-- The payload holds its own architecture's loader and no other's.
payload_arch = payload_arch or (archive:find("aarch64", 1, true) and "aarch64" or "x86_64")
local own_loader = payload_arch == "aarch64" and "ld-linux-aarch64.so.1" or "ld-linux-x86-64.so.2"
if metadata_arch then os.arch = function() return metadata_arch end end
local calls = {}
path = {
    join = function(...) return table.concat({...}, "/") end,
    directory = function(p) return p:match("^(.*)/[^/]+$") end,
    filename = function(p) return p:match("[^/]+$") end,
}
os.isfile = function(p)
    if p:find("ld-linux-", 1, true) then return p:find(own_loader, 1, true) ~= nil end
    return true
end
os.host = function() return "linux" end
local proxy = setmetatable({}, {__index = function() return function() end end})
function import(name)
    local key = name:match("[^.]+$")
    if key == "pkginfo" then
        _G[key] = {
            install_file = function() return archive end,
            install_dir = function() return root end,
            version = function() return "2.44.3" end,
        }
    elseif key == "xvm" then
        _G[key] = {
            add = function(name, opts)
                if opts and opts.type == "lib" then
                    calls[#calls + 1] = name .. " " .. opts.bindir
                end
            end,
            remove = function(name) print("REMOVE " .. name) end,
        }
    else _G[key] = proxy end
end
dofile(recipe)
local runtime = package.xpm.linux.exports.runtime
print("EXPORT " .. runtime.loader .. " " .. runtime.abi .. " " .. table.concat(runtime.libdirs, ":"))
__config_header = function() end
assert(config())
for _, call in ipairs(calls) do print(call) end
uninstall()
