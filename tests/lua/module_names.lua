-- The test harnesses mock the names of spec 1 (os.isfile, os.tryrm, os.iorun,
-- io.readfile, os.host, ...); libs/ and the recipes of spec 3 call the
-- modules' names (fs.is_file, fs.remove, system.exec, fs.read,
-- pkginfo.platform, ...). Once a harness loads a file of libs/ or pkgs/, each module name
-- it did not mock itself is answered by the spec 1 name it did mock, looked up
-- at the call. Loaded for every Lua the tests start (LUA_INIT, conftest.py).
local bridge = {
    fs = {
        is_file = function(p) return os.isfile(p) end,
        is_dir  = function(p) return os.isdir(p) end,
        exists  = function(p) return os.exists(p) end,
        mkdir   = function(p)
            local mk = rawget(fs, "mkdir_p") or os.mkdir
            return mk(p)
        end,
        remove  = function(p) return os.tryrm(p) end,
        move    = function(a, b) return os.mv(a, b) end,
        copy    = function(a, b, o) return os.cp(a, b, o) end,
        read    = function(p) return io.readfile(p) end,
        write   = function(p, s) return io.writefile(p, s) end,
    },
    system = {
        exec = function(cmd, opt)
            if type(opt) == "table" and opt.capture then return os.iorun(cmd) end
            return os.exec(cmd)
        end,
        run = function(cmd) return os.iorun(cmd) end,
    },
    pkginfo = {
        platform = function() return os.host() end,
        arch     = function() return os.arch() end,
    },
}

local function attach(name, t)
    if type(t) ~= "table" or getmetatable(t) then return end
    setmetatable(t, { __index = bridge[name] })
end

-- The mocked tables are kept beside _G rather than in it, so that every
-- assignment of one -- a harness may set `pkginfo` again for a second case --
-- passes through here and gets the module names.
local armed, mocked = false, {}
local function arm()
    if armed then return end
    armed = true
    for name in pairs(bridge) do
        local t = rawget(_G, name)
        if t ~= nil then
            attach(name, t)
            mocked[name] = t
            rawset(_G, name, nil)
        end
    end
    setmetatable(_G, {
        __index = function(_, k)
            if bridge[k] then return mocked[k] or bridge[k] end
        end,
        __newindex = function(g, k, v)
            if bridge[k] then
                attach(k, v)
                mocked[k] = v
            else
                rawset(g, k, v)
            end
        end,
    })
end

for _, name in ipairs({ "loadfile", "dofile" }) do
    local original = _G[name]
    _G[name] = function(file, ...)
        if type(file) == "string" and (file:match("libs/[^/]+%.lua$") or file:match("pkgs/.+%.lua$")) then arm() end
        return original(file, ...)
    end
end
