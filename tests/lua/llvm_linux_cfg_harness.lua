-- Exercise Linux compiler cfg generation with explicit dependency payloads.
local recipe, mode = ...
local written = {}
path = {join = function(...) return table.concat({...}, "/") end,
        directory = function(p) return p:match("^(.*)/[^/]+$") end}
os.isdir = function() return true end
os.isfile = function(filename)
    if filename == "/usr/include/linux/limits.h" then return true end
    return filename == "/managed/uapi/include/linux/limits.h" and mode ~= "missing-headers"
end
local modules = {
    pkginfo = {install_dir = function() return "/managed/llvm" end,
               version = function() return "23.1.3" end,
               dep_install_dir = function(coordinate)
                   assert(coordinate == "xim:linux-headers")
                   return "/managed/uapi"
               end},
    log = {error = function(message) print("ERROR " .. message) end},
}
function import(name)
    local key = name:match("[^.]+$")
    _G[key] = modules[key] or {}
end
io.writefile = function(filename, content)
    written[#written + 1] = filename
    print("FILE " .. filename .. "\n" .. content)
end
dofile(recipe)
__find_glibc_runtime = function()
    return "/managed/glibc/lib", "/managed/glibc/lib/ld-linux-aarch64.so.1"
end
__detect_triple = function() return "aarch64-unknown-linux-gnu" end
print("HOST MARKER " .. tostring(os.isfile("/usr/include/linux/limits.h")))
local ok = __install_linux_cfg()
print("RESULT " .. tostring(ok))
print("WRITTEN " .. #written)
