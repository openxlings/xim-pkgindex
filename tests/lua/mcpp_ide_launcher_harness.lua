-- Exercise actual config() with the launcher files carried by each package.
local recipe, host, form = ...
function import(_) end
path = { join = function(...) return table.concat({...}, "/") end }
pkginfo = { install_dir = function() return "C:/IDE package" end }
os.host = function() return host end
os.isfile = function(file)
    return form == "exe" and file == "C:/IDE package/bin/mcpp-ide.exe"
end
local observed
xvm = { add = function(name, opts)
    assert(name == "mcpp-ide")
    observed = opts
end }
dofile(recipe)
assert(config() == true)
assert(observed.bindir == "C:/IDE package/bin")
local want = host == "windows" and (form == "exe" and "mcpp-ide.exe" or "mcpp-ide.cmd") or nil
assert(observed.alias == want, "incorrect launcher: " .. tostring(observed.alias) .. " instead of " .. tostring(want))
print("launcher OK")
