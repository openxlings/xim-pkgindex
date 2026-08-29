-- Exercise the GBM entry of the graphics discovery layer, in a plain-Lua
-- sandbox — the way libxpkg runs a hook: no xmake, only the globals a prelude
-- provides.
--
-- WHAT THIS IS DEFENDING
--
-- Three ways the GBM wiring can be silently wrong, all of which produce an
-- install that reports success and a gbm_create_device() that returns NULL:
--
--   * the variable missing from DISCOVERY entirely. That was the state before
--     this entry existed: LIBGL_DRIVERS_PATH and __EGL_VENDOR_LIBRARY_DIRS were
--     declared and GBM_BACKENDS_PATH was not, so libgbm kept searching the
--     `/usr/lib/gbm` compiled into it at mesa's `--prefix=/usr` build — a
--     directory that does not exist once the payload is relocated. Measured:
--       MESA-LOADER: failed to open dri: /usr/lib/gbm/dri_gbm.so: cannot open
--       shared object file (search paths /usr/lib/gbm, suffix _gbm)
--
--   * the destination not starting with `usr`/`etc`/`share`. xlings' file-asset
--     whitelist (xvm/bindings.cppm is_permitted_file_destination) REJECTS other
--     destinations, and a rejected destination is not an error — the placement
--     simply does not happen. `lib/gbm` would install cleanly, set the variable
--     to a directory that was never populated, and render nothing.
--
--   * S2 and S3 disagreeing. Both are generated from the one DISCOVERY table
--     precisely so they cannot; this asserts that they still are.
--
-- The two emitters are checked for FORM, not for a verdict: the form is the
-- part that silently degrades.

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

-- Captured rather than discarded: `declare_subos_env` is only observable
-- through the calls it makes.
local subos_calls = {}
local warned = {}

-- xmake's `import("a.b.c")` binds a GLOBAL named `c` as a side effect, and
-- graphics.lua calls it bare (`import("xim.libxpkg.subos")`, no assignment).
-- A stub that only returns the module leaves those globals nil, so the module
-- has to be published under its last path segment as well.
function import(name)
    local mod
    if name == "xim.libxpkg.subos" then
        mod = { env = function(t) table.insert(subos_calls, t) end }
    elseif name == "xim.libxpkg.log" then
        mod = { warn = function(fmt, ...) table.insert(warned, tostring(fmt)) end,
                error = function() end, info = function() end }
    else
        -- xvm.files must be a FUNCTION for declare_dri/declare_gbm to proceed --
        -- both start with `if not xvm.files then return false end`.
        mod = setmetatable({}, {__index = function() return function() end end})
    end
    _G[name:match("[^.]+$")] = mod
    return mod
end

os.isdir = function(p)
    -- Only the payload directory the positive case names exists.
    return p == "/fake/payload/lib/gbm"
end
os.isfile = function() return false end
os.iorun = function() return "" end

local graphics = dofile(ROOT .. "/libs/graphics.lua")
assert(type(graphics) == "table", "libs/graphics.lua must return its module table")

local function fail(msg) io.write("FAIL: ", msg, "\n"); os.exit(1) end

-- ── 1. the constant exists and is inside the permitted whitelist ───────
if graphics.GBM_DIR == nil then
    fail("graphics.GBM_DIR is not defined")
end
if graphics.GBM_DIR:sub(1, 4) ~= "usr/" then
    fail("GBM_DIR must start with usr/ (xlings file-asset whitelist accepts "
         .. "only usr/, etc/, share/ and REJECTS silently); got "
         .. graphics.GBM_DIR)
end

-- ── 2. S2: a consumer shim carries it ──────────────────────────────────
local envs = graphics.consumer_envs()
local s2 = envs["GBM_BACKENDS_PATH"]
if s2 == nil then
    fail("consumer_envs() does not carry GBM_BACKENDS_PATH")
end
if s2 ~= "${XLINGS_DYNAMIC_SUBOS_DIR}/" .. graphics.GBM_DIR then
    fail("consumer_envs() GBM_BACKENDS_PATH = " .. s2 .. " (expected the "
         .. "dynamic-subos spelling over GBM_DIR)")
end

-- ── 3. S3: a subos shell gets the same value, as a prepend ─────────────
graphics.declare_subos_env("mesa@test")
local s3
for _, c in ipairs(subos_calls) do
    if c.var == "GBM_BACKENDS_PATH" then s3 = c end
end
if s3 == nil then
    fail("declare_subos_env() does not declare GBM_BACKENDS_PATH")
end
if s3.op ~= "prepend" then
    fail("GBM_BACKENDS_PATH must be declared with op=prepend (it is a "
         .. "colon-separated list libgbm walks in order, and a `set` would "
         .. "erase another provider's entry); got op=" .. tostring(s3.op))
end
if not tostring(s3.value):find(graphics.GBM_DIR, 1, true) then
    fail("declare_subos_env() GBM_BACKENDS_PATH value does not name GBM_DIR: "
         .. tostring(s3.value))
end

-- ── 4. S2 and S3 name the same directory ───────────────────────────────
-- Different placeholder syntax, same tail. If these ever diverge, one of the
-- two emitters stopped reading DISCOVERY.
local function tail(v) return (tostring(v):gsub("^%$%b{}/", "")) end
if tail(s2) ~= tail(s3.value) then
    fail("S2 and S3 disagree: " .. tail(s2) .. " vs " .. tail(s3.value))
end

-- ── 5. declare_gbm refuses a payload that has no backends ──────────────
-- Not an error — a mesa built without the dri gbm backend is legitimate — but
-- it must return false and say so, because the alternative is a variable
-- pointing at an empty directory.
if graphics.declare_gbm == nil then
    fail("graphics.declare_gbm is not defined")
end
if graphics.declare_gbm("/fake/payload", "lib/nonexistent", "mesa@test") ~= false then
    fail("declare_gbm must return false when the payload has no such directory")
end
if #warned == 0 then
    fail("declare_gbm must warn when it refuses, or the empty directory is silent")
end
if graphics.declare_gbm("/fake/payload", "lib/gbm", "mesa@test") ~= true then
    fail("declare_gbm must return true when the payload directory exists")
end

io.write("OK\n")
