#!/usr/bin/env lua
--
-- Prints the `package` table of each recipe as one JSON line, as the recipe
-- sandbox loads it (.github/scripts/recipe-sandbox.lua: the top level runs,
-- hooks are defined and never called, imports are stubs). Functions are
-- dropped; a value the stub produced prints as "<stub>".
--
--     lua dump.lua [--arch <arch>] <recipe.lua>...
--
-- `--arch`: load the recipe as a client of that architecture does (os.arch()
-- and is_arch() answer for it); without it both are the permissive stub, as in
-- the census of the design (§2.2).
--
-- Output, one line per file: {"file": ..., "package": {...}} or
-- {"file": ..., "error": "..."}.

local SCRIPT_DIR = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local sandbox = dofile(SCRIPT_DIR .. "/../.github/scripts/recipe-sandbox.lua")

local function quote(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return map[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
end

local encode
encode = function(v, depth, seen)
    local t = type(v)
    if v == sandbox.stub then return '"<stub>"' end
    if t == "string" then return quote(v) end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        if math.type and math.type(v) == "integer" then return tostring(v) end
        return string.format("%.17g", v)
    end
    if t == "boolean" then return tostring(v) end
    if t ~= "table" then return nil end
    if depth > 40 or seen[v] then return '"<cycle>"' end
    seen[v] = true
    local n, count = #v, 0
    for _ in pairs(v) do count = count + 1 end
    local out = {}
    if n > 0 and n == count then
        for i = 1, n do
            local e = encode(rawget(v, i), depth + 1, seen)
            out[#out + 1] = e or "null"
        end
        seen[v] = nil
        return "[" .. table.concat(out, ",") .. "]"
    end
    for _, k in ipairs(sandbox.sorted_keys(v)) do
        local e = encode(rawget(v, k), depth + 1, seen)
        if e then out[#out + 1] = quote(tostring(k)) .. ":" .. e end
    end
    seen[v] = nil
    return "{" .. table.concat(out, ",") .. "}"
end

local arch
local files = {}
local i = 1
while arg[i] do
    if arg[i] == "--arch" then arch = arg[i + 1]; i = i + 2
    else files[#files + 1] = arg[i]; i = i + 1 end
end

for _, file in ipairs(files) do
    local pkg, err = sandbox.load_recipe(file, arch and { arch = arch } or nil)
    if pkg then
        io.write('{"file":', quote(file), ',"package":', encode(pkg, 0, {}) or "null", "}\n")
    else
        io.write('{"file":', quote(file), ',"error":', quote(tostring(err)), "}\n")
    end
end
