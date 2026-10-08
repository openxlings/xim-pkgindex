local recipe, arch, mode, payload = ...
assert(recipe and (arch == "x86_64" or arch == "aarch64"))
function is_arch(want) return arch == want end
local proxy
proxy = setmetatable({}, { __index = function() return proxy end, __call = function() return proxy end })
function import(name) _G[name:match("[^.]+$")] = proxy end
dofile(recipe)
if mode == "config" then
    assert(payload)
    path = {
        join = function(...) return table.concat({...}, "/") end,
        directory = function(p) return p:match("^(.*)/[^/]+$") end,
        filename = function(p) return p:match("([^/]+)$") end,
    }
    pkginfo = { install_dir = function() return payload end, version = function() return "2.44.3" end }
    sysroot = { declare_headers = function() return true end }
    os.isfile = function(p)
        local file = io.open(p, "rb")
        if not file then return false end
        file:close()
        return true
    end
    local registered = {}
    xvm = { add = function(name) table.insert(registered, name) end }
    assert(config())
    table.sort(registered)
    print(table.concat(registered, "\n"))
    return
end
local linux = package.xpm.linux
local version = linux.latest.ref
local resource = assert(linux[version][arch], "no resource for this architecture")
local runtime = linux.exports.runtime
local versions = {}
for key in pairs(linux) do
    if key:match("^%d") then table.insert(versions, key) end
end
table.sort(versions)
print(table.concat({runtime.loader, runtime.abi, tostring(linux[version].revision),
                   version, resource.sha256, resource.url.GLOBAL, resource.url.CN,
                   table.concat(versions, ",")}, "\t"))
