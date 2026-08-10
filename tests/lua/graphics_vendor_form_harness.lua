-- Exercise graphics.host_vendor_behind in a plain-Lua sandbox, the way libxpkg
-- runs a hook: no xmake, only the globals the prelude provides.
--
-- WHAT THIS IS DEFENDING
--
-- The function used to return nil for three unrelated situations and the
-- caller turned every nil into `state=native`, which the panel reports as a
-- PASS. Measured on a real NVIDIA home, ALL SIX vendors were recorded native
-- while the graphics stack was wired to nothing at all.
--
-- The two conflations, each reproduced below as its own case:
--
--   * readelf missing -> "" -> "this is ours, nothing to check"
--   * a bare symlink to the host driver has no absolute DT_NEEDED (a host
--     library names its siblings by soname), so "no absolute entry" read as
--     "our own build". It IS the host driver.
--
-- Every case here asserts the FORM, not the verdict, because the form is what
-- was wrong. The verdict is the caller's job and has its own test surface.

local ROOT = assert(os.getenv("FAKE_ROOT"), "FAKE_ROOT required")

-- ── the sandbox ────────────────────────────────────────────────────────
path = {}
function path.join(...)
    local parts = {...}
    local out = parts[1] or ""
    for i = 2, #parts do
        if out:sub(-1) == "/" then out = out .. parts[i]
        else out = out .. "/" .. parts[i] end
    end
    return out
end
function path.directory(p) return (p:gsub("/[^/]*$", "")) end
function path.filename(p) return (p:match("[^/]+$")) end

os.isfile = function(p)
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end

-- `readelf` is answered from a sidecar file so the harness needs no ELF
-- objects and no toolchain: `<lib>.readelf` holds what readelf would print,
-- and its ABSENCE is how the "tool did not run" case is reproduced -- which is
-- the case the real bug turned into a pass.
os.iorun = function(cmd)
    local target = cmd:match('"([^"]+)"')
    if cmd:match("^readelf") then
        local f = io.open(target .. ".readelf", "rb")
        if not f then return "" end
        local out = f:read("*a"); f:close(); return out
    end
    if cmd:match("^readlink") then
        local f = io.popen(string.format('readlink -f "%s"', target))
        if not f then return "" end
        local out = f:read("*a"); f:close(); return out
    end
    return ""
end

-- `import` is a libxpkg-sandbox global. The modules it pulls in are used by
-- other functions in the file, not by the one under test, so a stub that
-- yields an inert table is enough -- and it is the same reason the real
-- sandbox can stub an unknown module without the recipe noticing.
function import(_) return setmetatable({}, {__index = function() return function() end end}) end
log = {warn = function() end, info = function() end}

local graphics = dofile(ROOT .. "/libs/graphics.lua")
assert(type(graphics) == "table", "libs/graphics.lua must return its module table")

local failures = 0
local function check(name, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %-34s got=%s want=%s",
                            name, tostring(got), tostring(want)))
    else
        print(string.format("ok   %-34s %s", name, tostring(got)))
    end
end

local FIX = os.getenv("FIXTURE_DIR")
assert(FIX, "FIXTURE_DIR required")

-- 1. A stub of ours naming the host driver absolutely.
local _, form = graphics.host_vendor_behind(FIX .. "/interposed.so")
check("interposer -> interposed", form, "interposed")

-- 2. readelf produced nothing. NOT a verdict about the library: this is the
--    one that used to be recorded as a pass.
local _, form2 = graphics.host_vendor_behind(FIX .. "/unreadable.so")
check("no readelf -> unreadable", form2, "unreadable")

-- 3. A bare symlink to a host path. The vendor IS the host driver, and its
--    closure is every bit as unchecked as an interposer's.
local host3, form3 = graphics.host_vendor_behind(FIX .. "/direct.so")
check("host symlink -> direct", form3, "direct")
check("direct names the host lib", (host3 or ""):find("xpkgs", 1, true) == nil, true)

-- 4. Our own build: no absolute DT_NEEDED and it resolves inside the store.
local _, form4 = graphics.host_vendor_behind(FIX .. "/xpkgs/ours.so")
check("our build -> native", form4, "native")

if failures > 0 then
    print(string.format("%d case(s) failed", failures))
    os.exit(1)
end
print("all cases passed")
